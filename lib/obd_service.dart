import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

/// Classe que guarda o resultado da leitura de Etanol
class EthanolReadResult {
  final bool success;
  final double percentage;       // Porcentagem calculada (ex: 27.5%)
  final String rawResponse;      // Resposta pura da ECU (ex: "41 52 46")
  final String? errorMessage;    // Mensagem de erro amigável se algo der errado

  EthanolReadResult({
    required this.success,
    this.percentage = 0.0,
    this.rawResponse = '',
    this.errorMessage,
  });
}

/// Serviço responsável por falar o protocolo OBD-II (ELM327) via Bluetooth
class ObdService {
  /// Envia um comando AT ou PID OBD-II para o ELM327 e aguarda a resposta até o prompt '>'
  ///
  /// O ELM327 funciona assim: a gente manda o comando com "\r" (Carriage Return)
  /// e ele responde o texto e termina com o caractere '>' para avisar que está pronto para o próximo comando.
  static Future<String> sendCommand(
    BtcConnection connection,
    String command, {
    Duration timeout = const Duration(seconds: 4),
    Stream<Uint8List>? inputStream,
  }) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    StreamSubscription<Uint8List>? subscription;

    // Escuta os bytes que chegam do adaptador (usa stream compartilhado se fornecido)
    final stream = inputStream ?? connection.input;
    subscription = stream.listen(
      (data) {
        final text = utf8.decode(data, allowMalformed: true);
        buffer.write(text);

        // O caractere '>' indica o fim da resposta no padrão do ELM327
        if (buffer.toString().contains('>')) {
          if (!completer.isCompleted) {
            completer.complete(buffer.toString());
          }
        }
      },
      onError: (err) {
        if (!completer.isCompleted) {
          completer.completeError(err);
        }
      },
    );

    try {
      // Mandamos o comando com \r no final (o ELM327 ignora \n, precisa ser \r)
      final bytes = Uint8List.fromList(utf8.encode('$command\r'));
      await connection.output.add(bytes);

      final rawResponse = await completer.future.timeout(
        timeout,
        onTimeout: () {
          final partial = buffer.toString().trim();
          if (partial.isNotEmpty) return partial;
          throw TimeoutException('O leitor ELM327 demorou demais para responder ao comando: $command');
        },
      );

      return _cleanResponse(rawResponse, command);
    } finally {
      await subscription.cancel();
    }
  }

  /// Inicializa o adaptador ELM327 com os comandos básicos recomendados
  static Future<void> initializeElm327(
    BtcConnection connection, {
    Stream<Uint8List>? inputStream,
  }) async {
    debugPrint('[OBD-II] Inicializando adaptador ELM327...');

    Future<void> safeSend(String cmd, {Duration timeout = const Duration(seconds: 4)}) async {
      try {
        await sendCommand(connection, cmd, timeout: timeout, inputStream: inputStream);
      } catch (e) {
        debugPrint('[OBD-II] Aviso ao enviar $cmd: $e');
      }
    }

    // ATZ: Reseta o chip ELM327 para o estado inicial de fábrica
    await safeSend('ATZ', timeout: const Duration(seconds: 3));
    await Future.delayed(const Duration(milliseconds: 500));

    // ATE0: Desativa o Eco (não fica repetindo de volta o comando que a gente mandou)
    await safeSend('ATE0');

    // ATL0: Desativa Line Feeds extras (\n), facilitando o parse de texto
    await safeSend('ATL0');

    // ATS0: Remove espaços nas respostas hexadecimais para agilizar
    // (alguns preferem com espaços, mas ATS0 deixa mais leve a transmissão)
    // await sendCommand(connection, 'ATS0');

    // ATSP0: Protocolo automático (deixa o ELM327 descobrir sozinho se o carro usa CAN, ISO, KWP...)
    await safeSend('ATSP0', timeout: const Duration(seconds: 5));

    debugPrint('[OBD-II] ELM327 inicializado com sucesso e pronto para leitura.');
  }

  /// Lê o parâmetro de % de Etanol no combustível usando o PID padrão SAE J1979: Mode 01 PID 52
  ///
  /// Fórmula Oficial OBD-II:
  /// Resposta esperada: "41 52 XX"
  /// Porcentagem (%) = (Byte A * 100) / 255
  /// Exemplo: se XX = 46 (Hex) -> 70 em decimal -> (70 * 100) / 255 = 27.45% de etanol (Gasolina brasileira comum!)
  static Future<EthanolReadResult> readEthanolPercentage(
    BtcConnection connection, {
    Stream<Uint8List>? inputStream,
  }) async {
    try {
      debugPrint('[OBD-II] Solicitando PID 01 52 (Ethanol Fuel %)...');
      final response = await sendCommand(
        connection,
        '01 52',
        timeout: const Duration(seconds: 8),
        inputStream: inputStream,
      );

      debugPrint('[OBD-II] Resposta bruta da ECU para etanol: "$response"');

      // Limpa espaços extras e padroniza para maiúsculas
      final clean = response.replaceAll(' ', '').toUpperCase();

      if (clean.contains('NODATA')) {
        return EthanolReadResult(
          success: false,
          rawResponse: response,
          errorMessage: 'O veículo não suporta o PID 0152 (NO DATA) ou a ignição está desligada.',
        );
      }

      if (clean.contains('UNABLETOCONNECT') || clean.contains('ERROR') || clean.contains('STOPPED')) {
        return EthanolReadResult(
          success: false,
          rawResponse: response,
          errorMessage: 'Não foi possível comunicar com a ECU do carro. Verifique se a ignição está ligada.',
        );
      }

      // Procura pelo cabeçalho de resposta positiva: "4152"
      final index = clean.indexOf('4152');
      if (index != -1 && clean.length >= index + 6) {
        final hexValue = clean.substring(index + 4, index + 6);
        final int? byteA = int.tryParse(hexValue, radix: 16);

        if (byteA != null) {
          // Fórmula oficial: (A * 100) / 255
          final percentage = (byteA * 100.0) / 255.0;
          return EthanolReadResult(
            success: true,
            percentage: double.parse(percentage.toStringAsFixed(1)),
            rawResponse: response,
          );
        }
      }

      return EthanolReadResult(
        success: false,
        rawResponse: response,
        errorMessage: 'Formato de resposta inesperado da ECU: $response',
      );
    } catch (e) {
      debugPrint('[OBD-II] Erro na leitura de etanol: $e');
      return EthanolReadResult(
        success: false,
        errorMessage: 'Erro na comunicação: $e',
      );
    }
  }

  /// Limpa caracteres de controle, prompt '>' e o eco do próprio comando
  static String _cleanResponse(String raw, String sentCommand) {
    String text = raw.replaceAll('>', '').replaceAll('\r', ' ').replaceAll('\n', ' ').trim();
    // Remove o comando se o ELM327 ainda estiver ecoando
    if (text.startsWith(sentCommand)) {
      text = text.substring(sentCommand.length).trim();
    }
    return text;
  }
}

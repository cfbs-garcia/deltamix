import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

import '../models/obd_reading.dart';
import 'obd_commands.dart';
import 'obd_parser.dart';

/// ============================================================================
/// SERVIÇO DE COMUNICAÇÃO SERIAL OBD-II (ELM327 VIA BLUETOOTH RFCOMM/SPP)
/// ============================================================================
///
/// Responsável pelo envio de comandos AT e PIDs SAE J1979 para o adaptador
/// ELM327 e leitura das respostas até o caractere delimitador '>'.
class ObdService {
  /// Envia um comando AT ou PID OBD-II para o ELM327 e aguarda a resposta até o prompt '>'.
  ///
  /// O ELM327 exige que todo comando termine com "\r" (Carriage Return) e
  /// finaliza sua resposta com o caractere '>' indicando que está pronto para o próximo comando.
  static Future<String> sendCommand(
    BtcConnection connection,
    String command, {
    Duration timeout = const Duration(seconds: 4),
    Stream<Uint8List>? inputStream,
  }) async {
    final completer = Completer<String>();
    final buffer = StringBuffer();
    StreamSubscription<Uint8List>? subscription;

    // Usa o stream broadcast compartilhado do ObdController para evitar múltiplas threads nativas
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
      onError: (Object err) {
        if (!completer.isCompleted) {
          completer.completeError(err);
        }
      },
    );

    try {
      // Envia o comando finalizado com \r (Carriage Return)
      final bytes = Uint8List.fromList(utf8.encode('$command\r'));
      await connection.output.add(bytes);

      final rawResponse = await completer.future.timeout(
        timeout,
        onTimeout: () {
          final partial = buffer.toString().trim();
          if (partial.isNotEmpty) return partial;
          throw TimeoutException(
            'O leitor ELM327 demorou demais para responder ao comando: $command',
          );
        },
      );

      return _cleanResponse(rawResponse, command);
    } finally {
      await subscription.cancel();
    }
  }

  /// Inicializa o adaptador ELM327 com a sequência recomendada de comandos AT:
  /// ATZ (Reset) -> ATE0 (Sem Eco) -> ATL0 (Sem Linefeeds) -> ATSP0 (Protocolo Automático).
  static Future<void> initializeElm327(
    BtcConnection connection, {
    Stream<Uint8List>? inputStream,
  }) async {
    debugPrint('[OBD-II] Inicializando adaptador ELM327...');

    Future<void> safeSend(
      String cmd, {
      Duration timeout = const Duration(seconds: 4),
    }) async {
      try {
        await sendCommand(
          connection,
          cmd,
          timeout: timeout,
          inputStream: inputStream,
        );
      } catch (e) {
        debugPrint('[OBD-II] Aviso ao enviar $cmd: $e');
      }
    }

    // ATZ: Reseta o chip ELM327 para o estado inicial
    await safeSend(ObdCommands.reset, timeout: const Duration(seconds: 3));
    await Future.delayed(const Duration(milliseconds: 300));

    // ATE0: Desativa o Eco dos comandos
    await safeSend(ObdCommands.echoOff, timeout: const Duration(seconds: 2));

    // ATL0: Desativa quebras de linha extras (\n)
    await safeSend(ObdCommands.linefeedsOff, timeout: const Duration(seconds: 2));

    // ATSP0: Seleciona detecção automática de protocolo da ECU
    await safeSend(ObdCommands.autoProtocol, timeout: const Duration(seconds: 3));

    debugPrint('[OBD-II] ELM327 inicializado com sucesso e pronto para leitura.');
  }

  // ---------------------------------------------------------------------------
  // 1. LEITURA DE PORCENTAGEM DE ETANOL (MODE 01 PID 52)
  // ---------------------------------------------------------------------------
  static Future<EthanolReadResult> readEthanolPercentage(
    BtcConnection connection, {
    Stream<Uint8List>? inputStream,
  }) async {
    try {
      debugPrint('[OBD-II] Solicitando PID 01 52 (Ethanol Fuel %)...');
      final response = await sendCommand(
        connection,
        ObdCommands.ethanolFuelPercent,
        timeout: const Duration(seconds: 3),
        inputStream: inputStream,
      );

      debugPrint('[OBD-II] Resposta bruta da ECU para etanol: "$response"');
      final clean = ObdParser.normalizeHex(response);

      if (ObdParser.isNoData(clean)) {
        return EthanolReadResult(
          success: false,
          rawResponse: response,
          errorMessage:
              'O veículo não suporta o PID 0152 (NO DATA) ou a ignição está desligada.',
        );
      }

      if (ObdParser.isConnectionError(clean)) {
        return EthanolReadResult(
          success: false,
          rawResponse: response,
          errorMessage:
              'Não foi possível comunicar com a ECU do carro. Verifique se a ignição está ligada.',
        );
      }

      final percentage = ObdParser.parseEthanolPercentage(response);
      if (percentage != null) {
        return EthanolReadResult(
          success: true,
          percentage: percentage,
          rawResponse: response,
        );
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

  // ---------------------------------------------------------------------------
  // 2. LEITURA DE ROTAÇÃO DO MOTOR - RPM (MODE 01 PID 0C)
  // ---------------------------------------------------------------------------
  static Future<int?> readEngineRpm(
    BtcConnection connection, {
    Stream<Uint8List>? inputStream,
  }) async {
    try {
      final response = await sendCommand(
        connection,
        ObdCommands.engineRpm,
        timeout: const Duration(milliseconds: 2500),
        inputStream: inputStream,
      );
      return ObdParser.parseRpm(response);
    } catch (e) {
      debugPrint('[OBD-II] Aviso na leitura de RPM (01 0C): $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 3. LEITURA DE SHORT TERM FUEL TRIM - STFT (MODE 01 PID 06)
  // ---------------------------------------------------------------------------
  static Future<double?> readShortTermFuelTrim(
    BtcConnection connection, {
    Stream<Uint8List>? inputStream,
  }) async {
    try {
      final response = await sendCommand(
        connection,
        ObdCommands.shortTermFuelTrim,
        timeout: const Duration(milliseconds: 2500),
        inputStream: inputStream,
      );
      return ObdParser.parseFuelTrim(response, pidHex: '06');
    } catch (e) {
      debugPrint('[OBD-II] Aviso na leitura de STFT (01 06): $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // 4. LEITURA DE LONG TERM FUEL TRIM - LTFT (MODE 01 PID 07)
  // ---------------------------------------------------------------------------
  static Future<double?> readLongTermFuelTrim(
    BtcConnection connection, {
    Stream<Uint8List>? inputStream,
  }) async {
    try {
      final response = await sendCommand(
        connection,
        ObdCommands.longTermFuelTrim,
        timeout: const Duration(milliseconds: 2500),
        inputStream: inputStream,
      );
      return ObdParser.parseFuelTrim(response, pidHex: '07');
    } catch (e) {
      debugPrint('[OBD-II] Aviso na leitura de LTFT (01 07): $e');
      return null;
    }
  }

  /// Remove caracteres de controle, prompt '>' e o eco do próprio comando enviado.
  static String _cleanResponse(String raw, String sentCommand) {
    String text = raw
        .replaceAll('>', '')
        .replaceAll('\r', ' ')
        .replaceAll('\n', ' ')
        .trim();
    if (text.startsWith(sentCommand)) {
      text = text.substring(sentCommand.length).trim();
    }
    return text;
  }
}

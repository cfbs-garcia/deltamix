import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/bluetooth/obd_controller.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

/// ============================================================================
/// TELA DE PERFIL E CONFIGURAÇÕES AUTOMOTIVAS
/// ============================================================================
///
/// Responsabilidades desta tela:
/// 1. Exibir e editar dados do usuário autenticado (nome e foto via Firestore).
/// 2. Ajustar a Frequência de Leitura da ECU (conectada em tempo real ao ObdController).
/// 3. Exibir informações da versão do sistema e protocolo OBD-II.
/// 4. Logout e exclusão (soft delete) da conta.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ObdController _obd = ObdController.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Meu Perfil'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. HEADER DO USUÁRIO (AVATAR + NOME + EMAIL)
              _buildUserHeader(),

              const SizedBox(height: 24),

              // 2. SEÇÃO DE CONFIGURAÇÕES DO PROTOCOLO OBD-II / BLUETOOTH
              _buildSectionTitle('PARÂMETROS OBD-II / ELM327'),
              const SizedBox(height: 10),
              _buildObdSettingsGroup(),

              const SizedBox(height: 24),

              // 3. INFORMAÇÕES DO SISTEMA E VERSÃO
              _buildAppInfoTile(),

              const SizedBox(height: 32),

              // 4. BOTÃO DE SAIR POSICIONADO EM BAIXO (RODAPÉ)
              _buildLogoutButton(),

              const SizedBox(height: 8),

              // 5. EXCLUIR CONTA (SOFT DELETE)
              TextButton.icon(
                onPressed: _showDeleteConfirmation,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 18,
                  color: AppColors.textMuted,
                ),
                label: const Text(
                  'Excluir conta',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // COMPONENTES DO PERFIL
  // ---------------------------------------------------------------------------

  /// Cabeçalho com foto de perfil e dados básicos (lidos do Firestore)
  Widget _buildUserHeader() {
    final user = AuthService.instance.currentUser;
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: user == null ? null : AuthService.instance.userStream(user.uid),
      builder: (context, snap) {
        final data = snap.data?.data();
        final name = (data?['name'] as String?) ?? user?.displayName ?? '';
        final email = (data?['email'] as String?) ?? user?.email ?? '';
        final photoB64 = data?['photoBase64'] as String?;
        final hasPhoto = photoB64 != null && photoB64.isNotEmpty;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              // Avatar com borda neon suave (toque para trocar a foto)
              GestureDetector(
                onTap: () => _changePhoto(hasPhoto),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.surfaceInput,
                        border: Border.all(
                          color: AppColors.ethanolNeon,
                          width: 2,
                        ),
                      ),
                      child: ClipOval(
                        child: hasPhoto
                            ? Image.memory(
                                base64Decode(photoB64),
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person_rounded,
                                  size: 38,
                                  color: AppColors.ethanolNeon,
                                ),
                              )
                            : const Icon(
                                Icons.person_rounded,
                                size: 38,
                                color: AppColors.ethanolNeon,
                              ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: AppColors.ethanolNeon,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surfaceCard,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.photo_camera_rounded,
                          size: 13,
                          color: AppColors.textOnNeon,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Informações textuais
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? 'Sem nome' : name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.edit_outlined,
                  color: AppColors.textMuted,
                ),
                onPressed: () => _editName(name),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Título de cada grupo de configurações
  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  /// Configuração real de Frequência de Leitura da ECU
  Widget _buildObdSettingsGroup() {
    return ListenableBuilder(
      listenable: _obd,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: ListTile(
            title: const Text(
              'Frequência de Leitura da ECU',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            subtitle: Text(
              'Atual: ${_obd.pollingIntervalLabel} (Taxa de atualização dos sensores)',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
            trailing: const Icon(
              Icons.timer_outlined,
              color: AppColors.obdCyan,
            ),
            onTap: _showPollingIntervalPicker,
          ),
        );
      },
    );
  }

  /// Informações sobre a versão do software e conformidade de protocolo
  Widget _buildAppInfoTile() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            'Deltamix v1.0.0 (Build 1)',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Padrão SAE J1979 • ELM327 SPP Serial • Suporte Flex Brasil',
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  /// Botão de Encerrar Sessão posicionado no final (rodapé) da tela de Perfil
  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.alertRed,
        side: const BorderSide(color: AppColors.alertRed, width: 1.5),
        minimumSize: const Size.fromHeight(54),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(27),
        ),
      ),
      onPressed: _showLogoutConfirmation,
      icon: const Icon(Icons.logout_rounded, color: AppColors.alertRed),
      label: const Text(
        'Sair da Conta',
        style: TextStyle(
          color: AppColors.alertRed,
          fontWeight: FontWeight.w700,
          fontSize: 15,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DIÁLOGOS DE AÇÃO
  // ---------------------------------------------------------------------------

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _logout() async {
    final nav = Navigator.of(context);
    await AuthService.instance.logout();
    // O AccountGate volta para o login; aqui só fechamos as telas empilhadas.
    nav.popUntil((r) => r.isFirst);
  }

  Future<void> _editName(String current) async {
    String typedName = current;
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text(
          'Editar o nome',
          style: TextStyle(color: AppColors.textPrimary),
        ),
        content: TextFormField(
          initialValue: current,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nome completo',
            prefixIcon: Icon(Icons.person_outline_rounded),
          ),
          onChanged: (v) => typedName = v,
          onFieldSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, typedName.trim()),
            child: const Text(
              'Salvar',
              style: TextStyle(color: AppColors.ethanolNeon),
            ),
          ),
        ],
      ),
    );
    if (newName != null && newName.isNotEmpty) {
      try {
        await AuthService.instance.updateName(newName);
      } catch (e) {
        if (mounted) _snack(AuthService.errorMessage(e));
      }
    }
  }

  Future<void> _changePhoto(bool hasPhoto) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Foto de perfil',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library_outlined,
                  color: AppColors.ethanolNeon,
                ),
                title: const Text(
                  'Escolher da galeria',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_camera_outlined,
                  color: AppColors.ethanolNeon,
                ),
                title: const Text(
                  'Tirar foto',
                  style: TextStyle(color: AppColors.textPrimary),
                ),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              if (hasPhoto)
                ListTile(
                  leading: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.alertRed,
                  ),
                  title: const Text(
                    'Remover foto',
                    style: TextStyle(color: AppColors.alertRed),
                  ),
                  onTap: () => Navigator.pop(ctx, 'remove'),
                ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;

    try {
      if (choice == 'remove') {
        await AuthService.instance.removePhoto();
        return;
      }
      final picked = await ImagePicker().pickImage(
        source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.length > 700 * 1024) {
        if (mounted) _snack('Imagem muito grande.');
        return;
      }
      await AuthService.instance.updatePhoto(bytes);
    } catch (e) {
      if (mounted) _snack('Não foi possível atualizar a foto.');
    }
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text(
            'Excluir conta?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            'Sua conta será desativada e você será desconectado. '
            'Se entrar novamente com o mesmo e-mail e senha, poderá reativá-la.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _deleteAccount();
              },
              child: const Text(
                'Excluir',
                style: TextStyle(color: AppColors.alertRed),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteAccount() async {
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await AuthService.instance.softDeleteAccount();
      nav.popUntil((r) => r.isFirst);
      messenger.showSnackBar(
        const SnackBar(content: Text('Conta excluída.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(AuthService.errorMessage(e))),
      );
    }
  }

  void _showPollingIntervalPicker() {
    final currentMs = _obd.pollingIntervalMs;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Frequência de Leitura da ECU',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  title: const Text(
                    '250 ms (Rápido - Padrão recomendado)',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: currentMs == 250
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.ethanolNeon,
                        )
                      : null,
                  onTap: () {
                    _obd.setPollingIntervalMs(250);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text(
                    '500 ms (Equilibrado)',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: currentMs == 500
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.ethanolNeon,
                        )
                      : null,
                  onTap: () {
                    _obd.setPollingIntervalMs(500);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  title: const Text(
                    '1000 ms (Econômico)',
                    style: TextStyle(color: AppColors.textPrimary),
                  ),
                  trailing: currentMs == 1000
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.ethanolNeon,
                        )
                      : null,
                  onTap: () {
                    _obd.setPollingIntervalMs(1000);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text(
            'Encerrar Sessão?',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            'Você será desconectado e o leitor OBD-II será desvinculado temporariamente.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _logout();
              },
              child: const Text(
                'Sair',
                style: TextStyle(color: AppColors.alertRed),
              ),
            ),
          ],
        );
      },
    );
  }
}

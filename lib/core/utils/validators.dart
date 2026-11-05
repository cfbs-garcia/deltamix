/// Validações de e-mail e senha usadas no cadastro.
class Validators {
  Validators._();

  static final RegExp _emailRegex = RegExp(
    r'^[A-Za-z0-9](?:[A-Za-z0-9._%+-]{0,62}[A-Za-z0-9])?'
    r'@(?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\.)+[A-Za-z]{2,24}$',
  );

  /// Domínios de e-mail descartável mais comuns.
  static const Set<String> _disposableDomains = {
    'mailinator.com',
    'tempmail.com',
    'temp-mail.org',
    'guerrillamail.com',
    '10minutemail.com',
    'yopmail.com',
    'trashmail.com',
    'throwawaymail.com',
    'sharklasers.com',
    'getnada.com',
    'maildrop.cc',
    'dispostable.com',
    'fakeinbox.com',
  };

  /// Senhas/termos fracos muito usados (comparação em minúsculas).
  static const List<String> _commonTerms = [
    'password',
    'senha',
    'qwerty',
    'asdfgh',
    'zxcvbn',
    'abc123',
    'admin',
    'letmein',
    'welcome',
    'iloveyou',
    'mudar',
    'deltamix',
    'brasil',
    'football',
    'futebol',
    '123123',
    '111111',
    '000000',
    '654321',
  ];

  /// Retorna `null` se o e-mail for válido, ou a mensagem de erro.
  static String? email(String value) {
    final email = value.trim();
    if (email.isEmpty) return 'Informe o e-mail.';
    if (email.length > 254 ||
        email.contains('..') ||
        !_emailRegex.hasMatch(email)) {
      return 'E-mail inválido.';
    }
    final domain = email.split('@').last.toLowerCase();
    if (_disposableDomains.contains(domain)) {
      return 'E-mails temporários não são aceitos.';
    }
    return null;
  }

  /// Retorna `null` se a senha for forte, ou a mensagem de erro.
  static String? password(String pass, {String email = '', String name = ''}) {
    if (pass.length < 8) return 'A senha deve ter no mínimo 8 caracteres.';
    if (pass.length > 64) return 'A senha deve ter no máximo 64 caracteres.';
    if (pass.contains(' ')) return 'A senha não pode conter espaços.';
    if (!RegExp(r'[a-z]').hasMatch(pass)) {
      return 'A senha precisa de ao menos uma letra minúscula.';
    }
    if (!RegExp(r'[A-Z]').hasMatch(pass)) {
      return 'A senha precisa de ao menos uma letra maiúscula.';
    }
    if (!RegExp(r'[0-9]').hasMatch(pass)) {
      return 'A senha precisa de ao menos um número.';
    }

    final lower = pass.toLowerCase();

    if (RegExp(r'(.)\1{3,}').hasMatch(pass)) {
      return 'Evite repetir o mesmo caractere várias vezes seguidas.';
    }
    if (_hasSequence(lower, 4)) {
      return 'Evite sequências como "1234" ou "abcd".';
    }
    for (final term in _commonTerms) {
      if (lower.contains(term)) return 'Essa senha é muito comum.';
    }

    final localPart = email.split('@').first.toLowerCase();
    if (localPart.length >= 4 && lower.contains(localPart)) {
      return 'A senha não pode conter o seu e-mail.';
    }
    for (final part in name.toLowerCase().split(RegExp(r'\s+'))) {
      if (part.length >= 4 && lower.contains(part)) {
        return 'A senha não pode conter o seu nome.';
      }
    }
    return null;
  }

  /// Verdadeiro se houver [len] caracteres alfanuméricos consecutivos
  /// em ordem crescente ou decrescente (ex.: 1234, 4321, abcd, dcba).
  static bool _hasSequence(String s, int len) {
    bool alnum(int c) =>
        (c >= 48 && c <= 57) || (c >= 97 && c <= 122);
    for (var i = 0; i + len <= s.length; i++) {
      var up = true;
      var down = true;
      for (var j = 0; j < len; j++) {
        final c = s.codeUnitAt(i + j);
        if (!alnum(c)) {
          up = false;
          down = false;
          break;
        }
        if (j > 0) {
          final prev = s.codeUnitAt(i + j - 1);
          if (c != prev + 1) up = false;
          if (c != prev - 1) down = false;
        }
      }
      if (up || down) return true;
    }
    return false;
  }
}

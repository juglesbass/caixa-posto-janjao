class Validator {
  /// Valida o nome do operador:
  /// - Exige pelo menos 3 caracteres alfabéticos válidos (incluindo acentos)
  /// - Retorna null se válido, ou mensagem de erro se inválido
  static String? validarNomeOperador(String? nome) {
    final nomeLimpo = (nome ?? '').trim();
    if (nomeLimpo.isEmpty) {
      return 'Digite pelo menos o primeiro nome completo (mín. 3 letras)';
    }

    final letras = RegExp(r'[a-zA-ZÀ-ÿ]').allMatches(nomeLimpo);
    if (letras.length < 3) {
      return 'Digite pelo menos o primeiro nome completo (mín. 3 letras)';
    }

    return null;
  }

  /// Formata o nome em Title Case (ex: "joão victor" -> "João Victor")
  static String formatarNomeOperador(String nome) {
    final limpo = nome.trim();
    if (limpo.isEmpty) return 'Não informado';
    return limpo.split(' ').where((p) => p.isNotEmpty).map((palavra) {
      final minuscula = palavra.toLowerCase();
      if (minuscula.length == 1) return minuscula.toUpperCase();
      return minuscula[0].toUpperCase() + minuscula.substring(1);
    }).join(' ');
  }
}

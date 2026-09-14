import 'dart:math';

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

  /// Indica se dois nomes parecem ser da mesma pessoa.
  ///
  /// Serve para barrar o cadastro duplicado de operador. O nome idêntico o
  /// cadastro já reconhece; o que escapava eram as variações:
  ///   - sem acento: "Joao" e "João"
  ///   - só parte do nome: "Joao" e "Joao Victor Almeida"
  ///   - uma letra de diferença: "Vitor" e "Victor", "Luis" e "Luiz"
  ///   - abreviação: "J Silva" e "Joao Silva"
  ///
  /// Todas as palavras do nome mais curto precisam estar no mais longo, então
  /// "Joao Pedro" não esbarra em "Joao Victor". Masculino e feminino ("Paulo" e
  /// "Paula", "Daniel" e "Daniela") não contam como erro de digitação.
  static bool nomesParecidos(String a, String b) {
    final palavrasA = _palavrasDoNome(a);
    final palavrasB = _palavrasDoNome(b);
    if (palavrasA.isEmpty || palavrasB.isEmpty) return false;

    final aEhMaisCurto = palavrasA.length <= palavrasB.length;
    final curto = aEhMaisCurto ? palavrasA : palavrasB;
    final restantes = List<String>.of(aEhMaisCurto ? palavrasB : palavrasA);

    // Palavras iguais saem primeiro, para uma variação não tomar o lugar delas
    var inteiras = 0;
    final pendentes = <String>[];
    for (final palavra in curto) {
      if (restantes.remove(palavra)) {
        if (palavra.length > 1) inteiras++;
      } else {
        pendentes.add(palavra);
      }
    }

    // Iniciais por último: uma inicial encaixa em qualquer palavra com a mesma
    // letra e não pode ocupar o lugar de uma palavra inteira.
    final ordem = [
      ...pendentes.where((p) => p.length > 1),
      ...pendentes.where((p) => p.length == 1),
    ];
    for (final palavra in ordem) {
      final i = restantes
          .indexWhere((candidata) => _palavrasEquivalentes(palavra, candidata));
      if (i == -1) return false;
      final outra = restantes.removeAt(i);
      if (palavra.length > 1 && outra.length > 1) inteiras++;
    }

    // Só iniciais em comum ("Jorge" e "J Silva") não bastam
    return inteiras > 0;
  }

  /// Palavras de ligação, que não distinguem uma pessoa de outra
  static const Set<String> _conectivos = {'da', 'das', 'de', 'di', 'do', 'dos', 'du', 'e'};

  static const Map<String, String> _acentos = {
    'a': 'áàâãäå',
    'e': 'éèêë',
    'i': 'íìîï',
    'o': 'óòôõö',
    'u': 'úùûü',
    'c': 'ç',
    'n': 'ñ',
  };

  /// Minúsculas, sem acento e sem conectivos: "João Victor da Silva" vira
  /// `[joao, victor, silva]`
  static List<String> _palavrasDoNome(String nome) {
    // Acento que chega como caractere separado da letra (a + ~) sai aqui; o
    // acento já embutido na letra (ã) é trocado logo abaixo.
    var texto = String.fromCharCodes(
      nome.toLowerCase().runes.where((r) => r < 0x0300 || r > 0x036F),
    );
    for (final acento in _acentos.entries) {
      for (final letra in acento.value.split('')) {
        texto = texto.replaceAll(letra, acento.key);
      }
    }
    return texto
        .split(RegExp(r'[^a-z]+'))
        .where((p) => p.isNotEmpty && !_conectivos.contains(p))
        .toList();
  }

  static bool _palavrasEquivalentes(String x, String y) {
    if (x == y) return true;
    if (x.length == 1 || y.length == 1) return x[0] == y[0];
    if (min(x.length, y.length) < 4) return false;
    if (_semVogalFinal(x) == _semVogalFinal(y)) return false;
    final tolerancia = max(x.length, y.length) >= 10 ? 2 : 1;
    return _distancia(x, y) <= tolerancia;
  }

  /// "paulo" e "paula" viram "paul"; "daniela" vira "daniel"
  static String _semVogalFinal(String palavra) =>
      palavra.endsWith('a') || palavra.endsWith('o')
          ? palavra.substring(0, palavra.length - 1)
          : palavra;

  /// Distância de edição: quantas letras é preciso trocar, pôr ou tirar
  static int _distancia(String a, String b) {
    var anterior = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final atual = List<int>.filled(b.length + 1, 0);
      atual[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final custo = a[i - 1] == b[j - 1] ? 0 : 1;
        atual[j] = min(min(anterior[j] + 1, atual[j - 1] + 1), anterior[j - 1] + custo);
      }
      anterior = atual;
    }
    return anterior[b.length];
  }
}

/// Conferência da pista contra o sistema (PDV): uma regra só, usada na tela
/// de Resumo, na janela de fechamento, no PDF, no texto do WhatsApp e no Excel.
///
/// Sem a venda do sistema informada não há conferência. Antes, comparar a
/// pista com zero fazia o total inteiro aparecer como "sobra na pista" — no
/// PDF inclusive — e isso confundia o gerente quando o frentista esquecia de
/// digitar o valor do sistema. Agora, sem sistema, sai só o total da pista.
enum EstadoConciliacao {
  /// Venda do sistema não informada: nada a comparar.
  semSistema,

  /// Pista igual ao sistema.
  fechada,

  /// Pista lançou mais que o sistema.
  sobra,

  /// Pista lançou menos que o sistema.
  falta,
}

class Conciliacao {
  Conciliacao._();

  /// Estado da conferência. Os valores são em reais com centavos; meio
  /// centavo é a fronteira que separa "igual" de "diferente" sem sofrer com o
  /// arredondamento de ponto flutuante (0,1 + 0,2 não dá exatamente 0,3).
  static EstadoConciliacao estado({required double totalPista, required double vendasSistema}) {
    if (vendasSistema <= 0) return EstadoConciliacao.semSistema;
    final diferenca = totalPista - vendasSistema;
    if (diferenca.abs() < 0.005) return EstadoConciliacao.fechada;
    return diferenca > 0 ? EstadoConciliacao.sobra : EstadoConciliacao.falta;
  }
}

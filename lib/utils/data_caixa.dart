import 'package:intl/intl.dart';

/// Dia a que um caixa pertence — que nem sempre é o dia em que ele foi aberto.
///
/// O funcionário da noite entra às 18h e sai às 6h com dois caixas: um até a
/// meia-noite, que é do dia em que entrou, e outro até as 6h, que já é do dia
/// seguinte. Quando ele só abria o app depois da meia-noite, o primeiro caixa
/// nascia com a data do dia seguinte, e os dois PDFs chegavam ao gerente com a
/// mesma data. Pior: com o mesmo nome de arquivo, o segundo chegava como "_v2",
/// que é o sinal de turno corrigido — o gerente podia descartar o primeiro.
///
/// A hora real de abertura continua em `Turno.data`, para auditoria. A data do
/// caixa é separada, e é ela que vai no nome do PDF e no cabeçalho.
class DataCaixa {
  DataCaixa._();

  /// Aberturas antes desta hora perguntam de qual dia é o caixa.
  ///
  /// Não existe regra automática que acerte: "antes das 6h é ontem" erraria
  /// justamente o caixa da madrugada, que é do dia novo. Só o operador sabe qual
  /// dos dois está abrindo.
  static const int horaFimMadrugada = 6;

  static final DateFormat _formato = DateFormat('dd/MM/yyyy');

  static bool aberturaDeMadrugada(DateTime abertura) =>
      abertura.hour < horaFimMadrugada;

  static String formatar(DateTime dia) => _formato.format(dia);

  /// Dia anterior pelo calendário, e não subtraindo 24 horas: assim não depende
  /// de fuso nem de horário de verão, e vira mês e ano corretamente.
  static DateTime diaAnterior(DateTime dia) =>
      DateTime(dia.year, dia.month, dia.day - 1);

  /// As duas datas possíveis para um caixa aberto em [dataAbertura]
  /// ("dd/MM/yyyy" ou "dd/MM/yyyy HH:mm"): o dia anterior e o próprio dia.
  /// Devolve null se a data não puder ser lida.
  static ({String anterior, String doDia})? opcoes(String dataAbertura) {
    try {
      final dia = _formato.parseStrict(dataAbertura.trim().split(' ').first);
      return (anterior: formatar(diaAnterior(dia)), doDia: formatar(dia));
    } catch (_) {
      return null;
    }
  }

  /// "14/09/2026" → "14/09", para caber em botão
  static String curta(String data) {
    final partes = data.split('/');
    return partes.length >= 2 ? '${partes[0]}/${partes[1]}' : data;
  }

  /// O caixa ainda aberto é de um dia anterior, e a madrugada já acabou?
  ///
  /// Depois das 6h nenhum caixa deveria continuar com data de um dia anterior:
  /// os dois caixas da noite fecham até as 6h. Acontece quando alguém fecha o
  /// caixa, abre o app de novo no mesmo dia — e se identificar já abre um
  /// turno — e só volta a trabalhar dias depois, com o caixa ainda datado do
  /// dia em que foi aberto.
  ///
  /// De madrugada é sempre false: ali, o caixa da meia-noite com data de ontem
  /// é o comportamento certo.
  static bool caixaDeDiaAnterior(String dataCaixa, DateTime agora) {
    if (aberturaDeMadrugada(agora)) return false;
    try {
      final dia = _formato.parseStrict(dataCaixa.trim().split(' ').first);
      return dia.isBefore(DateTime(agora.year, agora.month, agora.day));
    } catch (_) {
      return false;
    }
  }

  /// Datas oferecidas no "trocar" do Resumo, sem repetir e nesta ordem: o dia
  /// anterior à abertura, o dia da abertura e hoje. "Hoje" existe para o caixa
  /// aberto num dia e usado só dias depois.
  static List<({String rotulo, String data})> opcoesParaTroca(
    String dataAbertura,
    DateTime agora,
  ) {
    final base = opcoes(dataAbertura);
    final hoje = formatar(agora);
    final lista = <({String rotulo, String data})>[];
    if (base != null) {
      lista.add((rotulo: 'Dia anterior', data: base.anterior));
      lista.add((rotulo: 'Dia da abertura', data: base.doDia));
    }
    if (!lista.any((o) => o.data == hoje)) {
      lista.add((rotulo: 'Hoje', data: hoje));
    }
    return lista;
  }
}

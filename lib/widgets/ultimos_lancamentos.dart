import 'dart:async';

import 'package:flutter/material.dart';

import '../dialogs/edit_launch_dialog.dart';
import '../models/lancamento.dart';
import '../models/turno.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_icones.dart';
import '../theme/app_texto.dart';
import '../utils/currency_formatter.dart';

/// Os dois últimos lançamentos do turno, com correção a um toque.
///
/// Por que existe: o erro caro do posto é lançar 380 onde era 38, ou lançar no
/// Pix o que entrou em dinheiro. Hoje isso só aparece quando alguém abre o
/// Resumo — ou pior, quando o PDF já está na mão do gerente, e aí a saída é
/// reabrir turno, corrigir e reenviar, com a gerência recebendo uma segunda
/// versão sem saber por quê. Com os últimos lançamentos na tela onde o
/// frentista já está, o erro morre segundos depois de nascer.
///
/// A correção reaproveita o mesmo diálogo do Histórico: editar ou excluir, com
/// as mesmas travas de sempre. Não existe caminho novo para apagar dinheiro.
class UltimosLancamentos extends StatefulWidget {
  final Turno turno;
  final String maquinaAtiva;

  /// Muda a cada lançamento novo ou corrigido. É o sinal de que a lista precisa
  /// ser relida — sem isso ela ficaria mostrando o estado de antes do toque.
  final int versaoDados;

  final VoidCallback onAlterado;

  const UltimosLancamentos({
    super.key,
    required this.turno,
    required this.maquinaAtiva,
    required this.versaoDados,
    required this.onAlterado,
  });

  @override
  State<UltimosLancamentos> createState() => _UltimosLancamentosState();
}

class _UltimosLancamentosState extends State<UltimosLancamentos> {
  /// Dois bastam para pegar o erro do lançamento que acabou de entrar, e a
  /// terceira linha disputava espaço com a grade de formas de pagamento. O
  /// resto está a um toque, no Histórico.
  static const int _quantos = 2;

  List<Lancamento> _ultimos = const [];

  /// Lançamento que acabou de entrar: a linha dele brilha por um instante. É a
  /// confirmação do lançamento, no lugar onde o olho já está — no lugar da
  /// faixa verde que aparecia embaixo, por cima do rodapé.
  int? _idDestaque;
  Timer? _timerDestaque;
  bool _carregouUmaVez = false;

  @override
  void initState() {
    super.initState();
    // O banco avisa toda inclusão, correção e exclusão — venham da tela
    // Início, do "+" do rodapé ou do Histórico. Antes a lista só relia quando
    // a tela Início avisava, e um lançamento feito pelo "+" não aparecia aqui.
    DatabaseService.lancamentosNotifier.addListener(_carregar);
    _carregar();
  }

  @override
  void dispose() {
    DatabaseService.lancamentosNotifier.removeListener(_carregar);
    _timerDestaque?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant UltimosLancamentos anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.versaoDados != widget.versaoDados ||
        anterior.turno.id != widget.turno.id) {
      _carregar();
    }
  }

  Future<void> _carregar() async {
    final id = widget.turno.id;
    if (id == null) return;
    try {
      // A consulta já vem do mais novo para o mais antigo.
      final lista = await DatabaseService.instance.obterLancamentos(id);
      if (!mounted) return;
      final novos = lista.take(_quantos).toList();

      // Brilha so o que e novo de verdade: nao na abertura da tela, nem quando
      // uma correcao ou exclusao reordena a lista.
      final idsAntes = _ultimos.map((l) => l.id).toSet();
      final topo = novos.isEmpty ? null : novos.first.id;
      final chegouAgora = _carregouUmaVez && topo != null && !idsAntes.contains(topo);
      _carregouUmaVez = true;

      setState(() {
        _ultimos = novos;
        if (chegouAgora) _idDestaque = topo;
      });
      if (chegouAgora) {
        _timerDestaque?.cancel();
        _timerDestaque = Timer(const Duration(milliseconds: 1600), () {
          if (mounted) setState(() => _idDestaque = null);
        });
      }
    } catch (_) {
      // Lista de conferência: se a leitura falhar, a tela segue sem ela em vez
      // de travar o lançamento, que é o que o frentista veio fazer.
      if (mounted) setState(() => _ultimos = const []);
    }
  }

  void _corrigir(Lancamento lancamento) {
    final turnoId = widget.turno.id;
    if (turnoId == null || lancamento.id == null) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => EditLaunchDialog(
        lancamento: lancamento,
        maquinaAtiva: widget.maquinaAtiva,
        onSalvar: (dados) async {
          await DatabaseService.instance.atualizarLancamento(
            lancamento.id!,
            turnoId,
            dados.tipo,
            dados.valor,
            dados.descricao,
          );
          await _carregar();
          widget.onAlterado();
        },
        onDeletar: () async {
          await DatabaseService.instance.deletarLancamento(lancamento.id!, turnoId);
          await _carregar();
          widget.onAlterado();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No começo do turno não há o que conferir: o espaço fica para a grade.
    if (_ultimos.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppColors.radiusLg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 9),
            child: Row(
              children: [
                Text(
                  'ÚLTIMOS LANÇAMENTOS',
                  style: TextStyle(
                    fontSize: AppTexto.rotulo,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: textTer,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'toque para corrigir',
                    textAlign: TextAlign.right,
                    style: TextStyle(fontSize: AppTexto.rotulo, color: textTer),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          for (final lancamento in _ultimos)
            _Linha(
              lancamento: lancamento,
              primeira: lancamento == _ultimos.first,
              destacado: lancamento.id != null && lancamento.id == _idDestaque,
              borderColor: borderColor,
              textPri: textPri,
              textSec: textSec,
              textTer: textTer,
              onTap: () => _corrigir(lancamento),
            ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  final Lancamento lancamento;
  final bool primeira;
  final bool destacado;
  final Color borderColor;
  final Color textPri;
  final Color textSec;
  final Color textTer;
  final VoidCallback onTap;

  const _Linha({
    required this.lancamento,
    required this.primeira,
    this.destacado = false,
    required this.borderColor,
    required this.textPri,
    required this.textSec,
    required this.textTer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // O mesmo icone da grade, na cor do tipo — que aqui distingue a bandeira:
    // todo cartao usa o mesmo icone, e a cor e o nome dizem qual foi.
    final cor = AppColors.getCorTipo(lancamento.tipo);
    // Sem sinal nem cor de alerta no valor: quem diz o que o lançamento faz com
    // a gaveta é o tipo, e essa conta já é feita no resumo e no PDF. Inventar
    // um "menos" aqui contradiria o total geral, onde despesa entra somando.
    final valor = CurrencyFormatter.formatar(lancamento.valor);
    // "17:49:02" vira "17:49". Os segundos nao ajudam a reconhecer o
    // lancamento e roubavam a largura que o valor precisa para crescer.
    final hora = lancamento.hora.length >= 5
        ? lancamento.hora.substring(0, 5)
        : lancamento.hora;

    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        // Entra acesa e apaga devagar: diz "entrou" sem pedir atencao depois.
        duration: Duration(milliseconds: destacado ? 150 : 900),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: destacado ? cor.withValues(alpha: 0.16) : cor.withValues(alpha: 0),
          border: Border(top: BorderSide(color: borderColor)),
        ),
        child: Row(
          children: [
            Text(
              hora,
              style: TextStyle(
                fontFamily: AppTexto.numeros,
                fontSize: AppTexto.rotulo,
                color: textTer,
              ),
            ),
            const SizedBox(width: 9),
            Icon(AppIcones.doTipo(lancamento.tipo), size: 16, color: cor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                lancamento.tipo,
                style: TextStyle(fontSize: AppTexto.corpo, color: textSec),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              valor,
              style: TextStyle(
                fontFamily: AppTexto.numeros,
                fontSize: AppTexto.valor,
                fontWeight: FontWeight.w600,
                color: textPri,
              ),
            ),
            if (primeira) ...[
              const SizedBox(width: 8),
              Icon(Icons.edit_rounded, size: 16, color: textTer),
            ],
          ],
        ),
      ),
    );
  }
}

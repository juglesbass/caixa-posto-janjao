import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/turno.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../widgets/cabecalho_turno.dart';
import '../widgets/janela.dart';

class TurnosAnterioresDialog extends StatefulWidget {
  final Function(Turno turno) onReabrirTurno;

  const TurnosAnterioresDialog({super.key, required this.onReabrirTurno});

  @override
  State<TurnosAnterioresDialog> createState() => _TurnosAnterioresDialogState();
}

class _TurnosAnterioresDialogState extends State<TurnosAnterioresDialog> {
  List<Turno> _turnos = [];
  bool _carregando = true;

  @override
  void initState() {
    super.initState();
    _carregar();
  }

  void _carregar() async {
    setState(() => _carregando = true);
    final db = DatabaseService.instance;
    final lista = await db.obterTodosTurnos();
    if (mounted) {
      setState(() {
        _turnos = lista;
        _carregando = false;
      });
    }
  }

  void _solicitarReabertura(Turno t) async {
    // Reabrir fecha o turno que estiver aberto, e esse fechamento não gera
    // relatório nem envia nada ao Drive. Desde 25/08 isso acontecia em silêncio
    // — pelo menu Configurações dava para, no meio do turno, reabrir um antigo e
    // perder o relatório do atual sem saber. Mesma correção do "Trocar
    // operador" (6428276): continua possível, mas como escolha declarada.
    final aberto = await DatabaseService.instance.obterTurnoAberto();
    if (!mounted) return;
    if (aberto != null && aberto.id != t.id) {
      final confirmou = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const TituloJanela('Fechar o turno atual?', icone: Icons.warning_amber_rounded, cor: AppColors.amber),
          content: TextoJanela(
            'O turno #${aberto.numero} está aberto no nome de ${aberto.operador}.\n\n'
            'Reabrir o turno #${t.numero} fecha esse turno. Esse fechamento não '
            'gera relatório nem envia nada ao Google Drive.\n\n'
            'Para encerrar com relatório, use "Fechar Caixa & Resumo" antes de reabrir.',
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            BotoesJanela(
              secundario: BotaoSecundario(texto: 'Cancelar', onPressed: () => Navigator.of(ctx).pop(false)),
              principal: BotaoPrincipal(
                texto: 'Fechar e reabrir',
                cor: AppColors.red,
                onPressed: () => Navigator.of(ctx).pop(true),
              ),
            ),
          ],
        ),
      );
      if (confirmou != true || !mounted) return;
    }

    final autorizado = await showDialog<bool>(
      context: context,
      builder: (_) => _PinReaberturaDialog(turno: t),
    );

    if (autorizado == true && mounted) {
      Navigator.of(context).pop();
      widget.onReabrirTurno(t);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final blocoBg = isDark ? AppColors.darkBg : AppColors.lightBg;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          children: [
            CabecalhoJanela(
              icone: Icons.history_rounded,
              cor: AppColors.blue,
              titulo: 'Histórico de Turnos',
              subtitulo: 'Consultar e reabrir turnos anteriores',
              onFechar: () => Navigator.of(context).pop(),
            ),
            Divider(color: borderCol, height: 24),

            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator(color: AppColors.blue))
                  : _turnos.isEmpty
                      ? Center(
                          child: Text(
                            'Nenhum turno registrado.',
                            style: TextStyle(color: textSec, fontSize: AppTexto.corpo),
                          ),
                        )
                      // Um bloco só, do tamanho da lista, separado por fio.
                      : Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: blocoBg,
                              borderRadius: BorderRadius.circular(AppColors.radiusLg),
                              border: Border.all(color: borderCol),
                            ),
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: _turnos.length,
                              separatorBuilder: (_, __) => Divider(height: 1, thickness: 1, color: borderCol),
                              itemBuilder: (context, index) {
                                final t = _turnos[index];
                                final statusAberto = t.aberto;

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                                  child: Row(
                                    children: [
                                      // Largura mínima alinha os nomes; número maior só empurra.
                                      Container(
                                        constraints: const BoxConstraints(minWidth: 40),
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Text(
                                          '#${t.numero}',
                                          style: TextStyle(
                                            fontFamily: AppTexto.numeros,
                                            color: statusAberto ? AppColors.green : textTer,
                                            fontWeight: FontWeight.w600,
                                            fontSize: AppTexto.corpo,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.operador,
                                              style: TextStyle(
                                                color: textPri,
                                                fontWeight: FontWeight.w700,
                                                fontSize: AppTexto.corpo,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Abertura: ${t.data}',
                                              style: TextStyle(color: textSec, fontSize: AppTexto.rotulo),
                                            ),
                                            // Só quando difere do dia da abertura: é o caso que
                                            // antes confundia a conferência
                                            if (t.dataCaixa != t.data.trim().split(' ').first) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                'Caixa do dia ${t.dataCaixa}',
                                                style: const TextStyle(
                                                  color: AppColors.accentLight,
                                                  fontSize: AppTexto.rotulo,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                            if (t.fechadoEm != null) ...[
                                              const SizedBox(height: 1),
                                              Text(
                                                'Fechado: ${t.fechadoEm}',
                                                style: TextStyle(color: textTer, fontSize: AppTexto.rotulo),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      if (!statusAberto)
                                        OutlinedButton.icon(
                                          onPressed: () => _solicitarReabertura(t),
                                          icon: const Icon(Icons.lock_open_rounded, size: 16),
                                          label: const Text(
                                            'Reabrir',
                                            style: TextStyle(fontSize: AppTexto.corpo - 1, fontWeight: FontWeight.w700),
                                          ),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: AppColors.accentLight,
                                            side: BorderSide(color: AppColors.accentLight.withValues(alpha: 0.5)),
                                            minimumSize: const Size(0, 40),
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(AppColors.radiusSm),
                                            ),
                                          ),
                                        )
                                      else
                                        const SeloTurno(texto: 'Em andamento', cor: AppColors.green),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: BotaoSecundario(texto: 'Fechar', onPressed: () => Navigator.of(context).pop()),
            ),
          ],
        ),
      ),
    );
  }
}

/// PIN que autoriza reabrir um turno: o do operador dele ou o do
/// desenvolvedor. Com estado próprio, o campo só é descartado quando a janela
/// sai de vez (o teclado fechando redesenha a janela na saída).
class _PinReaberturaDialog extends StatefulWidget {
  final Turno turno;

  const _PinReaberturaDialog({required this.turno});

  @override
  State<_PinReaberturaDialog> createState() => _PinReaberturaDialogState();
}

class _PinReaberturaDialogState extends State<_PinReaberturaDialog> {
  final _controller = TextEditingController();
  String? _erro;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _autorizar() async {
    final pin = _controller.text.trim();
    final ok = await AuthService.validarPin(widget.turno.operador, pin);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      AppHaptics.heavy();
      setState(() {
        _erro = 'PIN incorreto. Acesso negado.';
      });
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final t = widget.turno;

    return AlertDialog(
      title: TituloJanela('Reabrir Turno #${t.numero}', icone: Icons.lock_open_rounded),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextoJanela('Digite o PIN de ${t.operador} ou do desenvolvedor para autorizar a reabertura:'),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 4,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: TextStyle(
              fontSize: 20,
              letterSpacing: 8,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPri : AppColors.lightTextPri,
            ),
            decoration: InputDecoration(
              labelText: 'PIN de 4 dígitos',
              counterText: '',
              prefixIcon: const Icon(Icons.shield_outlined),
              errorText: _erro,
              filled: true,
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
            ),
            onSubmitted: (_) => _autorizar(),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        BotoesJanela(
          secundario: BotaoSecundario(texto: 'Cancelar', onPressed: () => Navigator.of(context).pop(false)),
          principal: BotaoPrincipal(texto: 'Autorizar Reabertura', onPressed: _autorizar),
        ),
      ],
    );
  }
}

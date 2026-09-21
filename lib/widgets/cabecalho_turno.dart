import 'package:flutter/material.dart';

import '../models/turno.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';

/// Quem está no caixa, de que dia é o caixa e a que horas ele abriu.
///
/// Antes isso ficava espalhado: o nome do posto no título, operador e data no
/// subtítulo, o modo teste num selo colado ao nome do posto. Junto num lugar
/// só, vira a assinatura da tela — e é o componente que o Resumo vai usar
/// também, para as duas telas falarem do turno do mesmo jeito.
class CabecalhoTurno extends StatelessWidget {
  final Turno turno;

  const CabecalhoTurno({super.key, required this.turno});

  /// Mesma regra da tela de identificação: primeira letra do primeiro nome e
  /// do último. "Agildo Gomes" vira AG, "Bruno" vira B — o frentista vê no
  /// caixa o mesmo quadradinho em que tocou para entrar.
  static String _iniciais(String nome) {
    final partes =
        nome.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.substring(0, 1).toUpperCase();
    return '${partes.first.substring(0, 1)}${partes.last.substring(0, 1)}'
        .toUpperCase();
  }

  /// "20/09/2026" vira "20/09". O ano não cabe na linha e não ajuda: a dúvida
  /// do frentista é sempre "de que dia é este caixa", nunca de que ano.
  ///
  /// É a data do CAIXA, não a da abertura — e o número do turno saiu daqui
  /// porque o WebPost reinicia a contagem todo dia, então ele não diz nada a
  /// ninguém. O número continua no banco.
  static String _dataCurta(String dataCaixa) {
    final texto = dataCaixa.trim();
    return texto.length >= 5 ? texto.substring(0, 5) : texto;
  }

  /// "20/09/2026 17:30" vira "17h30". É a hora em que o turno foi aberto, que
  /// nem sempre cai no dia do caixa: o caixa da madrugada abre depois da
  /// meia-noite e pertence ao dia anterior — ver as duas coisas juntas é o
  /// que tira a dúvida. Sem hora gravada, a linha fica só com a data.
  static String? _horaAbertura(String dataAbertura) {
    final partes = dataAbertura.trim().split(' ');
    if (partes.length < 2) return null;
    final hm = partes[1].split(':');
    if (hm.length < 2 || hm[0].isEmpty || hm[1].isEmpty) return null;
    return '${hm[0]}h${hm[1]}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    final hora = _horaAbertura(turno.data);
    final linha = 'Caixa ${_dataCurta(turno.dataCaixa)}'
        '${hora != null ? ' · aberto $hora' : ''}';

    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: Text(
            _iniciais(turno.operador),
            style: const TextStyle(
              color: Colors.white,
              fontSize: AppTexto.rotulo,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                turno.operador,
                style: TextStyle(
                  fontSize: AppTexto.corpo,
                  fontWeight: FontWeight.w700,
                  color: textPri,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 1),
              Text(
                linha,
                style: TextStyle(fontSize: AppTexto.rotulo, color: textSec),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Selo de estado na ponta da barra do turno: uma palavra, a cor do estado.
///
/// Hoje só o modo teste usa. É o lugar reservado para o "Entregue / Conferir"
/// da proposta, quando ficar decidido o que esse estado quer dizer durante um
/// turno ainda aberto.
class SeloTurno extends StatelessWidget {
  final String texto;
  final Color cor;

  const SeloTurno({super.key, required this.texto, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppColors.radiusXs),
        border: Border.all(color: cor.withValues(alpha: 0.4)),
      ),
      child: Text(
        texto.toUpperCase(),
        style: TextStyle(
          fontSize: AppTexto.rotulo,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: cor,
        ),
      ),
    );
  }
}

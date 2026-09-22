import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_icones.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../utils/payment_types.dart';

/// As seis formas de pagamento, em duas colunas.
///
/// Cada card tem o quadrado com o ícone da forma, o nome e uma linha de apoio
/// (na de Cartões, a bandeira escolhida). O card escolhido acende inteiro na
/// cor da própria forma — fundo, borda e um brilho — e ganha um ✓ no canto do
/// ícone: um sinal de forma, além do de cor, que continua visível no sol, na
/// tela suja e para quem confunde cores.
class PaymentGrid extends StatelessWidget {
  final String tipoAtivo;
  final String bandeiraCartaoAtiva;
  final ValueChanged<String> onSelecionarTipo;
  final VoidCallback onAbrirSeletorCartoes;

  /// Versão baixa, sem a linha de apoio, para o lançamento rápido do "+": lá a
  /// grade divide a tela com o teclado, e o valor e o botão Lançar precisam
  /// ficar acima dele.
  final bool compacto;

  const PaymentGrid({
    super.key,
    required this.tipoAtivo,
    required this.bandeiraCartaoAtiva,
    required this.onSelecionarTipo,
    required this.onAbrirSeletorCartoes,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final ehCartaoAtivo = PaymentTypes.ehCartao(tipoAtivo);

    // Linha de apoio curta de propósito: num celular de 375px sobram uns 80px
    // de largura para o texto, e "Faturado / prazo" sairia cortado.
    final formas = <_Forma>[
      _Forma('Dinheiro', 'Espécie', AppIcones.dinheiro, AppColors.green,
          tipoAtivo == PaymentTypes.dinheiro, () => onSelecionarTipo(PaymentTypes.dinheiro)),
      _Forma('Pag Pix', 'Instantâneo', AppIcones.pix, AppColors.blue,
          tipoAtivo == PaymentTypes.pix, () => onSelecionarTipo(PaymentTypes.pix)),
      _Forma('Cartões', bandeiraCartaoAtiva, AppIcones.cartao, AppColors.purple,
          ehCartaoAtivo, onAbrirSeletorCartoes,
          isCartao: true),
      _Forma('Requisição', 'Faturado', AppIcones.requisicao, AppColors.amber,
          tipoAtivo == PaymentTypes.requisicao, () => onSelecionarTipo(PaymentTypes.requisicao)),
      _Forma('Depósito', 'Bancário', AppIcones.deposito, AppColors.brown,
          tipoAtivo == PaymentTypes.depositoGlobal, () => onSelecionarTipo(PaymentTypes.depositoGlobal)),
      _Forma('Despesas', 'Retirada', AppIcones.despesas, AppColors.red,
          tipoAtivo == PaymentTypes.despesas, () => onSelecionarTipo(PaymentTypes.despesas)),
    ];

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // Altura fixa, e nao proporcao da largura: com proporcao, o botao
      // encolhia junto com o celular, e num aparelho de 375px o de Cartoes
      // ficava mais baixo que o proprio conteudo.
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        mainAxisExtent: compacto ? 64 : 76,
      ),
      children: [
        for (final f in formas) _CardMetodo(forma: f, compacto: compacto),
      ],
    );
  }
}

class _Forma {
  final String label;
  final String subtitulo;
  final IconData icon;
  final Color cor;
  final bool selecionado;
  final VoidCallback onTap;
  final bool isCartao;

  const _Forma(this.label, this.subtitulo, this.icon, this.cor, this.selecionado, this.onTap,
      {this.isCartao = false});
}

class _CardMetodo extends StatelessWidget {
  final _Forma forma;
  final bool compacto;

  const _CardMetodo({required this.forma, required this.compacto});

  /// "Master Débito" nao cabe na pastilha, e cortado no meio ("Master Dé...")
  /// e pior que abreviado. Crédito e Débito viram Créd. e Déb., que e como o
  /// pessoal fala e como sai na maquininha.
  static String _bandeiraCurta(String bandeira) {
    return bandeira
        .replaceAll(' ▼', '')
        .replaceAll('Crédito', 'Créd.')
        .replaceAll('Débito', 'Déb.')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    final sel = forma.selecionado;
    final cor = isDark && forma.cor == AppColors.purple ? AppColors.purpleLight : forma.cor;
    final fundo = sel
        ? Color.alphaBlend(cor.withValues(alpha: isDark ? 0.20 : 0.10), surfaceColor)
        : surfaceColor;

    final lado = compacto ? 32.0 : 44.0;

    // A borda do selecionado tem 2px, e o Container soma a borda ao recuo.
    // Sem descontar 1px, o conteudo pulava ao tocar e saia da linha dos
    // outros blocos da tela (o icone fica sempre a 16 da borda do card).
    final vertical = compacto ? 10.0 : 15.0;
    final padding = EdgeInsets.symmetric(
      horizontal: sel ? 15 : 16,
      vertical: sel ? vertical - 1 : vertical,
    );

    return InkWell(
      onTap: () {
        AppHaptics.light();
        forma.onTap();
      },
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: padding,
        decoration: BoxDecoration(
          color: fundo,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(
            color: sel ? cor : borderColor,
            width: sel ? 2.0 : 1.0,
          ),
          // Um brilho so, no card escolhido: e ele que diz "o proximo
          // lancamento entra aqui". Nos outros, nenhuma sombra.
          boxShadow: sel
              ? [
                  BoxShadow(
                    color: cor.withValues(alpha: isDark ? 0.35 : 0.22),
                    blurRadius: 14,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _Tile(
              icon: forma.icon,
              cor: cor,
              lado: lado,
              isDark: isDark,
              selecionado: sel,
              corDoFundo: fundo,
            ),
            SizedBox(width: compacto ? 10 : 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Encolhe em vez de cortar: "Requisição" passa por pouco da
                  // largura num celular de 375px.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      forma.label,
                      style: TextStyle(
                        fontSize: AppTexto.corpo,
                        fontWeight: sel ? FontWeight.w800 : FontWeight.w700,
                        // Altura de linha propria: sem ela o texto herda 1,43
                        // do tema e nome + linha de apoio passam do card.
                        height: 1.2,
                        color: textPri,
                      ),
                    ),
                  ),
                  if (forma.isCartao) ...[
                    const SizedBox(height: 2),
                    _Bandeira(
                      texto: _bandeiraCurta(forma.subtitulo),
                      cor: cor,
                      selecionado: sel,
                      isDark: isDark,
                    ),
                  ] else if (!compacto) ...[
                    const SizedBox(height: 3),
                    Text(
                      forma.subtitulo,
                      style: TextStyle(fontSize: AppTexto.rotulo, height: 1.2, color: textSec),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// O quadrado com o ícone da forma. No escolhido ganha um ✓ no canto.
class _Tile extends StatelessWidget {
  final IconData icon;
  final Color cor;
  final double lado;
  final bool isDark;
  final bool selecionado;

  /// Cor do card por trás: o contorno do ✓ usa ela, para o selo parecer
  /// recortado no quadrado em vez de colado por cima.
  final Color corDoFundo;

  const _Tile({
    required this.icon,
    required this.cor,
    required this.lado,
    required this.isDark,
    required this.selecionado,
    required this.corDoFundo,
  });

  @override
  Widget build(BuildContext context) {
    final quadrado = Container(
      width: lado,
      height: lado,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cor.withValues(alpha: selecionado ? (isDark ? 0.30 : 0.20) : (isDark ? 0.16 : 0.12)),
        borderRadius: BorderRadius.circular(lado > 36 ? AppColors.radiusSm : AppColors.radiusXs),
      ),
      child: Icon(icon, size: lado > 36 ? 24 : 18, color: cor),
    );

    if (!selecionado) return quadrado;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        quadrado,
        Positioned(
          top: -5,
          right: -5,
          child: Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: cor,
              shape: BoxShape.circle,
              border: Border.all(color: corDoFundo, width: 2),
            ),
            child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

/// A bandeira escolhida, na pastilha que abre a lista de bandeiras.
class _Bandeira extends StatelessWidget {
  final String texto;
  final Color cor;
  final bool selecionado;
  final bool isDark;

  const _Bandeira({
    required this.texto,
    required this.cor,
    required this.selecionado,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final corTexto = selecionado ? textPri : textSec;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: selecionado
              ? cor.withValues(alpha: isDark ? 0.24 : 0.14)
              : (isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selecionado ? cor.withValues(alpha: 0.5) : borderColor,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Encolhe em vez de cortar: "Master Déb." no celular de 375px.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  texto,
                  style: TextStyle(
                    fontSize: AppTexto.rotulo,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: corTexto,
                  ),
                ),
              ),
            ),
            Icon(Icons.arrow_drop_down_rounded, size: 12, color: corTexto),
          ],
        ),
      ),
    );
  }
}

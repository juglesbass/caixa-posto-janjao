import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';

/// As quatro abas da proposta — Início, Histórico, Resumo, Menu — com o "+"
/// no meio, que abre o lançamento rápido por cima de qualquer aba.
///
/// A proposta desenhava a barra sem o "+"; ele ficou porque é o atalho que o
/// posto usa. Entrou na mesma língua do resto: sem sombra, na cor que o app
/// reserva para botão.
class BottomNavBar extends StatelessWidget {
  final int indiceAtual;
  final ValueChanged<int> onTrocarAba;
  final VoidCallback onAbrirLancamentoRapido;

  const BottomNavBar({
    super.key,
    required this.indiceAtual,
    required this.onTrocarAba,
    required this.onAbrirLancamentoRapido,
  });

  @override
  Widget build(BuildContext context) {
    // Se o teclado virtual estiver aberto, ocultar a barra para não sobrepor inputs
    final tecladoAberto = MediaQuery.of(context).viewInsets.bottom > 0;
    if (tecladoAberto) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;

    void trocar(int aba) {
      AppHaptics.selection();
      onTrocarAba(aba);
    }

    // Separação por borda, sem sombra: mesma regra do resto do app, e uma
    // camada de desfoque a menos para o celular fraco desenhar. É Material, e
    // não Container, para o efeito de toque das abas aparecer — um Container
    // opaco pinta por cima dele.
    return Material(
      color: surfaceColor,
      shape: Border(top: BorderSide(color: borderColor)),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _ItemNav(
              icon: Icons.home_rounded,
              label: 'Início',
              ativo: indiceAtual == 0,
              onTap: () => trocar(0),
              textSec: textSec,
            ),
            _ItemNav(
              icon: Icons.receipt_long_rounded,
              label: 'Histórico',
              ativo: indiceAtual == 1,
              onTap: () => trocar(1),
              textSec: textSec,
            ),
            // Lançamento rápido: largura fixa no centro, as abas dividem o resto.
            // heightFactor 1: sem ele o Center se estica até a altura da tela e
            // a barra inteira cresce junto, cobrindo o conteúdo.
            SizedBox(
              width: 64,
              child: Center(
                heightFactor: 1,
                child: Semantics(
                  button: true,
                  label: 'Lançamento rápido',
                  child: Material(
                    color: AppColors.accent,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: () {
                        AppHaptics.light();
                        onAbrirLancamentoRapido();
                      },
                      customBorder: const CircleBorder(),
                      child: const SizedBox(
                        width: 46,
                        height: 46,
                        child: Icon(Icons.add_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _ItemNav(
              icon: Icons.bar_chart_rounded,
              label: 'Resumo',
              ativo: indiceAtual == 2,
              onTap: () => trocar(2),
              textSec: textSec,
            ),
            _ItemNav(
              icon: Icons.more_horiz_rounded,
              label: 'Menu',
              ativo: indiceAtual == 3,
              onTap: () => trocar(3),
              textSec: textSec,
            ),
          ],
        ),
      ),
    );
  }
}

/// Uma aba. Ocupa um quarto da largura inteira, não só o ícone: o dedo acerta
/// em qualquer ponto da coluna, que é o que importa com o celular numa mão só.
class _ItemNav extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool ativo;
  final VoidCallback onTap;
  final Color textSec;

  const _ItemNav({
    required this.icon,
    required this.label,
    required this.ativo,
    required this.onTap,
    required this.textSec,
  });

  @override
  Widget build(BuildContext context) {
    final cor = ativo ? AppColors.accentLight : textSec;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 9, bottom: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: cor, size: 22),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTexto.rotulo,
                  fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
                  color: cor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

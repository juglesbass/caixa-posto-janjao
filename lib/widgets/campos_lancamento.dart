import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/currency_formatter.dart';

/// O campo do valor da venda, com o botão Lançar colado nele.
///
/// É o mesmo na tela Início e no lançamento rápido do "+", para os dois
/// lugares onde se lança dinheiro terem a mesma cara e o mesmo jeito. O botão
/// fica dentro do campo de propósito: o teclado numérico do iPhone não tem
/// tecla de confirmar, e colado no valor ele nunca some atrás do teclado.
class CampoValorVenda extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool autofocus;

  /// Mostra o botão Lançar — só quando há valor digitado.
  final bool podeLancar;

  /// Desliga o botão enquanto um lançamento está sendo gravado, para um toque
  /// duplo não lançar duas vezes.
  final bool enviando;

  final String? erro;
  final ValueChanged<String> onChanged;
  final VoidCallback onLancar;

  /// Rótulo do campo. Na correção de um lançamento vira só "Valor".
  final String rotulo;

  const CampoValorVenda({
    super.key,
    required this.controller,
    this.focusNode,
    this.autofocus = false,
    required this.podeLancar,
    this.enviando = false,
    this.erro,
    required this.onChanged,
    required this.onLancar,
    this.rotulo = 'Valor da Venda',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [CurrencyInputFormatter()],
      textInputAction: TextInputAction.done,
      style: TextStyle(
        fontSize: AppTexto.entrada,
        fontWeight: FontWeight.w800,
        color: textPri,
      ),
      decoration: InputDecoration(
        labelText: rotulo,
        labelStyle: TextStyle(fontSize: AppTexto.corpo, fontWeight: FontWeight.bold, color: textSec),
        hintText: 'R\$ 0,00',
        // Icone na mesma linha do primeiro elemento de todo bloco da tela.
        // 17 = recuo de 16 + 1 da borda: nos cartoes a borda ocupa espaco, no
        // campo ela e desenhada por fora. Sem isso o Flutter centraliza o
        // icone numa caixa de 48.
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 17, right: 8),
          child: Icon(Icons.attach_money_rounded, color: AppColors.accentLight, size: 26),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 48),
        suffixIcon: podeLancar
            ? Padding(
                padding: const EdgeInsets.only(right: 6, top: 6, bottom: 6),
                child: ElevatedButton.icon(
                  onPressed: enviando ? null : onLancar,
                  icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                  label: const Text(
                    'LANÇAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: AppTexto.corpo,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    // Sem sombra: profundidade por borda e cor, como o resto.
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
              )
            : null,
        errorText: erro,
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.accentLight, width: 2),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: (_) => onLancar(),
    );
  }
}

/// Descrição, placa ou observação do lançamento — opcional. Mesmo campo na
/// tela Início e no lançamento rápido.
class CampoDescricao extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onSubmitted;

  const CampoDescricao({super.key, required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return TextField(
      controller: controller,
      decoration: InputDecoration(
        // Mais curto que o "Descrição / Placa / Observação (Opcional)" de
        // antes, que era cortado com reticências em celular de 375px.
        labelText: 'Descrição / placa (opcional)',
        hintText: 'Ex: troca de óleo, placa ABC-1234',
        prefixIcon: const Padding(
          padding: EdgeInsets.only(left: 17, right: 8),
          child: Icon(Icons.edit_note_rounded),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 40),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: BorderSide(color: borderColor),
        ),
      ),
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
    );
  }
}

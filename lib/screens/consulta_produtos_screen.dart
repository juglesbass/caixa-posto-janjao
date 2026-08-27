import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/produtos_data.dart';
import '../theme/app_colors.dart';

class ConsultaProdutosScreen extends StatefulWidget {
  const ConsultaProdutosScreen({super.key});

  @override
  State<ConsultaProdutosScreen> createState() => _ConsultaProdutosScreenState();
}

class _ConsultaProdutosScreenState extends State<ConsultaProdutosScreen> {
  final _buscaController = TextEditingController();
  final _focusNode = FocusNode();
  String _termoBusca = '';
  String _categoriaSelecionada = 'Todos';

  final List<String> _categorias = [
    'Todos',
    'Lubrificantes & Fluidos',
    'Cuidados & Aromatizantes',
    'Conveniência & Bebidas',
    'Arla 32',
    'Recipientes & Acessórios',
  ];

  @override
  void dispose() {
    _buscaController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Remove acentos e caracteres especiais para busca insensível
  String _normalizar(String texto) {
    var resultado = texto.toLowerCase();
    const mapaAcentos = {
      'a': ['á', 'à', 'â', 'ã', 'ä'],
      'e': ['é', 'è', 'ê', 'ë'],
      'i': ['í', 'ì', 'î', 'ï'],
      'o': ['ó', 'ò', 'ô', 'õ', 'ö'],
      'u': ['ú', 'ù', 'û', 'ü'],
      'c': ['ç'],
    };

    mapaAcentos.forEach((letra, acentos) {
      for (final a in acentos) {
        resultado = resultado.replaceAll(a, letra);
      }
    });

    return resultado;
  }

  List<Produto> get _produtosFiltrados {
    final termoNorm = _normalizar(_termoBusca.trim());

    return ProdutosData.listaProdutos.where((p) {
      // Filtro por Categoria
      if (_categoriaSelecionada != 'Todos' && p.categoria != _categoriaSelecionada) {
        return false;
      }

      // Se busca estiver vazia, retorna todos da categoria
      if (termoNorm.isEmpty) return true;

      // Busca por Código (com ou sem zeros à esquerda)
      final codigoLimpo = p.codigo.toLowerCase();
      final codigoSemZeros = codigoLimpo.replaceFirst(RegExp(r'^0+'), '');
      if (codigoLimpo.contains(termoNorm) || (codigoSemZeros.isNotEmpty && codigoSemZeros.contains(termoNorm))) {
        return true;
      }

      // Busca por Descrição
      final descNorm = _normalizar(p.descricao);
      if (descNorm.contains(termoNorm)) {
        return true;
      }

      return false;
    }).toList();
  }

  void _copiarCodigo(Produto p) {
    Clipboard.setData(ClipboardData(text: p.codigo));
    HapticFeedback.lightImpact();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Código ${p.codigo} copiado! (${p.descricao})',
                style: const TextStyle(fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgScaffold = isDark ? const Color(0xFF08090F) : AppColors.lightBg;
    final surfaceCard = isDark ? const Color(0xFF131C2E) : AppColors.lightSurface;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;

    final lista = _produtosFiltrados;

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        title: const Column(
          children: [
            Text(
              'Consulta de Produtos',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.2),
            ),
            Text(
              'Tabela de códigos rápidos do posto',
              style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Barra Fixa de Pesquisa ──
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF111420) : Colors.white,
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _buscaController,
                    focusNode: _focusNode,
                    onChanged: (v) => setState(() => _termoBusca = v),
                    style: TextStyle(color: textPri, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Buscar por código (ex: 00488) ou nome...',
                      hintStyle: TextStyle(color: textSec, fontSize: 13),
                      prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF38BDF8), size: 22),
                      suffixIcon: _termoBusca.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _buscaController.clear();
                                setState(() => _termoBusca = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF181D2E) : const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // ── Filtro Rápido por Categorias ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _categorias.map((cat) {
                        final selecionada = _categoriaSelecionada == cat;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(
                              cat,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: selecionada ? FontWeight.bold : FontWeight.normal,
                                color: selecionada
                                    ? Colors.white
                                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                              ),
                            ),
                            selected: selecionada,
                            selectedColor: const Color(0xFF2563EB),
                            backgroundColor: isDark ? const Color(0xFF181D2E) : const Color(0xFFE2E8F0),
                            side: BorderSide(
                              color: selecionada ? const Color(0xFF2563EB) : borderCol,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            onSelected: (val) {
                              if (val) {
                                HapticFeedback.selectionClick();
                                setState(() => _categoriaSelecionada = cat);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),

            // ── Barra de Status / Contagem de Resultados ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${lista.length} produto(s) encontrado(s)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textSec,
                    ),
                  ),
                  Text(
                    'Toque para copiar o código',
                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),

            // ── Lista de Produtos ──
            Expanded(
              child: lista.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF181D2E) : const Color(0xFFE2E8F0),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.search_off_rounded, size: 40, color: Color(0xFF38BDF8)),
                            ),
                            const SizedBox(height: 14),
                            Text(
                              'Nenhum produto encontrado',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Verifique se digitou o código ou nome correto.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 12, color: textSec),
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () {
                                _buscaController.clear();
                                setState(() {
                                  _termoBusca = '';
                                  _categoriaSelecionada = 'Todos';
                                });
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Limpar Filtros'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2563EB),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 6, 14, 16),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = lista[index];
                        return InkWell(
                          onTap: () => _copiarCodigo(p),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: surfaceCard,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: borderCol),
                            ),
                            child: Row(
                              children: [
                                // Badge do Código
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7).withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.4)),
                                  ),
                                  child: Text(
                                    p.codigo,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF38BDF8),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),

                                // Descrição e Categoria
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.descricao,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: textPri,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        p.categoria,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Botão Copiar
                                IconButton(
                                  icon: const Icon(
                                    Icons.copy_rounded,
                                    size: 18,
                                    color: Color(0xFF38BDF8),
                                  ),
                                  tooltip: 'Copiar código ${p.codigo}',
                                  onPressed: () => _copiarCodigo(p),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

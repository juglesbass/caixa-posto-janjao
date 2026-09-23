import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/produtos_data.dart';
import '../theme/app_colors.dart';
import '../theme/app_texto.dart';
import '../utils/app_haptics.dart';
import '../widgets/filtro_pilula.dart';
import '../widgets/janela.dart';

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
    AppHaptics.light();

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
    final bgScaffold = isDark ? AppColors.darkBg : AppColors.lightBg;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final campoBg = isDark ? AppColors.darkSurfaceSubtle : AppColors.lightSurfaceSubtle;
    final textPri = isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final textTer = isDark ? AppColors.darkTextTer : AppColors.lightTextTer;
    final borderCol = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    final corCodigo = isDark ? AppColors.accentLight : AppColors.accent;

    final lista = _produtosFiltrados;

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        title: Column(
          children: [
            const Text(
              'Consulta de Produtos',
              style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700),
            ),
            Text(
              'Tabela de códigos rápidos do posto',
              style: TextStyle(fontSize: AppTexto.rotulo, color: textSec),
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
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              decoration: BoxDecoration(
                color: surface,
                border: Border(bottom: BorderSide(color: borderCol)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _buscaController,
                    focusNode: _focusNode,
                    onChanged: (v) => setState(() => _termoBusca = v),
                    style: TextStyle(color: textPri, fontSize: AppTexto.corpo),
                    decoration: InputDecoration(
                      hintText: 'Buscar por código (ex: 00488) ou nome...',
                      hintStyle: TextStyle(color: textSec, fontSize: AppTexto.corpo - 1),
                      prefixIcon: Icon(Icons.search_rounded, color: textSec, size: 22),
                      suffixIcon: _termoBusca.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              tooltip: 'Limpar busca',
                              onPressed: () {
                                _buscaController.clear();
                                setState(() => _termoBusca = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: campoBg,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide: BorderSide(color: borderCol),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        borderSide: BorderSide(color: corCodigo, width: 1.5),
                      ),
                    ),
                  ),

                  // ── Filtro Rápido por Categorias ──
                  SizedBox(
                    height: 52,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      children: [
                        for (final cat in _categorias)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FiltroPilula(
                              texto: cat,
                              selecionado: _categoriaSelecionada == cat,
                              onTap: () {
                                AppHaptics.selection();
                                setState(() => _categoriaSelecionada = cat);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Barra de Status / Contagem de Resultados ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${lista.length} produto(s) encontrado(s)',
                      style: TextStyle(fontSize: AppTexto.rotulo, fontWeight: FontWeight.w600, color: textSec),
                    ),
                  ),
                  Text(
                    'Toque para copiar o código',
                    style: TextStyle(fontSize: AppTexto.rotulo, color: textTer),
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
                            IconeJanela(icone: Icons.search_off_rounded, cor: corCodigo, tamanho: 64),
                            const SizedBox(height: 14),
                            Text(
                              'Nenhum produto encontrado',
                              style: TextStyle(fontSize: AppTexto.valor, fontWeight: FontWeight.w700, color: textPri),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Verifique se digitou o código ou nome correto.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: AppTexto.corpo - 1, color: textSec),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 200,
                              child: BotaoPrincipal(
                                texto: 'Limpar Filtros',
                                icone: Icons.refresh_rounded,
                                onPressed: () {
                                  _buscaController.clear();
                                  setState(() {
                                    _termoBusca = '';
                                    _categoriaSelecionada = 'Todos';
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final p = lista[index];
                        return Material(
                          color: surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppColors.radiusMd),
                            side: BorderSide(color: borderCol),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _copiarCodigo(p),
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
                              child: Row(
                                children: [
                                  // Código em coluna: o que o frentista procura primeiro
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 64),
                                    padding: const EdgeInsets.only(right: 12),
                                    child: Text(
                                      p.codigo,
                                      style: TextStyle(
                                        fontFamily: AppTexto.numeros,
                                        fontSize: AppTexto.valor,
                                        fontWeight: FontWeight.w600,
                                        color: corCodigo,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.descricao,
                                          style: TextStyle(
                                            fontSize: AppTexto.corpo,
                                            fontWeight: FontWeight.w700,
                                            color: textPri,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          p.categoria,
                                          style: TextStyle(fontSize: AppTexto.rotulo, color: textTer),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.content_copy_rounded, size: 18, color: textSec),
                                    tooltip: 'Copiar código ${p.codigo}',
                                    onPressed: () => _copiarCodigo(p),
                                  ),
                                ],
                              ),
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

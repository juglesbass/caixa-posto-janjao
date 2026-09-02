import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../models/operador_model.dart';
import '../../services/operadores_sync_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/app_haptics.dart';
import '../../utils/validator.dart';

class GestaoOperadoresScreen extends StatefulWidget {
  final bool isDark;

  const GestaoOperadoresScreen({super.key, required this.isDark});

  @override
  State<GestaoOperadoresScreen> createState() => _GestaoOperadoresScreenState();
}

class _GestaoOperadoresScreenState extends State<GestaoOperadoresScreen> {
  final _searchController = TextEditingController();
  List<OperadorModel> _operadores = [];
  bool _carregando = true;
  String _filtro = '';

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados({bool forcarNuvem = false}) async {
    setState(() => _carregando = true);
    if (forcarNuvem) {
      final res = await OperadoresSyncService.forcarSincronizacao();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res.mensagem),
          backgroundColor: res.sucesso ? AppColors.green : AppColors.amber,
          duration: const Duration(seconds: 3),
        ),
      );
    }
    final lista = await OperadoresSyncService.obterOperadores(sincronizarNuvem: !forcarNuvem);
    if (mounted) {
      setState(() {
        _operadores = lista;
        _carregando = false;
      });
    }
  }

  void _dialogNovoOperador() {
    final nomeController = TextEditingController();
    final pinController = TextEditingController();
    final confirmaController = TextEditingController();
    String? erro;
    bool salvando = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = widget.isDark;
            final textPri = isDark ? Colors.white : AppColors.lightTextPri;
            final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111420) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_add_rounded, color: Color(0xFF38BDF8), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Text('Novo Operador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri)),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Cadastre um operador para atuação no caixa e emissão de comprovantes:',
                      style: TextStyle(fontSize: 12.5, color: textSec),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: nomeController,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(color: textPri, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        labelText: 'Nome do Operador',
                        hintText: 'Ex: Carlos Silva',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.w900, color: textPri),
                      decoration: InputDecoration(
                        labelText: 'PIN Inicial (4 dígitos)',
                        hintText: '••••',
                        counterText: '',
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: confirmaController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      style: TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.w900, color: textPri),
                      decoration: InputDecoration(
                        labelText: 'Confirmar PIN',
                        hintText: '••••',
                        counterText: '',
                        errorText: erro,
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancelar', style: TextStyle(color: textSec)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: salvando
                      ? null
                      : () async {
                          final nome = nomeController.text.trim();
                          final p1 = pinController.text.trim();
                          final p2 = confirmaController.text.trim();

                          final erroNome = Validator.validarNomeOperador(nome);
                          if (erroNome != null) {
                            setModalState(() => erro = erroNome);
                            return;
                          }
                          if (p1.length != 4 || p2.length != 4) {
                            setModalState(() => erro = 'O PIN deve ter 4 dígitos numéricos');
                            return;
                          }
                          if (p1 != p2) {
                            setModalState(() => erro = 'Os PINs digitados não conferem!');
                            return;
                          }

                          setModalState(() => salvando = true);
                          final nomeFormatado = Validator.formatarNomeOperador(nome);
                          final ok = await OperadoresSyncService.adicionarOperador(
                            nome: nomeFormatado,
                            pin: p1,
                          );

                          if (ok && ctx.mounted) {
                            Navigator.of(ctx).pop();
                            AppHaptics.medium();
                            _carregarDados();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ Operador $nomeFormatado adicionado com sucesso!'),
                                  backgroundColor: AppColors.green,
                                ),
                              );
                            }
                          } else {
                            setModalState(() {
                              salvando = false;
                              erro = 'Falha ao salvar operador.';
                            });
                          }
                        },
                  child: salvando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Salvar Operador', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _dialogRedefinirPin(OperadorModel operador) {
    final pinController = TextEditingController();
    final confirmaController = TextEditingController();
    String? erro;
    bool salvando = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = widget.isDark;
            final textPri = isDark ? Colors.white : AppColors.lightTextPri;
            final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111420) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.password_rounded, color: Color(0xFFF59E0B), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Redefinir PIN',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPri),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Defina um novo PIN de 4 dígitos para ${operador.nomeExibicao}:',
                    style: TextStyle(fontSize: 12.5, color: textSec),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.w900, color: textPri),
                    decoration: InputDecoration(
                      labelText: 'Novo PIN (4 dígitos)',
                      hintText: '••••',
                      counterText: '',
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmaController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 18, letterSpacing: 6, fontWeight: FontWeight.w900, color: textPri),
                    decoration: InputDecoration(
                      labelText: 'Confirmar Novo PIN',
                      hintText: '••••',
                      counterText: '',
                      errorText: erro,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Cancelar', style: TextStyle(color: textSec)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: salvando
                      ? null
                      : () async {
                          final p1 = pinController.text.trim();
                          final p2 = confirmaController.text.trim();

                          if (p1.length != 4 || p2.length != 4) {
                            setModalState(() => erro = 'O PIN deve ter 4 dígitos');
                            return;
                          }
                          if (p1 != p2) {
                            setModalState(() => erro = 'Os PINs digitados não conferem!');
                            return;
                          }

                          setModalState(() => salvando = true);
                          final ok = await OperadoresSyncService.redefinirPin(
                            operadorId: operador.id,
                            novoPin: p1,
                          );

                          if (ok && ctx.mounted) {
                            Navigator.of(ctx).pop();
                            AppHaptics.medium();
                            _carregarDados();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('✅ PIN de ${operador.nomeExibicao} redefinido com sucesso!'),
                                  backgroundColor: AppColors.green,
                                ),
                              );
                            }
                          } else {
                            setModalState(() {
                              salvando = false;
                              erro = 'Falha ao atualizar PIN.';
                            });
                          }
                        },
                  child: salvando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Atualizar PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _alternarStatus(OperadorModel operador) async {
    final novoStatus = !operador.ativo;
    AppHaptics.selection();
    await OperadoresSyncService.alternarStatusOperador(
      operadorId: operador.id,
      ativo: novoStatus,
    );
    _carregarDados();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            novoStatus
                ? '✅ Operador ${operador.nomeExibicao} ativado.'
                : '⚠️ Operador ${operador.nomeExibicao} desativado.',
          ),
          backgroundColor: novoStatus ? AppColors.green : AppColors.amber,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _dialogDiagnosticoEConfiguracao() async {
    final projIdAtual = await OperadoresSyncService.getProjectId();
    final projController = TextEditingController(text: projIdAtual);
    bool testando = false;
    String? feedbackTeste;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isDark = widget.isDark;
            final textPri = isDark ? Colors.white : AppColors.lightTextPri;
            final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
            final status = OperadoresSyncService.statusNotifier.value;

            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF111420) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF38BDF8), size: 22),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Diagnóstico Nuvem Firestore',
                      style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.bold, color: textPri),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: status.online
                            ? AppColors.green.withOpacity(0.15)
                            : const Color(0xFFF59E0B).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: status.online ? AppColors.green : const Color(0xFFF59E0B),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            status.online ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                            color: status.online ? AppColors.green : const Color(0xFFF59E0B),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status.online ? 'Conectado e Sincronizado' : 'Modo Offline Ativo (Cache Local)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: status.online ? AppColors.green : const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Explicação do Status
                    Text(
                      'Por que está em Modo Offline?',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPri),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      status.online
                          ? 'A conexão com o Cloud Firestore está funcionando normalmente.'
                          : (status.statusCode == 403
                              ? 'O Cloud Firestore retornou erro 403 (Permission Denied). Isso ocorre porque o banco Firestore ainda não foi criado no console Firebase ou as regras de segurança exigem autenticação.'
                              : (status.detalheErro ?? 'Sem resposta da nuvem no momento.')),
                      style: TextStyle(fontSize: 11.5, color: textSec, height: 1.3),
                    ),
                    const SizedBox(height: 12),

                    // Garantia de Persistência Local
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.green, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Garantia Offline-First: Todas as alterações, novos operadores e PINs são salvos com segurança no banco de dados local (SQLite) deste aparelho e funcionam perfeitamente para abrir e fechar turnos.',
                              style: TextStyle(fontSize: 11, color: textSec, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo de configuração do ID do Projeto Firebase
                    Text(
                      'ID do Projeto Firebase (Firestore):',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textPri),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: projController,
                      style: TextStyle(fontSize: 13, color: textPri),
                      decoration: InputDecoration(
                        hintText: 'Ex: caixa-posto-janjao',
                        hintStyle: TextStyle(fontSize: 12, color: textSec),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                    if (feedbackTeste != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        feedbackTeste!,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: feedbackTeste!.startsWith('✅') ? AppColors.green : const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text('Fechar', style: TextStyle(color: textSec)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onPressed: testando
                      ? null
                      : () async {
                          final novoProj = projController.text.trim();
                          if (novoProj.isEmpty) return;

                          setModalState(() {
                            testando = true;
                            feedbackTeste = 'Testando conexão com $novoProj...';
                          });

                          await OperadoresSyncService.setProjectId(novoProj);
                          final res = await OperadoresSyncService.forcarSincronizacao();

                          setModalState(() {
                            testando = false;
                            feedbackTeste = res.sucesso
                                ? '✅ Conexão bem-sucedida com Firestore!'
                                : '⚠️ Nuvem retornou: ${OperadoresSyncService.ultimoStatusCode != null ? "HTTP ${OperadoresSyncService.ultimoStatusCode}" : "Offline"}. Usando cache local.';
                          });

                          _carregarDados();
                        },
                  child: testando
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Testar / Salvar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final bgScaffold = isDark ? const Color(0xFF090D16) : AppColors.lightBg;
    final textPri = isDark ? Colors.white : AppColors.lightTextPri;
    final textSec = isDark ? const Color(0xFF94A3B8) : AppColors.lightTextSec;
    final borderCol = isDark ? const Color(0xFF1E293B) : AppColors.lightBorder;

    final operadoresFiltrados = _operadores.where((op) {
      if (_filtro.isEmpty) return true;
      return op.nome.toLowerCase().contains(_filtro.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: bgScaffold,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF111420) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPri),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_rounded, color: Color(0xFF38BDF8), size: 20),
                const SizedBox(width: 8),
                Text(
                  'Gestão de Operadores',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: textPri),
                ),
              ],
            ),
            Text(
              'Sincronização Nuvem (Firestore)',
              style: TextStyle(fontSize: 11, color: textSec, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, color: Color(0xFFF59E0B)),
            tooltip: 'Diagnóstico Nuvem',
            onPressed: _dialogDiagnosticoEConfiguracao,
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: Color(0xFF38BDF8)),
            tooltip: 'Sincronizar com Nuvem',
            onPressed: () => _carregarDados(forcarNuvem: true),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: borderCol),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Faixa de Status de Sincronização ──
            ValueListenableBuilder<SyncStatus>(
              valueListenable: OperadoresSyncService.statusNotifier,
              builder: (context, status, _) {
                return InkWell(
                  onTap: _dialogDiagnosticoEConfiguracao,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                    child: Row(
                      children: [
                        Icon(
                          status.online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          size: 16,
                          color: status.online ? AppColors.green : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            status.mensagem,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: status.online ? AppColors.green : const Color(0xFFF59E0B),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: (status.online ? AppColors.green : const Color(0xFFF59E0B)).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                status.online ? 'Online' : 'Diagnóstico',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: status.online ? AppColors.green : const Color(0xFFF59E0B),
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 12,
                                color: status.online ? AppColors.green : const Color(0xFFF59E0B),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            // ── Barra de Busca e Botão Novo Operador ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF131C2E) : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderCol),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 13, color: textPri),
                        decoration: InputDecoration(
                          hintText: 'Buscar operador por nome...',
                          hintStyle: TextStyle(fontSize: 12.5, color: textSec),
                          prefixIcon: Icon(Icons.search_rounded, size: 18, color: textSec),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (v) => setState(() => _filtro = v.trim()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _dialogNovoOperador,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Novo', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),

            // ── Lista de Operadores ──
            Expanded(
              child: _carregando
                  ? const Center(child: CircularProgressIndicator())
                  : operadoresFiltrados.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.person_off_rounded, size: 48, color: textSec.withOpacity(0.5)),
                              const SizedBox(height: 12),
                              Text(
                                _filtro.isEmpty
                                    ? 'Nenhum operador cadastrado'
                                    : 'Nenhum operador encontrado para "$_filtro"',
                                style: TextStyle(fontSize: 14, color: textSec, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0284C7),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: _dialogNovoOperador,
                                icon: const Icon(Icons.person_add_rounded, size: 18),
                                label: const Text('Cadastrar Primeiro Operador'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _carregarDados(forcarNuvem: true),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: operadoresFiltrados.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (ctx, i) {
                              final op = operadoresFiltrados[i];
                              return _cardOperador(op, isDark, textPri, textSec, borderCol);
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardOperador(
    OperadorModel op,
    bool isDark,
    Color textPri,
    Color textSec,
    Color borderCol,
  ) {
    final dataFormatada = DateFormat('dd/MM/yyyy HH:mm').format(op.atualizadoEm);
    final cardBg = isDark ? const Color(0xFF131C2E) : AppColors.lightSurface;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: op.ativo ? borderCol : borderCol.withOpacity(0.4),
        ),
      ),
      child: Row(
        children: [
          // Avatar com inicial
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: op.ativo
                  ? (isDark ? const Color(0xFF0369A1).withOpacity(0.4) : const Color(0xFFE0F2FE))
                  : (isDark ? const Color(0xFF334155).withOpacity(0.4) : const Color(0xFFF1F5F9)),
              shape: BoxShape.circle,
              border: Border.all(
                color: op.ativo ? const Color(0xFF0284C7) : const Color(0xFF64748B),
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                op.nomeExibicao.isNotEmpty ? op.nomeExibicao[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: op.ativo ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)) : textSec,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Informações do Operador
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        op.nomeExibicao,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.bold,
                          color: op.ativo ? textPri : textSec,
                          decoration: op.ativo ? null : TextDecoration.lineThrough,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: op.ativo
                            ? AppColors.green.withOpacity(0.15)
                            : Colors.red.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        op.ativo ? 'ATIVO' : 'INATIVO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: op.ativo ? AppColors.green : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Atualizado: $dataFormatada',
                  style: TextStyle(fontSize: 11, color: textSec),
                ),
              ],
            ),
          ),

          // Ações: Redefinir PIN e Alternar Status
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.password_rounded, size: 20),
                color: const Color(0xFFF59E0B),
                tooltip: 'Redefinir PIN de 4 dígitos',
                onPressed: () => _dialogRedefinirPin(op),
              ),
              IconButton(
                icon: Icon(
                  op.ativo ? Icons.toggle_on_rounded : Icons.toggle_off_rounded,
                  size: 28,
                ),
                color: op.ativo ? AppColors.green : textSec,
                tooltip: op.ativo ? 'Desativar Operador' : 'Ativar Operador',
                onPressed: () => _alternarStatus(op),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

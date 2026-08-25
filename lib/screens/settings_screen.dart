import 'package:flutter/material.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../theme/app_colors.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDark;
  final ValueChanged<bool> onMudarTema;
  final VoidCallback onAbrirNovoTurno;

  const SettingsScreen({
    super.key,
    required this.isDark,
    required this.onMudarTema,
    required this.onAbrirNovoTurno,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _controllerPin = TextEditingController();
  final _controllerDriveUrl = TextEditingController();
  int _pendencias = 0;
  bool _sincronizando = false;

  @override
  void initState() {
    super.initState();
    _carregarConfig();
  }

  void _carregarConfig() async {
    final db = DatabaseService.instance;
    final pin = await db.getConfig('pin_acesso');
    final driveUrl = await db.getConfig('google_drive_webhook_url', padrao: DriveService.defaultWebhookUrl);
    final pends = await DriveService.sincronizarPendencias();

    setState(() {
      _controllerPin.text = pin;
      _controllerDriveUrl.text = driveUrl;
      _pendencias = pends;
    });
  }

  void _salvarPin() async {
    final db = DatabaseService.instance;
    await db.setConfig('pin_acesso', _controllerPin.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PIN de acesso atualizado com sucesso!'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  void _salvarDriveUrl() async {
    final db = DatabaseService.instance;
    await db.setConfig('google_drive_webhook_url', _controllerDriveUrl.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('URL do Google Drive atualizada com sucesso!'),
        backgroundColor: AppColors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textPri = widget.isDark ? AppColors.darkTextPri : AppColors.lightTextPri;
    final textSec = widget.isDark ? AppColors.darkTextSec : AppColors.lightTextSec;
    final surfaceColor = widget.isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final borderColor = widget.isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu e Configurações', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // ── Ações Rápidas de Turno ──
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: borderColor),
            ),
            child: ListTile(
              leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.accentLight),
              title: Text('Abrir Novo Turno', style: TextStyle(fontWeight: FontWeight.bold, color: textPri)),
              subtitle: Text('Inicia um novo turno de caixa com identificação', style: TextStyle(color: textSec, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onAbrirNovoTurno,
            ),
          ),
          const SizedBox(height: 14),

          // ── Aparência e Tema ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      color: AppColors.accentLight,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tema Escuro (Obsidian)', style: TextStyle(fontWeight: FontWeight.bold, color: textPri)),
                        Text(widget.isDark ? 'Ativado' : 'Desativado', style: TextStyle(color: textSec, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                Switch(
                  value: widget.isDark,
                  activeColor: AppColors.accentLight,
                  onChanged: widget.onMudarTema,
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── PIN de Segurança ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security_rounded, color: AppColors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text('PIN de Segurança (Abertura)', style: TextStyle(fontWeight: FontWeight.bold, color: textPri)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Deixe vazio se não quiser exigir PIN ao abrir turnos.', style: TextStyle(color: textSec, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controllerPin,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'Ex: 1234 (Opcional)',
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _salvarPin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                        ),
                      ),
                      child: const Text('Salvar', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Google Drive Webhook ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(AppColors.radiusMd),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_upload_rounded, color: AppColors.blue, size: 20),
                    const SizedBox(width: 8),
                    Text('Webhook Google Drive do Gerente', style: TextStyle(fontWeight: FontWeight.bold, color: textPri)),
                  ],
                ),
                const SizedBox(height: 4),
                Text('URL do Google Apps Script para recebimento automático dos PDFs.', style: TextStyle(color: textSec, fontSize: 12)),
                const SizedBox(height: 10),
                TextField(
                  controller: _controllerDriveUrl,
                  decoration: InputDecoration(
                    hintText: 'https://script.google.com/...',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: _salvarDriveUrl,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                    ),
                    child: const Text('Salvar URL', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Informações do App ──
          Center(
            child: Column(
              children: [
                Text('Caixa Posto Janjão v1.0.0 (Flutter Puro)', style: TextStyle(color: textSec, fontSize: 11)),
                const SizedBox(height: 2),
                Text('Desenvolvido para Máxima Performance e Estabilidade', style: TextStyle(color: textSec.withOpacity(0.7), fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

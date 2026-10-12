import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../services/secure_pin_service.dart';

class AdultGateScreen extends StatefulWidget {
  const AdultGateScreen({super.key});
  @override
  State<AdultGateScreen> createState() => _AdultGateScreenState();
}

class _AdultGateScreenState extends State<AdultGateScreen> {
  final pinController = TextEditingController();
  final service = SecurePinService();
  bool hasPin = false;
  bool loading = true;
  bool unlocked = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadPin();
  }

  Future<void> loadPin() async {
    final saved = await service.hasPin();
    if (!mounted) return;
    setState(() {
      hasPin = saved;
      loading = false;
    });
  }

  Future<void> submit() async {
    final pin = pinController.text.trim();
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() => error = 'Usá entre 4 y 8 dígitos numéricos.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      if (hasPin) {
        if (!await service.verifyPin(pin)) {
          setState(() {
            loading = false;
            error = 'PIN incorrecto. Intentá de nuevo.';
          });
          return;
        }
      } else {
        await service.setPin(pin);
        hasPin = true;
      }
      if (!mounted) return;
      setState(() {
        loading = false;
        unlocked = true;
        pinController.clear();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        loading = false;
        error = 'No se pudo guardar o validar el PIN en este dispositivo.';
      });
    }
  }

  @override
  void dispose() {
    pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (unlocked) {
      return ListView(
        padding: const EdgeInsets.all(22),
        children: [
          const Text('SECCIÓN +18', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Acceso local validado. Agregá únicamente contenido legal y destinado a adultos.',
              style: TextStyle(color: AppTheme.muted)),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: AppTheme.panel, borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: .08))),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_user_outlined, color: AppTheme.accent, size: 34),
                SizedBox(height: 14),
                Text('Acceso protegido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('La sección está desbloqueada durante esta sesión de pantalla. Al salir y volver, se solicitará el PIN nuevamente.',
                    style: TextStyle(color: AppTheme.muted, height: 1.5)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(onPressed: () => setState(() => unlocked = false),
              icon: const Icon(Icons.lock_outline), label: const Text('BLOQUEAR AHORA')),
        ],
      );
    }
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Container(
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(color: AppTheme.panel.withValues(alpha: .96), borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withValues(alpha: .09))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_person_rounded, size: 52, color: AppTheme.accent),
                const SizedBox(height: 18),
                const Text('ACCESO +18', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 9),
                Text(hasPin ? 'Ingresá tu PIN para continuar.' : 'Configurá un PIN numérico para proteger esta sección. No lo olvides.',
                    textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted, height: 1.5)),
                const SizedBox(height: 22),
                TextField(
                  controller: pinController,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: const InputDecoration(labelText: 'PIN numérico', counterText: '', prefixIcon: Icon(Icons.password_rounded)),
                  onSubmitted: (_) => submit(),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: const TextStyle(color: Colors.redAccent)),
                ],
                const SizedBox(height: 18),
                SizedBox(width: double.infinity,
                    child: FilledButton(onPressed: loading ? null : submit, child: Text(hasPin ? 'DESBLOQUEAR' : 'CONFIGURAR PIN'))),
                const SizedBox(height: 12),
                const Text('La protección se aplica dentro de la app; no reemplaza los controles parentales de Android.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: AppTheme.muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

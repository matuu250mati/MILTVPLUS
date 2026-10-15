import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/supabase_config.dart';
import '../../features/auth/auth_screen.dart';
import 'adult_browser_screen.dart';
import '../../services/secure_pin_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool accountVerified = false;
  bool ageConfirmed = false;
  bool ageCheckboxChecked = false;
  bool _policyAccepted = false;
  bool _policyCheckboxChecked = false;
  String? error;

  @override
  void initState() {
    super.initState();
    loadPin();
  }

  Future<void> loadPin() async {
    final saved = await service.hasPin();
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      hasPin = saved;
      _policyAccepted = preferences.getBool('miltvplus_adult_policy_accepted_v1') ?? false;
      loading = false;
    });
  }

  Future<void> _acceptPolicy() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('miltvplus_adult_policy_accepted_v1', true);
    if (!mounted) return;
    setState(() {
      _policyAccepted = true;
      ageConfirmed = false;
      ageCheckboxChecked = false;
    });
  }

  Future<void> _recoverPin() async {
    if (!isSupabaseConfigured) {
      setState(() => error = 'La recuperación requiere una cuenta MILTVPLUS verificada.');
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email?.trim();
    final phone = user?.phone?.trim();
    final useEmail = email != null && email.isNotEmpty;
    if (!useEmail && (phone == null || phone.isEmpty)) {
      setState(() => error = 'Tu cuenta no tiene un correo ni un teléfono verificado para recuperar el PIN.');
      return;
    }
    final codeController = TextEditingController();
    setState(() { loading = true; error = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (useEmail) {
        await auth.signInWithOtp(email: email, shouldCreateUser: false);
      } else {
        await auth.signInWithOtp(phone: phone, shouldCreateUser: false);
      }
      if (!mounted) return;
      setState(() => loading = false);
      final code = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Recuperar PIN +18'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(useEmail
                ? 'Ingresá el código de verificación enviado a $email.'
                : 'Ingresá el código SMS enviado a $phone.'),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              maxLength: 8,
              decoration: const InputDecoration(labelText: 'Código de verificación', counterText: ''),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, codeController.text.trim()),
              child: const Text('VERIFICAR'),
            ),
          ],
        ),
      );
      if (!mounted || code == null || code.isEmpty) return;
      setState(() => loading = true);
      if (useEmail) {
        await auth.verifyOTP(type: OtpType.email, email: email, token: code);
      } else {
        await auth.verifyOTP(type: OtpType.sms, phone: phone, token: code);
      }
      await service.clearPin();
      if (!mounted) return;
      setState(() {
        hasPin = false;
        loading = false;
        error = null;
        pinController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta verificada. Ahora podés crear un PIN nuevo.')),
      );
    } on AuthException catch (exception) {
      if (mounted) setState(() { loading = false; error = 'No se pudo verificar el código: ${exception.message}'; });
    } catch (_) {
      if (mounted) setState(() { loading = false; error = 'No se pudo completar la recuperación. Revisá la configuración de correo/SMS de la cuenta.'; });
    } finally {
      codeController.dispose();
      if (mounted && loading) setState(() => loading = false);
    }
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
    final signedIn = isSupabaseConfigured && Supabase.instance.client.auth.currentUser != null;
    if (!signedIn && !accountVerified) {
      return AuthScreen(onAuthenticated: () {
        if (!mounted) return;
        setState(() => accountVerified = true);
      });
    }
    if (!_policyAccepted) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Center(child: Icon(Icons.gpp_good_rounded, size: 48, color: Color(0xFF5BE58B))),
                const SizedBox(height: 12),
                const Center(child: Text('SEGURIDAD Y CONVIVENCIA MILTVPLUS', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
                const SizedBox(height: 16),
                const Text('Antes de entrar a la Zona +18, leé estas condiciones. Esta confirmación se solicita una sola vez por dispositivo.', style: TextStyle(color: AppTheme.muted, height: 1.5)),
                const SizedBox(height: 12),
                const Text('• La sección es exclusiva para personas mayores de 18 años.\n\n• Respetá las leyes aplicables, los derechos de autor y las condiciones de cada sitio externo.\n\n• MILTVPLUS no controla ni garantiza la privacidad, disponibilidad o contenido de páginas de terceros.\n\n• No compartas tu PIN, contraseñas, códigos de recuperación ni datos de acceso.\n\n• El PIN local protege el acceso dentro de la app, pero no sustituye los controles parentales del sistema.', style: TextStyle(height: 1.45)),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _policyCheckboxChecked,
                  onChanged: (value) => setState(() => _policyCheckboxChecked = value ?? false),
                  title: const Text('Leí y acepto las políticas de seguridad y convivencia.'),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: _policyCheckboxChecked ? _acceptPolicy : null,
                  child: const Text('CONFIRMAR Y CONTINUAR'),
                )),
              ]),
            ),
          ),
        ),
      );
    }
    if (!ageConfirmed) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.panel,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: .08)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.gpp_good_rounded, size: 48, color: AppTheme.accent),
                  const SizedBox(height: 14),
                  const Text('CONTENIDO PARA ADULTOS', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  const Text('Esta sección es exclusiva para mayores de 18 años. Para continuar necesitás una cuenta MILTV PLUS y confirmar tu edad.',
                      textAlign: TextAlign.center, style: TextStyle(color: AppTheme.muted, height: 1.5)),
                  const SizedBox(height: 12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: ageCheckboxChecked,
                    onChanged: (value) => setState(() => ageCheckboxChecked = value ?? false),
                    title: const Text('Confirmo que tengo 18 años o más.'),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                  const SizedBox(height: 8),
                  SizedBox(width: double.infinity,
                    child: FilledButton(
                      onPressed: ageCheckboxChecked ? () => setState(() => ageConfirmed = true) : null,
                      child: const Text('CONTINUAR'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (loading) return const Center(child: CircularProgressIndicator());
    if (unlocked) {
      return AdultBrowserScreen(
        onLock: () {
          if (!mounted) return;
          setState(() => unlocked = false);
        },
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
                if (hasPin)
                  TextButton.icon(
                    onPressed: loading ? null : _recoverPin,
                    icon: const Icon(Icons.mark_email_read_outlined),
                    label: const Text('OLVIDÉ MI PIN · RECUPERAR POR CÓDIGO'),
                  ),
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _register = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _busy) return;
    setState(() { _busy = true; _message = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (_register) {
        final response = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (!mounted) return;
        setState(() {
          _error = false;
          _message = response.session == null
              ? 'Cuenta creada. Revisá tu correo y confirmá la dirección antes de iniciar sesión.'
              : 'Cuenta creada correctamente.';
        });
      } else {
        await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = true; _message = e.message; });
    } catch (_) {
      if (mounted) setState(() {
        _error = true;
        _message = 'No se pudo completar la operación. Revisá tu conexión e intentá de nuevo.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() {
        _error = true;
        _message = 'Ingresá tu correo electrónico para recibir el enlace de recuperación.';
      });
      return;
    }
    setState(() { _busy = true; _message = null; });
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(email);
      if (mounted) setState(() {
        _error = false;
        _message = 'Si la cuenta existe, vas a recibir un correo para restablecer la contraseña.';
      });
    } on AuthException catch (e) {
      if (mounted) setState(() { _error = true; _message = e.message; });
    } catch (_) {
      if (mounted) setState(() {
        _error = true;
        _message = 'No se pudo enviar el correo. Intentá más tarde.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!isSupabaseConfigured) {
      return Scaffold(
        body: Center(child: Padding(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: const Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.lock_outline_rounded, size: 54, color: AppTheme.accent),
              SizedBox(height: 18),
              Text('MILTV PLUS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              SizedBox(height: 12),
              Text(
                'Acceso bloqueado: configurá SUPABASE_URL y SUPABASE_ANON_KEY (publishable key) en los parámetros de compilación.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, height: 1.5),
              ),
            ]),
          ),
        )),
      );
    }
    return Scaffold(
      body: Stack(children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: RadialGradient(
            center: Alignment.topRight, radius: 1.4,
            colors: [Color(0xFF20243C), AppTheme.background],
          )),
          child: SizedBox.expand(),
        ),
        Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Card(
              color: AppTheme.panel.withValues(alpha: .96),
              child: Padding(
                padding: const EdgeInsets.all(26),
                child: Form(key: _formKey, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(child: Container(
                      width: 58, height: 58,
                      decoration: BoxDecoration(color: AppTheme.accent, borderRadius: BorderRadius.circular(17)),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 42),
                    )),
                    const SizedBox(height: 18),
                    const Text('MILTV PLUS', textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                    const SizedBox(height: 8),
                    Text(_register ? 'Creá tu cuenta para continuar' : 'Iniciá sesión para acceder al catálogo',
                      textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted)),
                    const SizedBox(height: 26),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        return value.contains('@') && !value.endsWith('@') ? null : 'Ingresá un correo válido.';
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      autofillHints: _register ? const [AutofillHints.newPassword] : const [AutofillHints.password],
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _hidePassword = !_hidePassword),
                          icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        ),
                      ),
                      validator: (v) => (v ?? '').length >= 6 ? null : 'Usá al menos 6 caracteres.',
                    ),
                    if (!_register) Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(onPressed: _busy ? null : _resetPassword, child: const Text('Olvidé mi contraseña')),
                    ) else const SizedBox(height: 10),
                    if (_message != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (_error ? Colors.redAccent : AppTheme.accent).withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_message!, style: TextStyle(
                          color: _error ? Colors.redAccent.shade100 : AppTheme.accent, height: 1.4,
                        )),
                      ),
                      const SizedBox(height: 14),
                    ],
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        child: _busy
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(_register ? 'CREAR CUENTA' : 'INICIAR SESIÓN'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _busy ? null : () => setState(() { _register = !_register; _message = null; }),
                      child: Text(_register ? 'Ya tengo cuenta · Iniciar sesión' : '¿Primera vez? · Crear cuenta'),
                    ),
                  ],
                )),
              ),
            ),
          ),
        )),
      ]),
    );
  }
}

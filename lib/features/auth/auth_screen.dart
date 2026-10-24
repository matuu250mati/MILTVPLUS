import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/country_catalog.dart';
import '../../core/country_preference.dart';
import '../../core/supabase_config.dart';
import '../../core/theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, this.onAuthenticated});

  final VoidCallback? onAuthenticated;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _name = TextEditingController();
  final _code = TextEditingController();
  final _emailFocus = FocusNode(debugLabel: 'login-email');
  final _passwordFocus = FocusNode(debugLabel: 'login-password');
  final _submitFocus = FocusNode(debugLabel: 'login-submit');
  final _registerFocus = FocusNode(debugLabel: 'login-register');
  final _phoneModeFocus = FocusNode(debugLabel: 'login-phone-mode');

  late CountryOption _country;
  bool _verifying = false;
  int _resendIn = 0;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    // Pre-select the country the device reports; Argentina is the fallback.
    _country = countryByCode(
          WidgetsBinding.instance.platformDispatcher.locale.countryCode,
        ) ??
        countryByCode('AR')!;
    // Explicit D-pad routing avoids traversal getting trapped in helper controls
    // between the email, password and primary action on Android TV remotes.
    _emailFocus.onKeyEvent = (_, event) =>
        _handleDpadNavigation(event, down: _passwordFocus);
    _passwordFocus.onKeyEvent = (_, event) =>
        _handleDpadNavigation(event, up: _emailFocus, down: _submitFocus);
    _submitFocus.onKeyEvent = (_, event) =>
        _handleDpadNavigation(event, up: _passwordFocus, down: _registerFocus);
    _registerFocus.onKeyEvent = (_, event) =>
        _handleDpadNavigation(event, up: _submitFocus, down: _phoneModeFocus);
    _phoneModeFocus.onKeyEvent = (_, event) =>
        _handleDpadNavigation(event, up: _registerFocus);
  }

  KeyEventResult _handleDpadNavigation(
    KeyEvent event, {
    FocusNode? up,
    FocusNode? down,
  }) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && down != null) {
      down.requestFocus();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp && up != null) {
      up.requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
  bool _phoneMode = false;
  bool _otpSent = false;
  String? _pendingPhone;
  bool _register = false;
  bool _busy = false;
  bool _hidePassword = true;
  String? _message;
  bool _error = false;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _name.dispose();
    _code.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otp.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _submitFocus.dispose();
    _registerFocus.dispose();
    _phoneModeFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() { _busy = true; _message = null; });
    try {
      final auth = Supabase.instance.client.auth;
      if (_verifying) {
        await _verifyEmailCode();
      } else if (_phoneMode) {
        final phone = _pendingPhone ??
            '+549${_phone.text.replaceAll(RegExp(r'\D'), '')}';
        if (!_otpSent) {
          await auth.signInWithOtp(phone: phone);
          if (!mounted) return;
          setState(() {
            _pendingPhone = phone;
            _otpSent = true;
            _error = false;
            _message = 'Te enviamos un código por SMS a $phone. Ingresalo para verificar tu número.';
          });
        } else {
          await auth.verifyOTP(
            type: OtpType.sms,
            phone: phone,
            token: _otp.text.trim(),
          );
          if (mounted) widget.onAuthenticated?.call();
        }
      } else if (_register) {
        final response = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: <String, dynamic>{
            'full_name': _name.text.trim(),
            'country': _country.code,
          },
        );
        if (!mounted) return;
        if (response.session != null) {
          // Email verification is mandatory. A session at this point means the
          // server has "Confirm email" turned off, so do not let the user in.
          await auth.signOut();
          if (!mounted) return;
          setState(() {
            _error = true;
            _message = 'La verificación por correo no está activada en el servidor. Avisale al administrador.';
          });
          return;
        }
        await CountryPreference.save(_country.code);
        _enterVerification(
          'Te enviamos un código de 6 dígitos a ${_email.text.trim()}. Ingresalo para activar tu cuenta.',
        );
      } else {
        final response = await auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
        await CountryPreference.syncFromMetadata(response.user?.userMetadata);
        if (mounted) widget.onAuthenticated?.call();
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final unverified = !_register &&
          !_phoneMode &&
          !_verifying &&
          e.message.toLowerCase().contains('not confirmed');
      if (unverified) {
        await _resendCode(force: true);
        if (!mounted) return;
        _enterVerification(
          'Tu correo todavía no está verificado. Te enviamos un código nuevo a ${_email.text.trim()}.',
        );
        return;
      }
      setState(() {
        _error = true;
        _message = e.message;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = 'No se pudo completar la operación. Revisá tu conexión e intentá de nuevo.';
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _enterVerification(String message) {
    setState(() {
      _verifying = true;
      _error = false;
      _message = message;
      _code.clear();
    });
    _startCooldown();
  }

  void _leaveVerification() {
    _cooldownTimer?.cancel();
    setState(() {
      _verifying = false;
      _resendIn = 0;
      _code.clear();
      _message = null;
    });
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _resendIn = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _resendIn <= 1) {
        timer.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn -= 1);
    });
  }

  Future<void> _verifyEmailCode() async {
    final auth = Supabase.instance.client.auth;
    final response = await auth.verifyOTP(
      type: OtpType.signup,
      email: _email.text.trim(),
      token: _code.text.trim(),
    );
    if (response.session == null) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _message = 'No se pudo verificar el código. Pedí uno nuevo.';
      });
      return;
    }
    await CountryPreference.syncFromMetadata(response.user?.userMetadata);
    if (mounted) widget.onAuthenticated?.call();
  }

  Future<void> _resendCode({bool force = false}) async {
    if (!force && (_busy || _resendIn > 0)) return;
    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: _email.text.trim(),
      );
      if (!mounted || force) return;
      _startCooldown();
      setState(() {
        _error = false;
        _message = 'Te enviamos un código nuevo a ${_email.text.trim()}.';
      });
    } on AuthException catch (e) {
      if (!mounted || force) return;
      setState(() {
        _error = true;
        _message = e.message;
      });
    } catch (_) {
      if (!mounted || force) return;
      setState(() {
        _error = true;
        _message = 'No se pudo reenviar el código. Intentá en unos minutos.';
      });
    }
  }

  Future<void> _pickCountry() async {
    final picked = await showModalBottomSheet<CountryOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.panel,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * .75,
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
              child: Text('¿Desde qué país mirás?',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final country in supportedCountries)
                    ListTile(
                      leading: Text(country.flag, style: const TextStyle(fontSize: 26)),
                      title: Text(country.name),
                      trailing: country.code == _country.code
                          ? const Icon(Icons.check_circle_rounded, color: AppTheme.accent)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(country),
                    ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _country = picked);
  }

  Widget _messageBox() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: (_error ? Colors.redAccent : AppTheme.accent).withValues(alpha: .10),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(_message!, style: TextStyle(
        color: _error ? Colors.redAccent.shade100 : AppTheme.accent, height: 1.4,
      )),
    );
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
      if (mounted) {
        setState(() {
          _error = false;
          _message = 'Si la cuenta existe, vas a recibir un correo para restablecer la contraseña.';
        });
      }
    } on AuthException catch (e) {
      if (mounted) { setState(() { _error = true; _message = e.message; }); }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = true;
          _message = 'No se pudo enviar el correo. Intentá más tarde.';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.lock_outline_rounded, size: 54, color: AppTheme.accent),
              const SizedBox(height: 18),
              const Text('MILTVPLUS', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(
                supabaseConfigurationError ??
                    'La configuración de Supabase no está disponible.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.muted, height: 1.5),
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
                    Text(
                      _verifying
                          ? 'Verificá tu correo para activar la cuenta'
                          : _register
                              ? 'Creá tu cuenta para continuar'
                              : 'Iniciá sesión para acceder al catálogo',
                      textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.muted)),
                    const SizedBox(height: 26),
                    if (_verifying) ...[
                      TextFormField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        maxLength: 6,
                        textAlign: TextAlign.center,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w800),
                        decoration: const InputDecoration(
                          labelText: 'Código de verificación',
                          counterText: '',
                          prefixIcon: Icon(Icons.verified_user_outlined),
                        ),
                        validator: (v) => RegExp(r'^\d{6}$').hasMatch((v ?? '').trim())
                            ? null
                            : 'Ingresá el código de 6 dígitos.',
                      ),
                      const SizedBox(height: 14),
                      if (_message != null) ...[
                        _messageBox(),
                        const SizedBox(height: 14),
                      ],
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: _busy
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('VERIFICAR Y ENTRAR'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: (_busy || _resendIn > 0) ? null : _resendCode,
                        child: Text(_resendIn > 0
                            ? 'Reenviar código en ${_resendIn}s'
                            : 'Reenviar código'),
                      ),
                      TextButton(
                        onPressed: _busy ? null : _leaveVerification,
                        child: const Text('Usar otro correo'),
                      ),
                    ] else if (!_phoneMode) ...[
                    if (_register) ...[
                      TextFormField(
                        controller: _name,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(labelText: 'Nombre', prefixIcon: Icon(Icons.person_outline_rounded)),
                        validator: (v) => (v ?? '').trim().length >= 2 ? null : 'Ingresá tu nombre.',
                      ),
                      const SizedBox(height: 14),
                    ],
                    TextFormField(
                      focusNode: _emailFocus,
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_outline_rounded)),
                      validator: (v) {
                        final value = (v ?? '').trim();
                        return value.contains('@') && !value.endsWith('@') ? null : 'Ingresá un correo válido.';
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      focusNode: _passwordFocus,
                      controller: _password,
                      obscureText: _hidePassword,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submitFocus.requestFocus(),
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
                    if (_register) ...[
                      const SizedBox(height: 14),
                      OutlinedButton(
                        onPressed: _busy ? null : _pickCountry,
                        style: OutlinedButton.styleFrom(
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                        ),
                        child: Row(children: [
                          Text(_country.flag, style: const TextStyle(fontSize: 22)),
                          const SizedBox(width: 12),
                          Expanded(child: Text('País: ${_country.name}')),
                          const Icon(Icons.expand_more_rounded),
                        ]),
                      ),
                    ],
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
                      focusNode: _submitFocus,
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
                      focusNode: _registerFocus,
                      onPressed: _busy ? null : () => setState(() { _register = !_register; _message = null; }),
                      child: Text(_register ? 'Ya tengo cuenta · Iniciar sesión' : '¿Primera vez? · Crear cuenta'),
                    ),
                      TextButton(
                        focusNode: _phoneModeFocus,
                        onPressed: _busy ? null : () => setState(() {
                          _phoneMode = true;
                          _message = null;
                        }),
                        child: const Text('Continuar con número de celular (+54 9)'),
                      ),
                    ] else ...[
                      TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        enabled: !_otpSent,
                        decoration: const InputDecoration(
                          labelText: 'Celular argentino',
                          prefixText: '+54 9 ',
                          prefixIcon: Icon(Icons.phone_android_rounded),
                          hintText: '351 123 4567',
                        ),
                        validator: (value) {
                          if (!_phoneMode) return null;
                          final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
                          return digits.length == 10
                              ? null
                              : 'Ingresá el código de área y número (10 dígitos).';
                        },
                      ),
                      if (_otpSent) ...[
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _otp,
                          keyboardType: TextInputType.number,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          decoration: const InputDecoration(
                            labelText: 'Código SMS',
                            prefixIcon: Icon(Icons.password_rounded),
                          ),
                          validator: (value) => !_otpSent ||
                                  (value ?? '').trim().length >= 6
                              ? null
                              : 'Ingresá el código recibido por SMS.',
                        ),
                      ],
                      if (_message != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: (_error ? Colors.redAccent : AppTheme.accent)
                                .withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_message!, style: TextStyle(
                            color: _error ? Colors.redAccent.shade100 : AppTheme.accent,
                            height: 1.4,
                          )),
                        ),
                      ],
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: _busy
                              ? const SizedBox(width: 20, height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2))
                              : Text(_otpSent ? 'VERIFICAR CÓDIGO' : 'ENVIAR CÓDIGO SMS'),
                        ),
                      ),
                      TextButton(
                        onPressed: _busy ? null : () => setState(() {
                          _phoneMode = false;
                          _otpSent = false;
                          _pendingPhone = null;
                          _otp.clear();
                          _message = null;
                        }),
                        child: const Text('Volver al acceso con correo'),
                      ),
                    ],

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

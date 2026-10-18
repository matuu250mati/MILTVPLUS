import 'dart:math';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_theme.dart';
import '../shell/app_shell.dart';

/// First authenticated launch flow. Hardware details are read for diagnostics;
/// the installation ID is generated locally and is not a hardware fingerprint.
class TvOnboardingScreen extends StatefulWidget {
  const TvOnboardingScreen({super.key});

  @override
  State<TvOnboardingScreen> createState() => _TvOnboardingScreenState();
}

class _TvOnboardingScreenState extends State<TvOnboardingScreen> {
  int _step = 0; // 0 syncing, 1 complete, 2 terms
  bool _busy = true;
  bool _accepted = false;
  bool _syncSuccessful = false;
  bool _termsReachedEnd = false;
  final ScrollController _termsScrollController = ScrollController();
  String? _error;
  String _deviceLabel = 'Dispositivo compatible';
  String _installationId = '';
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _termsScrollController.addListener(_trackTermsScroll);
    _synchronize();
  }

  @override
  void dispose() {
    _termsScrollController
      ..removeListener(_trackTermsScroll)
      ..dispose();
    super.dispose();
  }

  void _trackTermsScroll() {
    if (!_termsScrollController.hasClients || _termsReachedEnd) return;
    if (_termsScrollController.position.extentAfter <= 24 && mounted) {
      setState(() => _termsReachedEnd = true);
    }
  }

  Future<void> _openHome() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('miltv_tv_tutorial_completed_v1', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const AppShell()),
    );
  }

  Future<void> _synchronize() async {
    setState(() {
      _busy = true;
      _error = null;
      _syncSuccessful = false;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      var installationId = preferences.getString('miltv_installation_id_v1');
      if (installationId == null || installationId.isEmpty) {
        final random = Random.secure();
        installationId = List<int>.generate(
          16,
          (_) => random.nextInt(256),
        ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
        await preferences.setString('miltv_installation_id_v1', installationId);
      }

      // Device metadata is diagnostic only. A failure in a platform plugin
      // must not block a valid installation from continuing through onboarding.
      var appVersion = 'No disponible';
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      } catch (_) {
        // Keep the fallback version; the local installation ID is sufficient.
      }

      var label = '${defaultTargetPlatform.name} · información del dispositivo no disponible';
      if (kIsWeb) {
        label = 'Web';
      } else {
        try {
          final deviceInfo = DeviceInfoPlugin();
          switch (defaultTargetPlatform) {
            case TargetPlatform.android:
              final info = await deviceInfo.androidInfo;
              label = 'Android · ${info.manufacturer} ${info.model} · Android ${info.version.release}';
              break;
            case TargetPlatform.iOS:
              final info = await deviceInfo.iosInfo;
              label = 'iOS · ${info.model} · ${info.systemVersion}';
              break;
            case TargetPlatform.macOS:
              final info = await deviceInfo.macOsInfo;
              label = 'macOS · ${info.model} · ${info.osRelease}';
              break;
            case TargetPlatform.windows:
              final info = await deviceInfo.windowsInfo;
              label = 'Windows · ${info.productName}';
              break;
            case TargetPlatform.linux:
              final info = await deviceInfo.linuxInfo;
              label = 'Linux · ${info.prettyName}';
              break;
            case TargetPlatform.fuchsia:
              label = 'Fuchsia';
              break;
          }
        } catch (_) {
          // Device information is optional and no Android runtime permission
          // is required for this local, non-identifying diagnostic label.
        }
      }

      if (!mounted) return;
      setState(() {
        _installationId = installationId!;
        _appVersion = appVersion;
        _deviceLabel = label;
        _busy = false;
        _syncSuccessful = true;
        _step = 0;
        _error = null;
      });
    } catch (error, stackTrace) {
      // QA diagnostic: preserve the real failure so the next test can identify
      // whether plugin initialization, preference reads, or writes are failing.
      debugPrint('MILTVPLUS QA onboarding local setup failed: $error');
      debugPrintStack(
        label: 'MILTVPLUS QA onboarding local setup stack',
        stackTrace: stackTrace,
      );
      if (!mounted) return;
      setState(() {
        _busy = false;
        _syncSuccessful = false;
        _error = 'Falló la configuración local (${error.runtimeType}). Detalle: $error';
      });
    }
  }

  Future<void> _acceptTerms() async {
    if (!_accepted || !_termsReachedEnd || _busy) return;
    setState(() => _busy = true);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('miltv_terms_accepted_v1', true);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _step = 3;
        _error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'No se pudo guardar tu aceptación. Intentá nuevamente.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topRight,
            radius: 1.3,
            colors: [Color(0xFF14283A), AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(wide ? 36 : 20),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Card(
                  color: AppTheme.panel.withValues(alpha: .97),
                  child: Padding(
                    padding: EdgeInsets.all(wide ? 32 : 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.ondemand_video_rounded,
                            color: AppTheme.accent, size: 58),
                        const SizedBox(height: 12),
                        const Text(
                          'MILTVPLUS',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _step == 0
                              ? 'Sincronización del dispositivo'
                              : _step == 1
                                  ? 'Sincronización completada'
                                  : _step == 2 ? 'Términos y condiciones de uso' : 'Guía rápida para tu televisor',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: AppTheme.accent, fontSize: 19, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 24),
                        if (_step == 0) ...[
                          if (_busy) ...[
                            const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
                            const SizedBox(height: 18),
                            const Text(
                              'Comprobando la información disponible del sistema y preparando la navegación por control remoto…',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.muted, height: 1.5),
                            ),
                          ] else ...[
                            Text(_deviceLabel, textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            Text('Versión: $_appVersion', textAlign: TextAlign.center),
                            const SizedBox(height: 8),
                            const Text(
                              'La navegación usa los eventos de teclado estándar de Flutter (flechas y OK/Enter). La disponibilidad exacta de teclas depende del dispositivo y debe comprobarse en el televisor.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppTheme.muted, height: 1.5),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 14),
                              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                            ],
                            const SizedBox(height: 20),
                            FilledButton(
                              autofocus: true,
                              onPressed: _synchronize,
                              child: const Text('VOLVER A INTENTAR'),
                            ),
                            FilledButton(
                              onPressed: _syncSuccessful ? () => setState(() => _step = 1) : null,
                              child: const Text('CONTINUAR'),
                            ),
                          ],
                        ] else if (_step == 1) ...[
                          const Icon(Icons.check_circle_outline_rounded, color: AppTheme.accent, size: 56),
                          const SizedBox(height: 16),
                          Text(_deviceLabel, textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          Text('Versión de la aplicación: $_appVersion', textAlign: TextAlign.center),
                          const SizedBox(height: 8),
                          const Text(
                            'Se guardó un identificador local de esta instalación. No es un identificador de hardware ni garantiza compatibilidad con todos los mandos.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppTheme.muted, height: 1.5),
                          ),
                          const SizedBox(height: 8),
                          Text('ID de instalación: $_installationId', textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, color: AppTheme.muted)),
                          const SizedBox(height: 22),
                          FilledButton(
                            autofocus: true,
                            onPressed: () => setState(() => _step = 2),
                            child: const Text('CONTINUAR'),
                          ),
                        ] else if (_step == 2) ...[
                          const Text(
                            'TÉRMINOS Y CONDICIONES DE USO',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Leé el documento completo desplazándote hasta el final. Este texto es una base informativa para el producto y debe revisarse legalmente antes de publicarse como contrato definitivo.',
                            style: TextStyle(color: AppTheme.muted, height: 1.5),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            height: wide ? 300 : 260,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.accent.withValues(alpha: .55)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Scrollbar(
                              controller: _termsScrollController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _termsScrollController,
                                padding: const EdgeInsets.all(16),
                                child: const Text(_termsDocument, style: TextStyle(color: AppTheme.muted, height: 1.55)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _termsReachedEnd ? 'Documento leído hasta el final.' : 'Desplazate hasta el final del documento para habilitar la aceptación.',
                            style: TextStyle(color: _termsReachedEnd ? AppTheme.accent : AppTheme.muted, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          CheckboxListTile(
                            value: _accepted,
                            onChanged: (!_termsReachedEnd || _busy) ? null : (value) => setState(() => _accepted = value ?? false),
                            activeColor: AppTheme.accent,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: const Text('Declaro que leí y acepto los términos de uso.'),
                            contentPadding: EdgeInsets.zero,
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 8),
                            Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                          ],
                          const SizedBox(height: 14),
                          FilledButton(
                            autofocus: true,
                            onPressed: _accepted && _termsReachedEnd && !_busy ? _acceptTerms : null,
                            child: _busy
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Text('ACEPTAR Y CONTINUAR'),
                          ),
                        ] else ...[
                          const Icon(Icons.gamepad_rounded, color: AppTheme.accent, size: 54),
                          const SizedBox(height: 12),
                          const Text(
                            'Aprendé a manejar MILTVPLUS con el control remoto',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                          ),
                          const SizedBox(height: 18),
                          _tutorialRow(Icons.arrow_circle_up_rounded, '1. Flechas del control', 'Usá arriba, abajo, izquierda y derecha para moverte entre menús, tarjetas y botones. El borde de enfoque indica qué elemento está seleccionado.'),
                          _tutorialRow(Icons.check_circle_outline_rounded, '2. OK / Enter', 'Presioná OK o Enter para abrir la categoría, elegir un canal o entrar a la ficha de una película o serie.'),
                          _tutorialRow(Icons.arrow_back_rounded, '3. Atrás / Back', 'Volvé a la pantalla anterior con el botón Atrás del control. Si el sistema muestra un diálogo, revisá la opción enfocada antes de confirmar.'),
                          _tutorialRow(Icons.live_tv_rounded, '4. Categorías sin mezclas', 'TV en vivo reúne canales lineales generales e informativos. Deportes se reserva para canales y emisiones deportivas. Películas, Series, Anime e Infantil mantienen sus secciones propias.'),
                          _tutorialRow(Icons.play_circle_outline_rounded, '5. Reproducción y fuentes', 'Abrí una ficha o canal y usá las opciones disponibles en pantalla. Si una fuente falla, probá otra fuente autorizada cuando la aplicación la ofrezca; no todos los enlaces garantizan disponibilidad.'),
                          _tutorialRow(Icons.search_rounded, '6. Buscar y favoritos', 'Usá la lupa para localizar contenido. Agregá elementos a Favoritos si esa acción está disponible y consultá Historial para volver a lo visto.'),
                          _tutorialRow(Icons.settings_rounded, '7. Configuración', 'Entrá a Configuración para revisar las opciones disponibles. Su presencia no implica que una función de red o del sistema esté soportada en todos los modelos.'),
                          const SizedBox(height: 18),
                          FilledButton(
                            autofocus: true,
                            onPressed: _busy ? null : _openHome,
                            child: const Text('IR A MILTVPLUS'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tutorialRow(IconData icon, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(color: AppTheme.muted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const String _termsDocument = '''
1. IDENTIFICACIÓN Y ALCANCE
MILTVPLUS es una aplicación de acceso a interfaces de contenido audiovisual, organizada en categorías como televisión en vivo, deportes, películas, series, anime e infantil. Estos términos describen reglas generales de uso de la aplicación. La entidad responsable, domicilio, datos de contacto y condiciones comerciales definitivas deberán completarse por el titular antes de una publicación contractual.

2. ACEPTACIÓN
Al marcar la casilla de aceptación y continuar, la persona usuaria declara que leyó este documento y que acepta las condiciones de uso aplicables. Si no está de acuerdo, debe salir de esta pantalla y no continuar utilizando las funciones que requieran aceptación. La aceptación se registra localmente en este dispositivo; no equivale por sí sola a una firma electrónica avanzada ni demuestra identidad legal.

3. REQUISITOS Y CUENTA
La persona usuaria debe contar con un dispositivo compatible, conexión de red cuando sea necesaria y una versión del sistema operativo admitida por la aplicación. Es responsable de la veracidad de los datos que suministre, de proteger sus credenciales y de cerrar su sesión en equipos compartidos. No debe compartir contraseñas, intentar acceder a cuentas ajenas ni eludir controles de seguridad. Las funciones de inicio de sesión y registro dependen de la disponibilidad del servicio de autenticación configurado.

4. USO PERMITIDO
La aplicación debe utilizarse conforme a las leyes aplicables, las condiciones de los proveedores y los derechos de terceros. Se prohíbe utilizarla para vulnerar derechos de autor, retransmitir contenido sin autorización, realizar ingeniería inversa con fines ilícitos, interferir con la infraestructura, distribuir malware, evadir medidas de seguridad o perjudicar a otros usuarios. La disponibilidad de una dirección pública en Internet no significa que exista autorización para redistribuir el contenido asociado.

5. CONTENIDO Y DERECHOS
Los nombres, marcas, logotipos, sinopsis, carteles, señales y obras audiovisuales pueden pertenecer a sus respectivos titulares. Cada proveedor o titular conserva los derechos que le correspondan. El operador de la aplicación debe publicar únicamente contenido para el que cuente con derechos, licencias, permisos o una base legal válida. Una categoría visible o una ficha de catálogo no garantiza que el contenido esté disponible, completo o autorizado en todos los territorios.

6. DISPONIBILIDAD DE CANALES Y FUENTES
Los canales y las fuentes de reproducción pueden cambiar, interrumpirse, limitarse geográficamente o dejar de funcionar por decisiones de terceros, mantenimiento, cambios técnicos, conectividad o restricciones legales. No se garantiza disponibilidad ininterrumpida, una calidad específica ni que todos los enlaces funcionen en todos los dispositivos. Cuando existan fuentes alternativas, deben utilizarse únicamente si su uso está permitido y autorizado.

7. CLASIFICACIÓN Y CONTROLES DE CONTENIDO
Las secciones de TV en vivo, Deportes, Películas, Series, Anime e Infantil tienen fines de organización. La clasificación puede depender de los metadatos suministrados por las fuentes y podría contener errores. Las personas adultas responsables deben supervisar el uso por menores y comprobar la clasificación por edades. La existencia de una sección Infantil no sustituye los controles parentales ni garantiza que todo contenido sea adecuado para cada edad.

8. SUSCRIPCIONES, PAGOS Y PRUEBAS
Si una versión futura ofrece suscripciones, pagos, períodos de prueba o compras, sus precios, duración, renovación, impuestos, cancelación y reembolsos deberán informarse claramente antes de cobrar. No se considera que exista una suscripción paga por el solo hecho de instalar esta aplicación o aceptar este documento. Cualquier condición comercial deberá ser completada y validada por el operador antes de ofrecerse.

9. PRIVACIDAD Y DATOS
La aplicación puede procesar los datos necesarios para autenticación, preferencias, funcionamiento técnico y diagnóstico. El identificador generado durante la configuración es aleatorio y local a esta instalación; no debe interpretarse como un número de serie físico del televisor. La política de privacidad definitiva debe identificar al responsable, detallar datos recogidos, finalidades, base jurídica, destinatarios, plazos de conservación, transferencias, derechos de acceso, rectificación y supresión, y un canal de contacto. No deben incorporarse datos sensibles innecesarios ni utilizarse datos para fines incompatibles sin una base válida.

10. PERMISOS Y DIAGNÓSTICO DEL DISPOSITIVO
La lectura de fabricante, modelo, versión del sistema o versión de la aplicación tiene fines de diagnóstico y compatibilidad. No implica que la aplicación pueda controlar todas las funciones del sistema, modificar ajustes del televisor, mapear cualquier mando, detectar todo hardware o garantizar soporte universal. Los permisos deben solicitarse solo cuando sean necesarios y explicarse de forma comprensible.

11. SEGURIDAD
El operador debe adoptar medidas razonables para proteger los servicios, credenciales y datos bajo su control. La persona usuaria debe mantener actualizado el dispositivo, descargar instaladores desde canales confiables y evitar compartir archivos de instalación modificados. Ningún sistema conectado puede garantizar seguridad absoluta; cualquier incidente debe comunicarse por el canal oficial que el operador habilite.

12. COMPATIBILIDAD Y REQUISITOS TÉCNICOS
El funcionamiento depende del modelo, sistema operativo, codecs, DRM, arquitectura, versión de WebView cuando corresponda, permisos, conexión y disponibilidad de proveedores. Una compilación exitosa no demuestra compatibilidad con cada teléfono, Smart TV, TV Box o convertidor. La compatibilidad debe validarse con pruebas reales en cada familia de dispositivos que se anuncie como soportada.

13. ACTUALIZACIONES Y CAMBIOS
La aplicación puede recibir actualizaciones para corregir errores, mejorar accesibilidad, ajustar compatibilidad o modificar funciones. Las actualizaciones pueden requerir cambios de configuración o dejar de admitir plataformas obsoletas por razones técnicas o de seguridad. Los cambios materiales en estas condiciones deben comunicarse de forma adecuada y, cuando la ley lo requiera, solicitar una nueva aceptación.

14. LIMITACIÓN DE RESPONSABILIDAD
En la medida permitida por la legislación aplicable, el operador no garantiza que los servicios de terceros permanezcan disponibles ni que todas las funciones estén libres de errores. Nada de este apartado excluye derechos irrenunciables de consumidores, garantías legales ni responsabilidad que no pueda limitarse por ley. Las exclusiones y límites definitivos deben ser revisados por asesoría jurídica en las jurisdicciones donde se distribuya la aplicación.

15. SUSPENSIÓN Y TERMINACIÓN
El acceso puede suspenderse cuando sea necesario para proteger la seguridad, cumplir una obligación legal, atender abuso o resolver una incidencia grave. Cuando corresponda, se informará el motivo y el procedimiento de revisión. La persona usuaria puede dejar de utilizar la aplicación y solicitar el tratamiento o eliminación de datos conforme a la política de privacidad y la normativa aplicable.

16. LEGISLACIÓN Y RESOLUCIÓN DE CONFLICTOS
La ley aplicable, jurisdicción competente, domicilio legal y mecanismo de reclamos deben ser determinados por el titular de MILTVPLUS y completados antes de publicar la versión definitiva. Nada de este documento pretende eliminar derechos obligatorios que correspondan a consumidores por su lugar de residencia.

17. CONTACTO Y VERSIÓN
El titular debe publicar un correo o canal de contacto válido para consultas, reclamos, privacidad y solicitudes legales. También debe indicar la fecha de vigencia y el número de versión de los términos. Hasta que esos datos sean completados y revisados, este documento funciona como una base de producto y no debe presentarse como asesoramiento jurídico ni como contrato revisado por un profesional.
''';

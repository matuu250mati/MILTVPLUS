import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Guided introduction that preserves MILTVPLUS' existing dark visual identity.
/// There is deliberately no skip action: the user advances through each topic.
Future<void> showMiltvPlusGuide(
  BuildContext context, {
  required String profileName,
}) async {
  final steps = <_GuideStep>[
    _GuideStep(
      icon: Icons.play_circle_fill_rounded,
      color: const Color(0xFF5BE58B),
      title: profileName.trim().isEmpty || profileName == 'Usuario MILTVPLUS'
          ? '¡Bienvenido a MILTVPLUS!'
          : '¡Bienvenido, ${profileName.trim()}!',
      detail:
          'Esta guía te muestra las funciones principales paso a paso. Usá “Siguiente” para continuar y “Anterior” para volver.',
    ),
    const _GuideStep(
      icon: Icons.live_tv_rounded,
      color: Color(0xFF58C7FF),
      title: 'TV en Vivo y Deportes',
      detail:
          'En TV en Vivo podés buscar señales y organizarlas por categoría. Deportes tiene su sección propia. La disponibilidad depende de las listas públicas o autorizadas que estén activas.',
    ),
    const _GuideStep(
      icon: Icons.tune_rounded,
      color: Color(0xFFFF7CA8),
      title: 'Perfil y configuración',
      detail:
          'Desde el menú lateral entrá en Perfil y configuración para guardar tu nombre, importar listas M3U autorizadas, administrar tu cuenta, limpiar la caché de imágenes y buscar actualizaciones.',
    ),
    const _GuideStep(
      icon: Icons.system_update_alt_rounded,
      color: Color(0xFF65B7FF),
      title: 'Cómo se actualiza MILTVPLUS',
      detail:
          'La aplicación consulta la versión publicada. Si hay una versión más nueva, descarga el APK y comprueba su SHA-256 antes de abrir el instalador de Android. Android pide confirmar la instalación; nunca se instala silenciosamente.',
    ),
    const _GuideStep(
      icon: Icons.shield_outlined,
      color: Color(0xFFB79CFF),
      title: 'Seguridad y ayuda',
      detail:
          'La Zona +18 tiene sus controles de acceso propios. Protegé tu PIN y usá solo fuentes de contenido autorizadas. Si necesitás repasar estos pasos, podés volver a abrir esta guía desde Configuración.',
    ),
    const _GuideStep(
      icon: Icons.settings_remote_rounded,
      color: Color(0xFFFFB74D),
      title: 'Usala en tu televisor',
      detail:
          'En pantallas compatibles, navegá con las flechas del control remoto y confirmá con el botón central. En el celular, tocá las opciones en pantalla. Si una señal no abre, puede estar fuera de servicio o no ser compatible.',
    ),
  ];

  var currentStep = 0;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => PopScope(
      canPop: false,
      child: StatefulBuilder(
        builder: (context, setState) {
          final step = steps[currentStep];
          final isLast = currentStep == steps.length - 1;
          return Dialog(
            backgroundColor: const Color(0xFF111521),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        color: step.color.withValues(alpha: .13),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: step.color.withValues(alpha: .18),
                            blurRadius: 14,
                          ),
                        ],
                      ),
                      child: Icon(step.icon, color: step.color, size: 34),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    step.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step.detail,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Semantics(
                    label: 'Paso ${currentStep + 1} de ${steps.length}',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(
                        steps.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: index == currentStep ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: index == currentStep
                                ? AppTheme.accent
                                : Colors.white24,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'PASO ${currentStep + 1} DE ${steps.length}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (currentStep > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => currentStep--),
                      child: const Text('ANTERIOR'),
                    ),
                  FilledButton(
                    onPressed: () {
                      if (isLast) {
                        Navigator.of(dialogContext).pop();
                      } else {
                        setState(() => currentStep++);
                      }
                    },
                    child: Text(isLast ? 'FINALIZAR GUÍA' : 'SIGUIENTE'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class _GuideStep {
  const _GuideStep({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String detail;
}

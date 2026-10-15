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
          ? 'Bienvenido a MILTVPLUS'
          : '¡Bienvenido, ${profileName.trim()}!',
      detail: 'MILTVPLUS es una aplicación de entretenimiento para organizar señales de televisión y explorar catálogos desde el celular o una pantalla compatible. Esta guía te acompaña por las funciones principales; avanzá con Siguiente y volvé cuando quieras desde Configuración.',
    ),
    const _GuideStep(
      icon: Icons.home_rounded,
      color: Color(0xFF5BE58B),
      title: 'Empezá por Inicio',
      detail: 'Inicio es el punto de partida para recorrer la aplicación. Usá el menú lateral para entrar a cada sección. En celulares, tocá una opción; en Android TV o dispositivos compatibles, probá las flechas y el botón central del control remoto. Si algo no responde, volvé a Inicio e intentá de nuevo.',
    ),
    const _GuideStep(
      icon: Icons.live_tv_rounded,
      color: Color(0xFF58C7FF),
      title: 'TV en Vivo y Deportes',
      detail: 'Entrá a TV en Vivo para consultar las señales disponibles. Usá el buscador para encontrar un canal o país y los filtros para reducir la lista. Tocá una señal para intentar reproducirla. La disponibilidad depende de que la fuente siga activa, sea compatible y tengas autorización para verla.',
    ),
    const _GuideStep(
      icon: Icons.sports_soccer_rounded,
      color: Color(0xFFFFB74D),
      title: 'Deportes, todo en su lugar',
      detail: 'La sección Deportes mantiene las señales deportivas separadas del resto de la televisión. Si la lista muestra pocas opciones, revisá las listas importadas en Configuración. No todas las señales están disponibles todo el día y una fuente externa puede dejar de funcionar sin aviso.',
    ),
    const _GuideStep(
      icon: Icons.movie_creation_outlined,
      color: Color(0xFFB79CFF),
      title: 'Películas, series y anime',
      detail: 'Recorré los catálogos por sección y elegí un título para ver su información. La disponibilidad y los datos dependen del catálogo conectado. Los títulos, las descripciones y los archivos deben ser legítimos y estar publicados con autorización. La aplicación no puede garantizar que un enlace externo permanezca activo.',
    ),
    const _GuideStep(
      icon: Icons.tune_rounded,
      color: Color(0xFFFF7CA8),
      title: 'Personalizá tu perfil',
      detail: 'En Perfil y configuración vas a encontrar las preferencias del dispositivo, el nombre de perfil, la cuenta, la carga de listas, las opciones para equipos compatibles, el tamaño de texto y la guía. Guardá los cambios cuando la pantalla lo indique. Algunas funciones de cuenta requieren que el servicio esté configurado y que haya conexión.',
    ),
    const _GuideStep(
      icon: Icons.playlist_add_check_rounded,
      color: Color(0xFF57D9A3),
      title: 'Cómo cargar una lista de canales',
      detail: 'Usá una lista pública o una lista propia que tengas permiso para utilizar. Pegá la dirección en el apartado de listas y elegí Importar. Esperá el resultado antes de salir. Una lista puede contener miles de entradas, pero eso no significa que todas estén activas: si un canal no abre, puede estar caído, restringido o usar un formato no compatible.',
    ),
    const _GuideStep(
      icon: Icons.settings_input_antenna_rounded,
      color: Color(0xFF65B7FF),
      title: 'Codificadores y equipos externos',
      detail: 'Para conectar un sintonizador o codificador, necesitás conocer la marca, el modelo y qué tipo de salida ofrece. La aplicación puede trabajar con señales o listas que el equipo publique mediante una conexión compatible; no puede leer directamente cualquier entrada HDMI del televisor. Antes de configurar un equipo, consultá su manual y confirmá que permita compartir la señal en tu red.',
    ),
    const _GuideStep(
      icon: Icons.shield_outlined,
      color: Color(0xFFB79CFF),
      title: 'Cuenta, privacidad y Zona +18',
      detail: 'Usá una cuenta propia y mantené protegidos tus datos de acceso. Cerrá la sesión si compartís el dispositivo. La Zona +18 requiere sus controles de acceso y está destinada exclusivamente a personas adultas. No compartas tu PIN ni ingreses claves de servicios ajenos. Los controles de la aplicación no reemplazan los controles parentales del dispositivo.',
    ),
    const _GuideStep(
      icon: Icons.system_update_alt_rounded,
      color: Color(0xFFFF7CA8),
      title: 'Actualizaciones y cuidado de la app',
      detail: 'Cuando haya una versión nueva publicada, MILTVPLUS puede avisarte para que revises la actualización. Android puede pedirte confirmar la instalación o autorizar al instalador. Instalá únicamente versiones provenientes de la publicación oficial del proyecto. Limpiar la caché de imágenes sirve para resolver algunos problemas visuales; no debería borrar tu perfil ni las listas guardadas.',
    ),
    const _GuideStep(
      icon: Icons.help_outline_rounded,
      color: Color(0xFF58C7FF),
      title: 'Si algo no funciona',
      detail: 'Primero comprobá la conexión a internet y volvé a abrir la sección. Probá otra señal para distinguir un problema del canal de uno general. Si una lista no se importa, verificá que la dirección esté completa y que el formato sea compatible. Si la pantalla queda vacía, volvé a Inicio y abrí la sección otra vez. No compartas contraseñas, códigos de acceso ni datos privados al pedir ayuda.',
    ),
    const _GuideStep(
      icon: Icons.check_circle_outline_rounded,
      color: Color(0xFF5BE58B),
      title: 'Listo: ya podés recorrer MILTVPLUS',
      detail: 'Explorá a tu ritmo, mantené tus listas organizadas y usá Configuración para adaptar la experiencia a tu equipo. La disponibilidad de cada señal o catálogo puede cambiar. Gracias por elegir MILTVPLUS: una experiencia pensada para que navegar sea claro, cómodo y sencillo.',
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

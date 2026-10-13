import 'package:flutter/material.dart';

/// Pantalla reutilizable para mostrar un bloqueo decidido por una comprobación
/// de seguridad real. Esta pantalla no detecta manipulación por sí sola.
class SecurityRestrictedScreen extends StatelessWidget {
  const SecurityRestrictedScreen({
    super.key,
    this.reason = 'No se pudo validar una condición de seguridad.',
    this.incidentCode = 'MILTV-SEC-403',
  });

  final String reason;
  final String incidentCode;

  @override
  Widget build(BuildContext context) {
    const red = Color(0xFFFF3548);
    const background = Color(0xFF08090D);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111116),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: red.withValues(alpha: .75), width: 1.4),
                    boxShadow: [
                      BoxShadow(
                        color: red.withValues(alpha: .10),
                        blurRadius: 34,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: red.withValues(alpha: .10),
                          border: Border.all(color: red, width: 1.5),
                        ),
                        child: const Icon(Icons.gpp_bad_outlined, color: red, size: 43),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'MILTV PLUS',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          letterSpacing: 4,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'ACCESO RESTRINGIDO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: red,
                          fontSize: 27,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'No se puede continuar hasta revisar el estado de seguridad.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFFB8B8C2), height: 1.5),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _StatusRow(label: 'ESTADO', value: 'RESTRINGIDO', valueColor: red),
                            const SizedBox(height: 12),
                            _StatusRow(label: 'INCIDENTE', value: incidentCode),
                            const SizedBox(height: 12),
                            _StatusRow(label: 'DETALLE', value: reason),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Esta pantalla solo presenta una restricción informada por la aplicación; no confirma por sí misma que exista manipulación. No se recopilan ni envían IP, identificadores del dispositivo ni datos a servicios de terceros desde esta pantalla.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF858591), fontSize: 12, height: 1.55),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          label: const Text('VOLVER'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white30),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.label,
    required this.value,
    this.valueColor = Colors.white,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF858591),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
}

import 'package:flutter/material.dart';
import '../../../../core/theme/grimoire_theme.dart';
import '../../domain/models/game_balance_metrics.dart';

class AnomaliesDetectorWidget extends StatelessWidget {
  final List<CardAnomaly> anomalies;
  final ValueChanged<Map<String, dynamic>> onInspectCard;

  const AnomaliesDetectorWidget({
    super.key,
    required this.anomalies,
    required this.onInspectCard,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: GrimoireTheme.borderSubtle.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: anomalies.isEmpty
                      ? GrimoireTheme.accentEmerald.withValues(alpha: 0.2)
                      : GrimoireTheme.accentAmber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: anomalies.isEmpty
                        ? GrimoireTheme.accentEmerald.withValues(alpha: 0.5)
                        : GrimoireTheme.accentAmber.withValues(alpha: 0.5),
                  ),
                ),
                child: Icon(
                  anomalies.isEmpty ? Icons.verified_outlined : Icons.warning_amber_rounded,
                  size: 16,
                  color: anomalies.isEmpty ? GrimoireTheme.accentEmerald : GrimoireTheme.accentAmber,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        const Text(
                          'Detección de Anomalías de Balance',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: anomalies.isEmpty ? GrimoireTheme.accentEmerald.withValues(alpha: 0.2) : GrimoireTheme.accentAmber.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            anomalies.isEmpty ? 'Todo en Orden' : '${anomalies.length} avisos',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: anomalies.isEmpty ? GrimoireTheme.accentEmerald : GrimoireTheme.accentAmber,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Identifica cartas atípicas, posibles desbalances de poder o datos faltantes',
                      style: TextStyle(fontSize: 11, color: GrimoireTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (anomalies.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GrimoireTheme.accentEmerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: GrimoireTheme.accentEmerald.withValues(alpha: 0.25)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: GrimoireTheme.accentEmerald, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'No se detectaron cartas rotas, inconsistencias graves de coste ni valores extremos. El mazo luce saludable.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: anomalies.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final anom = anomalies[idx];
                final color = anom.severity == AnomalySeverity.alert
                    ? const Color(0xFFF43F5E)
                    : (anom.severity == AnomalySeverity.warning
                        ? const Color(0xFFF59E0B)
                        : const Color(0xFF38BDF8));

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        anom.severity == AnomalySeverity.alert
                            ? Icons.error_outline
                            : (anom.severity == AnomalySeverity.warning ? Icons.warning_amber : Icons.info_outline),
                        size: 20,
                        color: color,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anom.title,
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              anom.description,
                              style: const TextStyle(fontSize: 11, color: Color(0xFFCBD5E1)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: color,
                          backgroundColor: color.withValues(alpha: 0.15),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: const Icon(Icons.palette_outlined, size: 14),
                        label: const Text('Inspeccionar', style: TextStyle(fontSize: 11)),
                        onPressed: () => onInspectCard(anom.card),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

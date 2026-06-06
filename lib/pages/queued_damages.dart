import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class QueuedDamages extends StatelessWidget {
  const QueuedDamages({super.key});

  Color _cardColor(ColorScheme cs, Map<String, dynamic> data, bool isDark) {
    final declined = (data['declined'] ?? false) == true;
    final resolved = (data['resolved'] ?? false) == true;
    final confirmed = (data['confirmed'] ?? false) == true;

    if (declined) {
      final color = Colors.red;
      return color.withValues(alpha: isDark ? 0.10 : 0.08);
    }

    if (resolved && !confirmed) {
      final color = Colors.orange;
      return color.withValues(alpha: isDark ? 0.10 : 0.08);
    }

    if (resolved && confirmed) {
      final color = Colors.green;
      return color.withValues(alpha: isDark ? 0.10 : 0.08);
    }

    return cs.surface;
  }

  Future<void> _resolveDamage(
    BuildContext context,
    DocumentReference docRef,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: const Text('Confirm Resolution'),
          content: const Text(
            'Mark this damage as resolved?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (ok != true) {
      ToastService.info('Resolution cancelled');
      return;
    }

    try {
      await docRef.update({
        'resolved': true,
        'confirmed': false, // explicitly enforce
        'declined': false,  // optional but logical cleanup
        'resolvedAt': FieldValue.serverTimestamp(),
      });

      ToastService.success('Damage marked as resolved');
    } catch (e) {
      if (!context.mounted) return;
      ToastService.error('Failed to resolve damage: $e');
    }
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Pending timestamp';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '${dt.day}/${dt.month}/${dt.year} • $h:$m';
    }
    return timestamp.toString();
  }

  Widget _metaLine(ColorScheme cs, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label $value',
        style: TextStyle(
          fontSize: 12,
          color: cs.onSurfaceVariant,
        ),
      ),
    );
  }

  String _safeFormat(dynamic timestamp) {
    if (timestamp == null) return 'Pending';
    if (timestamp is Timestamp) {
      final dt = timestamp.toDate();
      return '${dt.day}/${dt.month}/${dt.year} • '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    }
    return 'Invalid date';
  }

  Widget _stateChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('damagesReports').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  margin: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  child: Text(
                    'No queued damages found.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              );
            }

            final bikeDocs = snapshot.data!.docs;

            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: bikeDocs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final bikeDoc = bikeDocs[index];
                final bikeId = bikeDoc.id;

                return Container(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: cs.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: ExpansionTile(
                    tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: const Border(),            // no border when expanded
                    collapsedShape: const Border(),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    collapsedIconColor: cs.onSurfaceVariant,
                    iconColor: cs.primary,
                    textColor: cs.onSurface,
                    collapsedTextColor: cs.onSurface,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.motorcycle_rounded, color: cs.primary),
                    ),
                    title: Text(
                      bikeId,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      'Tap to view damage reports',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                    children: [
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('damagesReports')
                            .doc(bikeId)
                            .collection('items')
                            .snapshots(),
                        builder: (context, damageSnapshot) {
                          if (!damageSnapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: LinearProgressIndicator(),
                            );
                          }

                          final docs = damageSnapshot.data!.docs;

                          final damages = [...docs];

                          int priority(Map<String, dynamic> data) {
                            final declined = (data['declined'] ?? false) == true;
                            final resolved = (data['resolved'] ?? false) == true;
                            final confirmed = (data['confirmed'] ?? false) == true;

                            if (declined) return 0;
                            if (resolved && !confirmed) return 1;
                            if (confirmed) return 2;
                            return 3;
                          }

                          damages.sort((a, b) {
                            final ad = a.data() as Map<String, dynamic>;
                            final bd = b.data() as Map<String, dynamic>;

                            final pa = priority(ad);
                            final pb = priority(bd);

                            if (pa != pb) return pa.compareTo(pb);

                            final ta = ad['timestamp'];
                            final tb = bd['timestamp'];

                            if (ta is Timestamp && tb is Timestamp) {
                              return ta.compareTo(tb);
                            }

                            return 0;
                          });

                          if (damages.isEmpty) {
                            return Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'No damages reported for this bike.',
                                style: TextStyle(color: cs.onSurfaceVariant),
                              ),
                            );
                          }

                          return Column(
                            children: damages.map((doc) {
                              final data = doc.data() as Map<String, dynamic>;
                              final declined = (data['declined'] ?? false) == true;
                              final resolved = (data['resolved'] ?? false) == true;
                              final confirmed = (data['confirmed'] ?? false) == true;

                              final bg = _cardColor(cs, data, isDark);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: bg,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: (declined
                                            ? Colors.red
                                            : resolved && !confirmed
                                                ? Colors.orange
                                                : confirmed
                                                    ? Colors.green
                                                    : cs.outlineVariant)
                                        .withValues(alpha: isDark ? 0.25 : 0.35),
                                    width: 1,
                                  ),
                                  boxShadow: isDark
                                      ? [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.25),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : [],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: cs.primary.withValues(alpha: 0.08),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            resolved && confirmed
                                                ? Icons.verified_rounded
                                                : resolved
                                                    ? Icons.check_circle_rounded
                                                    : declined
                                                        ? Icons.block_rounded
                                                        : Icons.report_problem_rounded,
                                            color: resolved && confirmed
                                                ? Colors.green
                                                : resolved
                                                    ? Colors.orange
                                                    : declined
                                                        ? Colors.red
                                                        : cs.primary,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                data['message']?.toString() ?? '',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: cs.onSurface,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: [
                                                  _stateChip(
                                                    declined
                                                        ? 'Declined'
                                                        : resolved
                                                            ? 'Resolved'
                                                            : 'Pending',
                                                    declined
                                                        ? Colors.red
                                                        : resolved
                                                            ? Colors.orange
                                                            : cs.primary,
                                                  ),
                                                  _stateChip(
                                                    confirmed ? 'Confirmed' : 'Unconfirmed',
                                                    confirmed ? Colors.green : Colors.blue,
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 10),
                                              Text(
                                                'Posted by ${data['postedBy'] ?? 'Unknown'} on ${_formatTimestamp(data['timestamp'])}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: cs.onSurfaceVariant,
                                                ),
                                              ),
                                              if (resolved && !confirmed) ...[
                                                _metaLine(cs, 'Resolved on', _safeFormat(data['resolvedAt'])),
                                              ] else if (declined) ...[
                                                _metaLine(
                                                  cs,
                                                  'Declined by',
                                                  "${data['declinedBy'] ?? 'Unknown'} on ${_safeFormat(data['declinedAt'])}",
                                                ),
                                              ] else if (confirmed) ...[
                                                _metaLine(
                                                  cs,
                                                  'Confirmed by',
                                                  "${data['confirmedBy'] ?? 'Unknown'} on ${_safeFormat(data['confirmedAt'])}",
                                                ),
                                              ] else ...[
                                                _metaLine(cs, 'Time:', _safeFormat(data['timestamp'])),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        FilledButton.icon(
                                          onPressed: resolved
                                              ? null
                                              : () => _resolveDamage(context, doc.reference),
                                          icon: const Icon(Icons.done_rounded),
                                          label: const Text('Resolve'),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ],

                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
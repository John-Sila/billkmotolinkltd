// ========================= disburse_section.dart =========================

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum DisburseReason {
  sale,
  theft,
  loss,
  changeOfOwnership,
  auctionOrRepossession,
  absoluteDepreciation,
  catastrophicLoss,
}

class DisburseSection extends StatelessWidget {
  final void Function(BuildContext, Map<String, dynamic>) onTap;

  const DisburseSection({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final formatter = DateFormat('EEE dd MMM yyyy, HH:mm');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection("store")
          .orderBy("createdAt", descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_outlined,
                  size: 52,
                  color: colors.onSurfaceVariant.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 12),
                Text(
                  "No items to dispose",
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final items = snapshot.data!.docs
            .map<Map<String, dynamic>>((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final timestamp = data["createdAt"] as Timestamp?;
              final DateTime? created = timestamp?.toDate();
              return {
                "id": doc.id,
                ...data,
                "createdAtFormatted": created != null ? formatter.format(created) : null,
              };
            })
            .toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info note
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Text(
                'Use this section only for inventory permanently leaving the company.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),

            const Divider(),

            const SizedBox(height: 8),

            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.83,
                ),
                itemCount: items.length,
                itemBuilder: (ctx, index) {
                  final item = items[index];
                  final id = item["id"] as String;
                  final name = item["name"] as String;
                  final imageURL = item["imageURL"] as String?;
                  final createdAtFormatted = item["createdAtFormatted"] as String?;

                  return Card(
                    elevation: 3,
                    surfaceTintColor: colors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    clipBehavior: Clip.antiAlias, // important for background image
                    child: Stack(
                      children: [
                        // ================== IMAGE AS BACKGROUND ==================
                        imageURL != null && imageURL.isNotEmpty
                            ? Image.network(
                                imageURL,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) {
                                  return ColoredBox(
                                    color: colors.surfaceContainer,
                                    child: const Center(
                                      child: Icon(Icons.broken_image, size: 40),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: colors.surfaceContainer,
                                alignment: Alignment.center,
                                child: Icon(Icons.image, size: 40, color: colors.onSurfaceVariant),
                              ),

                        // ================== SEMI‑TRANSPARENT BOTTOM OVERLAY ==================
                        Align(
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  colors.surface.withValues(alpha: 0.85),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // ================== TEXT CONTENT ==================
                        const SizedBox.expand(),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.end, // text at bottom
                            children: [
                              // Name
                              Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),

                              // Created
                              if (createdAtFormatted != null)
                                Text(
                                  createdAtFormatted,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurface,
                                    fontSize: 11,
                                  ),
                                ),

                              const SizedBox(height: 10),

                              // Dispose button (on top of image, readable)
                              FilledButton.icon(
                                onPressed: () => _showDisburseDialog(
                                  context,
                                  id: id,
                                  name: name,
                                  imageURL: imageURL,
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.error.withValues(alpha: 0.95),
                                  foregroundColor: colors.onError,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: const Icon(Icons.delete_forever, size: 16),
                                label: Text(
                                  "Dispose",
                                  style: theme.textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );

                },
              ),
            ),
          ],
        );


        
      },
    );
  }

  /// Shows the dialog + loading when disposing
  Future<void> _showDisburseDialog(
    BuildContext context, {
    required String id,
    required String name,
    String? imageURL,
  }) async {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    DisburseReason reason = DisburseReason.loss;
    final amountController = TextEditingController();
    bool showAmount = false;
    bool _isLoading = false;

    await showDialog(
      context: context,
      barrierDismissible: !_isLoading,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                if (imageURL != null)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: colors.surfaceContainer,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        imageURL,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image, size: 20),
                      ),
                    ),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Inventory Disposal',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: _isLoading
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            'Disposing item...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Under what grounds is this item being disposed?',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        RadioListTile<DisburseReason>(
                          title: const Text('By sale'),
                          value: DisburseReason.sale,
                          groupValue: reason,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              reason = value;
                              showAmount = value == DisburseReason.sale;
                            });
                          },
                        ),
                        RadioListTile<DisburseReason>(
                          title: const Text('By theft'),
                          value: DisburseReason.theft,
                          groupValue: reason,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              reason = value;
                              showAmount = false;
                            });
                          },
                        ),
                        RadioListTile<DisburseReason>(
                          title: const Text('By untracked loss of property'),
                          value: DisburseReason.loss,
                          groupValue: reason,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              reason = value;
                              showAmount = false;
                            });
                          },
                        ),
                        RadioListTile<DisburseReason>(
                          title: const Text('By change of ownership'),
                          value: DisburseReason.changeOfOwnership,
                          groupValue: reason,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              reason = value;
                              showAmount = false;
                            });
                          },
                        ),
                        RadioListTile<DisburseReason>(
                          title: const Text('By auction or repossession'),
                          value: DisburseReason.auctionOrRepossession,
                          groupValue: reason,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              reason = value;
                              showAmount = false;
                            });
                          },
                        ),
                        RadioListTile<DisburseReason>(
                          title: const Text('By absolute depreciation'),
                          value: DisburseReason.absoluteDepreciation,
                          groupValue: reason,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              reason = value;
                              showAmount = false;
                            });
                          },
                        ),
                        RadioListTile<DisburseReason>(
                          title: const Text('By catastrophic loss (e.g. fire, floods)'),
                          value: DisburseReason.catastrophicLoss,
                          groupValue: reason,
                          onChanged: (value) {
                            if (value == null) return;
                            setDialogState(() {
                              reason = value;
                              showAmount = false;
                            });
                          },
                        ),

                        if (showAmount) ...[
                          const SizedBox(height: 16),
                          TextField(
                            controller: amountController,
                            decoration: InputDecoration(
                              labelText: 'Amount sold (KES)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: colors.surfaceContainer,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: _isLoading ? null : () => Navigator.of(ctx).pop(),
                child: Text(
                  'Cancel',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.error,
                  foregroundColor: colors.onError,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () async {
                  if (_isLoading) return;
                  setDialogState(() {
                    _isLoading = true;
                  });

                  final DateTime now = DateTime.now();
                  final String amountStr = amountController.text.trim();
                  final double? amount = amountStr.isEmpty ? null : double.tryParse(amountStr);

                  String statement = switch (reason) {
                    DisburseReason.sale =>
                      amount == null
                          ? "Item was sold"
                          : "Item was sold, amount received: KES ${amount.toStringAsFixed(2)}",
                    DisburseReason.theft => "Item was stolen",
                    DisburseReason.loss => "Item was lost without proper tracking",
                    DisburseReason.changeOfOwnership => "Item changed ownership",
                    DisburseReason.auctionOrRepossession => "Item was auctioned or repossessed",
                    DisburseReason.absoluteDepreciation => "Item fully depreciated",
                    DisburseReason.catastrophicLoss => "Item was lost due to a catastrophic event",
                  };

                  try {
                    // 1. Delete from /store/ID
                    await FirebaseFirestore.instance
                        .collection("store")
                        .doc(id)
                        .delete();

                    // 2. Record transaction in /store_transactions/ID
                    await FirebaseFirestore.instance
                        .collection("store_transactions")
                        .doc(id)
                        .set({
                      "id": id,
                      "itemName": name,
                      "dateDeleted": now,
                      "imageURL": imageURL,
                      "reason": reason.name,
                      if (amount != null) "amount": amount,
                      "statement": statement,
                    });

                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Item "$name" disposed.')),
                    );
                  } catch (e) {
                    setDialogState(() {
                      _isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Dispose failed: $e')),
                    );
                  }
                },
                child: _isLoading
                    ? SizedBox(
                        width: 80,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Disposing',
                              style: theme.textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      )
                    : const Text('Dispose'),
              ),
            ],
          );
        },
      ),
    );
  }
}
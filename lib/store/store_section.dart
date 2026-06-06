import 'package:billkmotolinkltd/utils/utility_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreSection extends StatelessWidget {
  const StoreSection({
    super.key, 
    this.currentUserUid,
  });

  final String? currentUserUid;

  DateTime? _parseTimestamp(dynamic rawTime) {
    if (rawTime == null) return null;
    if (rawTime is Timestamp) return rawTime.toDate();
    if (rawTime is DateTime) return rawTime;
    return null;
  }

  Future<String> _getCurrentUserName() async {
    if (currentUserUid == null) return 'Current User';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserUid!)
          .get();
      return userDoc.data()?['userName'] as String? ?? 'Current User';
    } catch (e) {
      return 'Current User';
    }
  }

  /// NEW: Full screen transactions page
  void _showTransactionsPage(BuildContext context, Map<String, dynamic> item) {
    final transactionsRaw = item["transactions"] as List<dynamic>? ?? [];
    final transactions = transactionsRaw
        .whereType<Map<String, dynamic>>()
        .map((transaction) {
          final rawTime = transaction["time"];
          final parsedTime = _parseTimestamp(rawTime);
          return {
            ...transaction,
            "parsedTime": parsedTime,
          };
        })
        .toList()
      ..sort((a, b) {
        final ta = a["parsedTime"] as DateTime?;
        final tb = b["parsedTime"] as DateTime?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ItemDetailsPage(item: item, transactions: transactions),
      ),
    );
  }

  Future<void> _showConfirmationDialog(
    BuildContext context,
    Map<String, dynamic> item,
  ) async {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final confirmedStatus = (item["confirmedStatus"] as bool?) ?? true;
    final transactionsRaw = item["transactions"] as List<dynamic>? ?? [];
    final droppedBy = item["droppedBy"] as String? ?? "Unknown";
    final hasTransactions = transactionsRaw.isNotEmpty;
    final category = item["category"] as String? ?? "Unknown";
    final itemName = item["name"] as String? ?? "Unknown";

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          item["name"] as String? ?? "Unknown Item",
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: confirmedStatus ? colors.primaryContainer : colors.errorContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      confirmedStatus ? Icons.check_circle : Icons.pending_outlined,
                      size: 16,
                      color: confirmedStatus ? colors.onPrimaryContainer : colors.onErrorContainer,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        confirmedStatus ? "Status Confirmed" : "Pending Confirmation",
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: confirmedStatus ? colors.onPrimaryContainer : colors.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (!confirmedStatus) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.errorContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.error.withOpacity(0.2), width: 1),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline, size: 18, color: colors.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "Confirm status from $droppedBy",
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onErrorContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // Item Details
              if (item["isAssigned"] != null)
                if (item["isAssigned"] as bool)
                  _buildDetailRow(context, "Status", "Assigned", colors.primary)
                else
                  _buildDetailRow(context, "Status", "Unassigned", colors.error)
              else
                _buildDetailRow(context, "Status", "Indeterminate", colors.onSurfaceVariant),
              if (item["assignedTo"] != null && item["assignedTo"] != "None")
                _buildDetailRow(context, "Assigned To", item["assignedTo"] as String, colors.secondary),
              if (item["movement"] != null)
                _buildDetailRow(context, "Movement", item["movement"] as String, colors.tertiary),
              if (item["category"] != null)
                _buildDetailRow(context, "Category", category, colors.tertiary),

              const SizedBox(height: 16),

              // Transactions Link or Empty
              if (hasTransactions) ...[
                Text("Transactions", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _showTransactionsPage(context, item);
                  },
                  icon: const Icon(Icons.history, size: 18),
                  label: const Text("View Transactions"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primaryContainer,
                    foregroundColor: colors.onPrimaryContainer,
                  ),
                ),
              ] else
                Text("No transactions", style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Close"),
          ),
          if (!confirmedStatus) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                if (!context.mounted) return;

                final now = DateTime.now();
                final key = AppDateUtils.formattedFileDate(now);
                final userName = await _getCurrentUserName();

                try {
                  final itemName = item["name"] as String;
                  final itemCategory = category;

                  // 1. Update store document (already exists in your code)
                  final storeQuery = await FirebaseFirestore.instance
                      .collection("store")
                      .where("name", isEqualTo: itemName)
                      .get();

                  if (storeQuery.docs.isNotEmpty) {
                    final storeRef = storeQuery.docs.first.reference;

                    await storeRef.update({
                      "isAssigned": false,
                      "confirmedStatus": true,
                      "transactions": FieldValue.arrayUnion([
                        {
                          "message": "Item confirmed to enter the store by $userName",
                          "time": now,
                        }
                      ]),
                    });
                  }

                  // 2. If category is "Batteries", update corresponding battery document
                  if (itemCategory == "Batteries") {
                    final batteryQuery = await FirebaseFirestore.instance
                        .collection("batteries")
                        .where("batteryName", isEqualTo: itemName)
                        .limit(1)
                        .get();

                    if (batteryQuery.docs.isNotEmpty) {
                      final batteryRef = batteryQuery.docs.first.reference;
                      final batteryData = batteryQuery.docs.first.data();
                      final traces = Map<String, dynamic>.from(batteryData['traces'] ?? {});

                      final existingEntries = List<dynamic>.from(
                        traces[key]?['entries'] ?? [],
                      );

                      existingEntries.add(
                        "Confirmed in by $userName at ${AppDateUtils.getCurrentTimeString()}.",
                      );

                      traces[key] = {
                        'dateEdited': now,
                        'entries': existingEntries,
                      };

                      await batteryRef.update({
                        "confirmedStatus": true,
                        "traces": traces,
                      });
                    }
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("$itemName confirmed successfully!"),
                        backgroundColor: colors.primary,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content:
                            Text("$itemName confirmation failed. Please try again. $e"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.check, size: 18),
              label: const Text("Confirm"),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.onPrimary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              "$label: ",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

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
                Icon(Icons.inventory_outlined, size: 52, color: colors.onSurfaceVariant.withOpacity(0.6)),
                const SizedBox(height: 12),
                Text("No items", style: theme.textTheme.titleMedium?.copyWith(color: colors.onSurfaceVariant)),
              ],
            ),
          );
        }

        final items = snapshot.data!.docs.map<Map<String, dynamic>>((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final rawCreatedAt = data["createdAt"];
          final createdAtParsed = _parseTimestamp(rawCreatedAt);
          return {
            "id": doc.id,
            ...data,
            "createdAtFormatted": createdAtParsed != null ? AppDateUtils.formatStandard(createdAtParsed) : null,
          };
        }).toList();

        return GridView.builder(
          padding: const EdgeInsets.all(10),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.83,
          ),
          itemCount: items.length,
          itemBuilder: (ctx, index) {
            final item = Map<String, dynamic>.from(items[index] as Map<String, dynamic>);
            final name = item["name"] as String;
            final imageURL = item["imageURL"] as String?;
            final createdAtFormatted = item["createdAtFormatted"] as String?;
            final confirmedStatus = (item["confirmedStatus"] as bool?) ?? true;
            final hasTransactions = (item["transactions"] as List?)?.isNotEmpty ?? false;

            return Card(
              elevation: confirmedStatus ? 1 : 3,
              color: confirmedStatus ? colors.surface : colors.errorContainer.withOpacity(0.15),
              surfaceTintColor: colors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: confirmedStatus ? Colors.transparent : colors.error.withOpacity(0.4)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _showConfirmationDialog(context, item),
                child: Stack(
                  children: [
                    imageURL != null && imageURL.isNotEmpty
                        ? Image.network(
                            imageURL,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: colors.surfaceContainer,
                              child: const Center(child: Icon(Icons.broken_image, size: 40)),
                            ),
                          )
                        : Container(
                            color: colors.surfaceContainer,
                            alignment: Alignment.center,
                            child: Icon(Icons.image, size: 40, color: colors.onSurfaceVariant),
                          ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Stack(
                        children: [
                          Material(
                            color: colors.inverseSurface.withOpacity(0.92),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () => _showConfirmationDialog(context, item),
                              child: Padding(
                                padding: const EdgeInsets.all(6),
                                child: Icon(
                                  confirmedStatus ? Icons.check_circle : Icons.pending_outlined,
                                  size: 20,
                                  color: confirmedStatus ? colors.primary : colors.tertiary,
                                ),
                              ),
                            ),
                          ),
                          if (hasTransactions)
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: colors.primary.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.history,
                                  size: 12,
                                  color: colors.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (!confirmedStatus)
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, colors.surface.withOpacity(0.95)],
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 12,
                      left: 12,
                      right: 12,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: colors.onSurface,
                              fontWeight: FontWeight.w600,
                              shadows: confirmedStatus
                                  ? null
                                  : [
                                      Shadow(
                                        offset: const Offset(0, 1),
                                        blurRadius: 2,
                                        color: colors.inverseSurface.withOpacity(0.8),
                                      )
                                    ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (createdAtFormatted != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              createdAtFormatted,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// NEW: Full screen item details page
class ItemDetailsPage extends StatelessWidget {
  final Map<String, dynamic> item;
  final List<Map<String, dynamic>> transactions;

  const ItemDetailsPage({
    super.key,
    required this.item,
    required this.transactions,
  });

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return "Unknown time";
    return AppDateUtils.formatStandard(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(item["name"] as String? ?? "Item Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            if (item["imageURL"] != null && (item["imageURL"] as String).isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  item["imageURL"] as String,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: colors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.image, size: 50),
                  ),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: (item["confirmedStatus"] as bool? ?? true) 
                    ? colors.primaryContainer 
                    : colors.errorContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    (item["confirmedStatus"] as bool? ?? true) ? Icons.check_circle : Icons.pending_outlined,
                    size: 20,
                    color: (item["confirmedStatus"] as bool? ?? true) 
                        ? colors.onPrimaryContainer 
                        : colors.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    (item["confirmedStatus"] as bool? ?? true) ? "Status Confirmed" : "Pending Confirmation",
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: (item["confirmedStatus"] as bool? ?? true) 
                          ? colors.onPrimaryContainer 
                          : colors.onErrorContainer,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Item Details
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Item Details", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    if (item["isAssigned"] != null)
                      if (item["isAssigned"] as bool)
                        _buildDetailRow(context, "Status", "Assigned", colors.primary)
                      else
                        _buildDetailRow(context, "Status", "Unassigned", colors.error)
                    else
                      _buildDetailRow(context, "Status", "Indeterminate", colors.onSurfaceVariant),
                    if (item["assignedTo"] != null && item["assignedTo"] != "None")
                      _buildDetailRow(context, "Assigned To", item["assignedTo"] as String, colors.secondary),
                    if (item["assignedToUid"] != null)
                      _buildDetailRow(context, "Assigned UID", item["assignedToUid"] as String, colors.tertiary),
                    if (item["category"] != null)
                      _buildDetailRow(context, "Category", item["category"] as String, colors.primary),
                    if (item["movement"] != null)
                      _buildDetailRow(context, "Movement", item["movement"] as String, colors.secondary),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Transactions
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.history, color: colors.primary, size: 24),
                        const SizedBox(width: 8),
                        Text("Transactions (${transactions.length})", 
                             style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (transactions.isEmpty)
                      Center(
                        child: Text("No transactions yet", 
                                style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant)),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: transactions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, index) {
                          final transaction = transactions[index];
                          final message = transaction["message"] as String? ?? "";
                          final parsedTime = transaction["parsedTime"] as DateTime?;
                          
                          return Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.timeline, size: 20, color: colors.primary),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(message, style: theme.textTheme.bodyMedium),
                                      if (parsedTime != null)
                                        Text(
                                          _formatTime(parsedTime),
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: colors.onSurfaceVariant,
                                            fontSize: 12,
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              "$label: ",
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
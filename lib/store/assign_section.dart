import 'package:billkmotolinkltd/pages/widgets/qr_scanner.dart';
import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:billkmotolinkltd/utils/utility_functions.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AssignSection extends StatefulWidget {
  const AssignSection({super.key});

  @override
  State<AssignSection> createState() => _AssignSectionState();
}

extension DateTimeFormatting on DateTime {
  String weekdayName() {
    return ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][weekday-1];
  }

  String monthName() {
    return ["January","February","March","April","May","June","July","August","September","October","November","December"][month-1];
  }

  String daySuffix() {
    if (day >= 11 && day <= 13) return "th";
    switch (day % 10) {
      case 1: return "st";
      case 2: return "nd";
      case 3: return "rd";
      default: return "th";
    }
  }
}

class _AssignSectionState extends State<AssignSection> {
  bool freeAssignment = false;
  bool loadingToggle = true;
  bool assigningBattery = false;

  List<Map<String, dynamic>> users = [];
  String? selectedUser;

  String? scannedBatteryId;
  String? scannedBatteryName;

  bool scanning = false;
  List<String> _inventoryTypes = [];
  
  String? _selectedCategory;
  final formatter = DateFormat('EEE dd MMM yyyy, HH:mm');

  @override
  void initState() {
    super.initState();
    _loadToggle();
    _loadUsers();
      _loadInventoryTypes();
  }

  Future<void> _loadInventoryTypes() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("general")
          .doc("general_variables")
          .get();

      final types = (doc.data()?["inventory_types"] as List<dynamic>?) ?? [];
      setState(() {
        _inventoryTypes = [
          ...types.cast<String>(),
        ];
        _selectedCategory = _inventoryTypes.isNotEmpty ? _inventoryTypes.first : null;
      });
    } catch (e) {
      ToastService.error("Failed to load inventory types.");
    }
  }

  Future<void> _loadToggle() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection("general")
          .doc("general_variables")
          .get();

      if (!mounted) return;

      setState(() {
        freeAssignment = doc.data()?["freeAssignment"] ?? false;
        loadingToggle = false;
      });
    } catch (e) {
      if (mounted) {
        ToastService.error("Failed to load free assignment toggle.");
        setState(() => loadingToggle = false);
      }
    }
  }

  Future<void> _updateToggle(bool value) async {
    setState(() => freeAssignment = value);

    try {
      await FirebaseFirestore.instance
          .collection("general")
          .doc("general_variables")
          .update({"freeAssignment": value});
    } catch (e) {
      ToastService.error("Failed to update toggle.");
      if (mounted) {
        setState(() => freeAssignment = !value);
      }
    }
  }

  Future<void> _loadUsers() async {
    try {
      // Only fetch users with allowed ranks
      final query = await FirebaseFirestore.instance
          .collection("users")
          .where("userRank", whereIn: ["Rider", "Manager", "Systems, IT"])
          .where("isActive", isEqualTo: true)
          .get();

      if (!mounted) return;

      setState(() {
        users = query.docs.map((doc) {
          final data = doc.data();
          return {
            "uid": doc.id,
            "name": data["userName"] ?? "Unknown",
          };
        }).toList();
      });
    } catch (e) {
      if (mounted) {
        ToastService.error("Failed to load users: $e");
      }
    }
  }

  String cleanExtract(String raw) {
    return raw
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('\n', '')
        .replaceAll('\r', '')
        .trim();
  }

  Future<void> scanBattery() async {
    if (scannedBatteryId != null) {
      ToastService.warning("You can only scan one battery at a time.");
      return;
    }

    setState(() => scanning = true);

    try {
      final qrRaw = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QrScannerPage()),
      );

      if (qrRaw == null) {
        setState(() => scanning = false);
        return;
      }

      final qrCode = cleanExtract(qrRaw);

      final batteryQuery = await FirebaseFirestore.instance
          .collection("batteries")
          .where("qr_code", isEqualTo: qrCode)
          .limit(1)
          .get();

      if (batteryQuery.docs.isEmpty) {
        ToastService.error("No battery found for scanned QR code.");
        setState(() => scanning = false);
        return;
      }

      final batteryDoc = batteryQuery.docs.first;
      final batteryData = batteryDoc.data();
      final batteryName = batteryData["batteryName"] as String? ?? "Unknown Battery";

      final assignedRider = batteryData["assignedRider"]?.toString() ?? "None";
      final assignedBike = batteryData["assignedBike"]?.toString() ?? "None";

      if (assignedRider != "None" || assignedBike != "None") {
        ToastService.warning(
          "Battery already assigned to $assignedRider on $assignedBike",
        );
        setState(() => scanning = false);
        return;
      }

      // ✅ CHECK IF THIS BATTERY NAME EXISTS IN STORE
      final storeQuery = await FirebaseFirestore.instance
          .collection("store")
          .where("name", isEqualTo: batteryName)
          .limit(1)
          .get();

      if (storeQuery.docs.isEmpty) {
        ToastService.error("$batteryName has not been added to the store yet.");
        setState(() => scanning = false);
        return;
      }

      // ✅ If we reach here, both checks passed
      setState(() {
        scannedBatteryId = batteryDoc.id;
        scannedBatteryName = batteryName;
        scanning = false;
      });

    } catch (e) {
      ToastService.error("Error scanning battery: ${e.toString()}");
      setState(() => scanning = false);
    }
  }
    
  Future<void> assignBattery() async {
    if (selectedUser == null || scannedBatteryId == null) {
      ToastService.warning("Please select a rider and scan a battery.");
      return;
    }

    final user = users.firstWhere(
      (u) => u["uid"] == selectedUser,
      orElse: () => {},
    );

    final userName = user["name"] ?? "Unknown";
    final now = DateTime.now();

    try {
      setState(() {
        assigningBattery = true;
      });

      final key = AppDateUtils.formattedFileDate(now);

      final batteryRef = FirebaseFirestore.instance
          .collection("batteries")
          .doc(scannedBatteryId);

      final batterySnap = await batteryRef.get();
      if (!batterySnap.exists) {
        ToastService.error("Battery not found.");
        return;
      }

      final batteryData = batterySnap.data() as Map<String, dynamic>;
      final batteryName = batteryData["batteryName"]?.toString();

      if (batteryName == null) {
        ToastService.error("Battery name missing.");
        return;
      }

      // Build updated traces
      final traces = Map<String, dynamic>.from(batteryData['traces'] ?? {});
      final existingEntries = List<dynamic>.from(
        traces[key]?['entries'] ?? [],
      );

      existingEntries.add(
        "Assigned to $userName by store manager at ${AppDateUtils.getCurrentTimeString()}.",
      );

      traces[key] = {
        'dateEdited': now,
        'entries': existingEntries,
      };

      // Update battery document
      await batteryRef.update({
        "storeAssignedRider": userName,
        "confirmedStatus": true,
        "traces": traces,
      });

      // Now update the corresponding store document
      final storeQuery = await FirebaseFirestore.instance
          .collection("store")
          .where("name", isEqualTo: batteryName)
          .limit(1)
          .get();

      if (storeQuery.docs.isNotEmpty) {
        final storeRef = storeQuery.docs.first.reference;
        final message = "Battery assigned to $userName by store manager.";

        await storeRef.update({
          "assignedTo": userName,
          "assignedToUid": selectedUser,
          "isAssigned": true,
          "confirmedStatus": true,
          "movement": "Outgoing",
          "droppedBy": "None",
          "transactions": FieldValue.arrayUnion([
            {
              "message": message,
              "time": now,
            },
          ]),
        });
      }

      ToastService.success("Battery assigned to $userName successfully!");

      setState(() {
        scannedBatteryId = null;
        scannedBatteryName = null;
        assigningBattery = false;
      });
    } catch (e) {
      ToastService.error("Assignment failed: $e");
      setState(() => assigningBattery = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info note
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
            child: Text(
              "Note: When free assignment is enabled, any user can load any free battery even when it's reserved for somebody else.",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ),

          const Divider(),

          // Toggle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Free assignment mode",
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (loadingToggle)
                  const SizedBox(
                    height: 40,
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
                  SwitchListTile.adaptive(
                    title: Text(
                      "Free assignment",
                      style: theme.textTheme.bodyMedium,
                    ),
                    secondary: freeAssignment
                        ? Icon(Icons.toggle_on, color: colors.primary)
                        : Icon(Icons.toggle_off, color: colors.onSurfaceVariant),
                    value: freeAssignment,
                    activeColor: colors.primary,
                    onChanged: _updateToggle,
                  ),
              ],
            ),
          ),

          const Divider(),
          const SizedBox(height: 16),

          // User dropdown
          Text(
            "Select rider",
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: colors.onSurface.withValues(alpha: 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  hint: Text(
                    "Select rider",
                    style: theme.textTheme.bodyMedium,
                  ),
                  value: selectedUser,
                  onChanged: (value) {
                    setState(() => selectedUser = value);
                  },
                  isExpanded: true,
                  items: (users.toList() // Create a copy to avoid mutating the original list if needed
                    ..sort((a, b) => (a["name"] as String).toLowerCase()
                        .compareTo((b["name"] as String).toLowerCase())))
                  .map((user) {
                    final uid = user["uid"] as String;
                    final name = user["name"] as String;
                    return DropdownMenuItem<String>(
                      value: uid,
                      child: Text(
                        name,
                        style: theme.textTheme.bodyMedium,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // types
          if (_inventoryTypes.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory, // use `value`, not `initialValue` when controlled
              decoration: InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colors.primary, width: 2),
                ),
                filled: true,
                fillColor: colors.surfaceContainer,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
              items: (_inventoryTypes.toList()..sort()) // Creates a copy and sorts it
                .map((cat) {
                  return DropdownMenuItem<String>(
                    value: cat, 
                    child: Text(
                      cat,
                      style: theme.textTheme.bodyMedium,
                    ),
                  );
                }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value; // This triggers the UI rebuild
                    // Reset scanning states if moving away from Batteries
                    if (value != "Batteries") {
                      scannedBatteryId = null;
                      scannedBatteryName = null;
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),

          _selectedCategory == "Batteries"
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Scan battery", style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: scanning || scannedBatteryId != null ? null : scanBattery,
                        icon: scanning
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.qr_code_scanner_rounded, size: 18),
                        label: Text(
                          scanning
                              ? "Scanning..."
                              : scannedBatteryId != null
                                  ? "Battery already scanned"
                                  : "Scan Battery QR",
                        ),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (scannedBatteryName != null) ...[
                      Text("Scanned battery", style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Card(
                        elevation: 1,
                        surfaceTintColor: colors.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Battery: $scannedBatteryName", style: theme.textTheme.titleMedium),
                              const SizedBox(height: 4),
                              if (scannedBatteryId != null)
                                Text(
                                  "ID: $scannedBatteryId",
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: assigningBattery ? null : assignBattery,
                          child: assigningBattery
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text("Assign Battery"),
                        ),
                      ),
                    ] else ...[
                      Text(
                        "No battery scanned.",
                        style: theme.textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ],
                  ],
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("store")
                      .where("category", isEqualTo: _selectedCategory)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildEmptyState(theme, colors); // Helper for the "No Items" UI
                    }

                    return GridView.builder(
                      shrinkWrap: true, // Required if inside a scrollable Column
                      physics: const NeverScrollableScrollPhysics(), 
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.83,
                      ),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (ctx, index) {
                        final doc = snapshot.data!.docs[index];
                        final item = doc.data() as Map<String, dynamic>;
                        final String name = item["name"] ?? "Unknown";
                        final String? imageURL = item["imageURL"];
                        final Timestamp? ts = item["createdAt"] as Timestamp?;
                        final String dateStr = ts != null ? formatter.format(ts.toDate()) : "";

                        return Card(
                          elevation: 3,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _confirmAndAssign(doc.id, name),
                            child: Stack(
                              children: [
                                // Background Image
                                Positioned.fill(
                                  child: imageURL != null && imageURL.isNotEmpty
                                      ? Image.network(imageURL, fit: BoxFit.cover)
                                      : Container(color: colors.surfaceContainer, child: const Icon(Icons.image)),
                                ),
                                // Gradient Overlay
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: Container(
                                    height: 80,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [Colors.transparent, colors.surface.withOpacity(0.9)],
                                      ),
                                    ),
                                  ),
                                ),
                                // Content
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                      Text(dateStr, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
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
                ),
        ],
      ),
    );
  
  }

  Widget _buildEmptyState(ThemeData theme, ColorScheme colors) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          children: [
            Icon(Icons.inventory_2_outlined, size: 48, color: colors.onSurfaceVariant.withOpacity(0.5)),
            const SizedBox(height: 12),
            Text("No items in this category", style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndAssign(String docId, String itemName) async {
    if (selectedUser == null) {
      ToastService.warning("Please select a rider before assigning.");
      return;
    }

    // Get rider name from your 'users' list based on selectedUser (UID)
    final riderName = users.firstWhere((u) => u["uid"] == selectedUser)["name"];

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Assignment"),
        content: Text("Assign $itemName to $riderName?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Assign")),
        ],
      ),
    );

    if (confirmed == true) {
      final now = DateTime.now();
      await FirebaseFirestore.instance.collection("store").doc(docId).update({
        "assignedTo": riderName,
        "assignedToUid": selectedUser,
        "transactions": FieldValue.arrayUnion([
            {
              "message": "Assigned to $riderName on ${AppDateUtils.formatStandard(DateTime.now())}",
              "time": now,
            }
          ]),
        "isAssigned": true,
        "confirmedStatus": true,
        "movement": "Outgoing",
      });
      
      ToastService.success("$itemName assigned to $riderName successfully!");
    }
  }

}

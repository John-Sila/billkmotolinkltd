import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssetManager extends StatefulWidget {
  const AssetManager({super.key});

  @override
  State<AssetManager> createState() => _AssetManagerState();
}

class _AssetManagerState extends State<AssetManager> {
  final _batteryController = TextEditingController();
  final _bikeController = TextEditingController();
  final _destinationController = TextEditingController();
  bool addingBattery = false;
  bool addingBike = false;
  bool addingDestination = false;

  String? _selectedDestination;
  List<String> _destinations = [];
  Map<String, dynamic> _bikes = {};

  @override
  void initState() {
    super.initState();
    _loadGeneralVariables();
  }

  Future<void> _loadGeneralVariables() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .get();

      final data = doc.data() ?? {};

      if (mounted) {
        setState(() {
          _destinations = List<String>.from(data['destinations'] ?? []);
          _bikes = Map<String, dynamic>.from(data['bikes'] ?? {});
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load data: $e', Colors.red);
    }
  }

  // Confirmation dialog helper
  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
    required String action,
    Color? actionColor,
  }) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check, size: 18),
            label: Text(action),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionColor ?? Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addBattery() async {
    final batteryName = _batteryController.text.trim();
    final destination = _selectedDestination;

    if (batteryName.isEmpty || destination == null) {
      _showSnackBar('Battery name and location are required', Colors.orange);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Add New Battery',
      content: 'Add "$batteryName" at $destination?',
      action: 'Add Battery',
      actionColor: Colors.green,
    );

    if (confirmed != true) return;

    try {
      setState(() {
        addingBattery = true;
      });
      final lower = batteryName.toLowerCase();
      final duplicate = await FirebaseFirestore.instance
          .collection('batteries')
          .where('batteryNameLower', isEqualTo: lower)
          .limit(1)
          .get();

      if (duplicate.docs.isNotEmpty) {
        _showSnackBar('Battery with similar name already exists', Colors.red);
        return;
      }

      final now = Timestamp.now();
      final globalDateKey = DateTime.now().toIso8601String().split('T').first;

      await FirebaseFirestore.instance.collection('batteries').add({
        'batteryName': batteryName,
        'batteryNameLower': lower,
        'batteryLocation': destination,
        'assignedBike': 'None',
        'assignedRider': 'None',
        'offTime': now,
        'traces': {
          globalDateKey: {
            'entries': ['Battery was added'],
            'dateEdited': now,
          }
        }
      });

      _batteryController.clear();
      setState(() {
        addingBattery = false;
      });
      _showSnackBar('Battery added successfully', Colors.green);
    } catch (e) {
      setState(() {
        addingBattery = false;
      });
      _showSnackBar('Failed to add battery: $e', Colors.red);
    }
  }

  Future<void> _addBike() async {
    final bikeNameInput = _bikeController.text.trim();
    if (bikeNameInput.isEmpty) {
      ToastService.error('Wrong bike format');
      return;
    }

    // Normalize: uppercase, single spaces between words
    final bikeName = bikeNameInput
        .toUpperCase()
        .replaceAll(RegExp(r'\s+'), ' ') // collapse multiple spaces
        .trim();

    final parts = bikeName.split(' ');

    // 1. Exactly 2 parts, none empty, each 4 chars
    if (parts.length != 2 ||
        parts.any((p) => p.isEmpty) ||
        parts.any((p) => p.length != 4)) {
      ToastService.error('Wrong name format. Use 2 parts of 4 chars, e.g. "KMFF 222G".');
      return;
    }

    final part1 = parts[0]; // e.g. "KMFF"
    final part2 = parts[1]; // e.g. "222G"

    // 2. Part 1: letters only, no digits
    if (!RegExp(r'^[A-Z]+$').hasMatch(part1)) {
      ToastService.error('First part must be letters only (e.g. "KMFF").');
      return;
    }

    // 3. Part 2: 3 digits + 1 letter
    if (!RegExp(r'^[0-9]{3}[A-Z]$').hasMatch(part2)) {
      ToastService.error('Second part must be 3 digits + 1 letter (e.g. "222G").');
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Add New Bike',
      content: 'Add bike "$bikeName"?',
      action: 'Add Bike',
      actionColor: Colors.green,
    );

    if (confirmed != true) return;

    try {
      setState(() {
        addingBike = true;
      });
      if (_bikes.containsKey(bikeName)) {
        ToastService.error('Bike already exists');
        return;
      }

      await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .update({
        'bikes.$bikeName': {
          'assignedRider': 'None',
          'isAssigned': false,
        }
      });

      _bikeController.clear();
      await _loadGeneralVariables();
      setState(() {
        addingBike = false;
      });
      ToastService.success('Bike added successfully');
    } catch (e) {
      setState(() {
        addingBike = false;
      });
      ToastService.error('Failed to add bike: $e');
    }
  }

  Future<void> _addDestination() async {
    final destination = _destinationController.text.trim();
    if (destination.isEmpty) {
      _showSnackBar('A valid destination name is needed', Colors.orange);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Add New Destination',
      content: 'Add destination "$destination"?',
      action: 'Add Destination',
      actionColor: Colors.green,
    );

    if (confirmed != true) return;

    try {
      setState(() {
        addingDestination = true;
      });
      if (_destinations.contains(destination)) {
        _showSnackBar('Destination already exists', Colors.orange);
        return;
      }

      await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .update({
        'destinations': FieldValue.arrayUnion([destination])
      });

      _destinationController.clear();
      await _loadGeneralVariables();
      setState(() {
        addingDestination = false;
       });
      _showSnackBar('Destination added successfully', Colors.green);
    } catch (e) {
      setState(() {
        addingDestination = false;
      });
      _showSnackBar('Failed to add destination: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.info, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _deleteDestination(String destination) async {
    final confirmed = await _showConfirmDialog(
      title: 'Delete Destination',
      content: 'Permanently delete $destination from BILLK locations? This cannot be undone.',
      action: 'Delete',
      actionColor: Colors.red,
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .update({
        'destinations': FieldValue.arrayRemove([destination])
      });

      await _loadGeneralVariables();
      _showSnackBar('Destination deleted successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to delete destination: $e', Colors.red);
    }
  }

  // 1. UPDATE _deleteBike method to check isAssigned
  Future<void> _deleteBike(String bike) async {
    // Check if bike is assigned
    final bikeData = _bikes[bike] as Map<String, dynamic>?;
    final isAssigned = bikeData?['isAssigned'] == true;
    
    if (isAssigned) {
      _showSnackBar('Cannot delete assigned bike "$bike"', Colors.orange);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Delete Bike',
      content: 'Permanently delete $bike from BILLK bikes? This cannot be undone.',
      action: 'Delete',
      actionColor: Colors.red,
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .update({
        'bikes.$bike': FieldValue.delete(),
      });

      await _loadGeneralVariables();
      _showSnackBar('Bike deleted successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to delete bike: $e', Colors.red);
    }
  }

  // 2. UPDATE _deleteBattery method to check assignedRider
  Future<void> _deleteBattery(String batteryId, String batteryName) async {
    // Fetch battery data to check assignment
    try {
      final doc = await FirebaseFirestore.instance.collection('batteries').doc(batteryId).get();
      final data = doc.data() ?? {};
      final assignedRider = data['assignedRider'] ?? 'None';
      
      if (assignedRider != 'None') {
        _showSnackBar('Cannot delete battery assigned to "$assignedRider"', Colors.orange);
        return;
      }
    } catch (e) {
      _showSnackBar('Error checking battery status', Colors.red);
      return;
    }

    final confirmed = await _showConfirmDialog(
      title: 'Delete Battery',
      content: 'Permanently delete $batteryName from BILLK assets? This cannot be undone.',
      action: 'Delete',
      actionColor: Colors.red,
    );

    if (confirmed != true) return;

    try {
      await FirebaseFirestore.instance.collection('batteries').doc(batteryId).delete();
      _showSnackBar('Battery deleted successfully', Colors.green);
    } catch (e) {
      _showSnackBar('Failed to delete battery: $e', Colors.red);
    }
  }

  // 3. UPDATE _buildBatteryList to sort batteries by number
  Widget _buildBatteryList(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Batteries', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('batteries').orderBy('batteryNameLower').snapshots(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.battery_alert, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Text('No batteries found', style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
                  ],
                ),
              );
            }
            
            // Custom sort for BK-BT-001, BK-BT-002, etc.
            final batteries = snap.data!.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = data['batteryName'] ?? 'Unknown';
              return {'doc': doc, 'name': name, 'data': data};
            }).toList();
            
            batteries.sort((a, b) {
              final numA = _extractBatteryNumber(a['name']);
              final numB = _extractBatteryNumber(b['name']);
              return numA.compareTo(numB);
            });
            
            return Column(
              children: batteries.map<Widget>((battery) {
                final doc = battery['doc'] as DocumentSnapshot;
                final data = battery['data'] as Map<String, dynamic>;
                final batteryName = battery['name'] as String;
                final assignedRider = data['assignedRider'] ?? 'None';
                final isAssigned = assignedRider != 'None';
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isAssigned 
                      ? Colors.orange.withValues(alpha: 0.1)
                      : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isAssigned 
                        ? Colors.orange.withValues(alpha: 0.3)
                        : theme.colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.battery_full, 
                        color: isAssigned ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(batteryName, style: theme.textTheme.bodyLarge),
                            if (isAssigned) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Assigned to $assignedRider',
                                style: TextStyle(
                                  color: Colors.orange.shade700,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (isAssigned)
                        Icon(Icons.block, color: Colors.orange, size: 20)
                      else
                        IconButton(
                          icon: Icon(Icons.delete, color: theme.colorScheme.error),
                          onPressed: () => _deleteBattery(doc.id, batteryName),
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  // 4. ADD battery number extraction helper
  int _extractBatteryNumber(String name) {
    final match = RegExp(r'(\d+)').firstMatch(name);
    return int.tryParse(match?.group(1) ?? '0') ?? 0;
  }

  // 5. UPDATE _buildAssetList for bikes to show assignment status
  Widget _buildAssetList(ThemeData theme, String title, List<String> items, Function(String) onDelete) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 12),
            Text('No $title', style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            )),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        ...items.map((item) {
          final bikeData = _bikes[item] as Map<String, dynamic>?;
          final isAssigned = bikeData?['isAssigned'] == true;
          
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAssigned 
                ? Colors.orange.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isAssigned 
                  ? Colors.orange.withValues(alpha: 0.3)
                  : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.two_wheeler, color: isAssigned ? Colors.orange : theme.colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item, style: theme.textTheme.bodyLarge),
                      if (isAssigned) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Assigned',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isAssigned)
                  Icon(Icons.block, color: Colors.orange, size: 20)
                else
                  IconButton(
                    icon: Icon(Icons.delete, color: theme.colorScheme.error),
                    onPressed: () => onDelete(item),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Asset Manager', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.paddingOf(context).bottom + 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add Battery Section
            _buildSection(theme, 'Add Battery', [
              DropdownButtonFormField<String>(
                initialValue: _selectedDestination,
                hint: const Text('Select location'),
                items: _destinations
                    .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedDestination = v),
                decoration: InputDecoration(
                  labelText: 'Location',
                  prefixIcon: Icon(Icons.location_on, color: theme.colorScheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _batteryController,
                decoration: InputDecoration(
                  labelText: 'Battery Name',
                  prefixIcon: Icon(Icons.battery_full, color: theme.colorScheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: addingBattery ? null : _addBattery,
                  icon: addingBattery
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add),
                  label: Text(addingBattery ? 'Adding Battery...' : 'Add Battery'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 32),

            // Add Bike Section
            _buildSection(theme, 'Add Bike', [
              TextField(
                controller: _bikeController,
                decoration: InputDecoration(
                  labelText: 'Eg: KJSK 094J',
                  prefixIcon: Icon(Icons.two_wheeler, color: theme.colorScheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: addingBike ? null : _addBike,
                  icon: addingBike
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add),
                  label: Text(addingBike ? 'Adding Bike...' : 'Add Bike'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 32),

            // Add Destination Section
            _buildSection(theme, 'Add Destination', [
              TextField(
                controller: _destinationController,
                decoration: InputDecoration(
                  labelText: 'Destination Name',
                  prefixIcon: Icon(Icons.location_city, color: theme.colorScheme.primary),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: addingDestination ? null : _addDestination,
                  icon: addingDestination
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.add),
                  label: Text(addingDestination ? 'Adding Destination...' : 'Add Destination'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 40),

            // Delete Assets Section
            _buildSection(theme, 'Manage Assets', [
              _buildAssetList(theme, 'Bikes (${_bikes.length})', _bikes.keys.toList(), 
                  (bike) => _deleteBike(bike)),
              const SizedBox(height: 24),
              _buildAssetList(theme, 'Destinations (${_destinations.length})', _destinations, 
                  (destination) => _deleteDestination(destination)),
              const SizedBox(height: 24),
              _buildBatteryList(theme),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(ThemeData theme, String title, List<Widget> children) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [theme.colorScheme.surface, theme.colorScheme.surfaceContainerHighest],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.add_circle, color: theme.colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _batteryController.dispose();
    _bikeController.dispose();
    _destinationController.dispose();
    super.dispose();
  }
}

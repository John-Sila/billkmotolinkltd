import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:billkmotolinkltd/pages/widgets/qr_scanner.dart';
import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AddSection extends StatefulWidget {
  final Function(Map<String, dynamic>) onAdd;

  const AddSection({super.key, required this.onAdd});

  @override
  State<AddSection> createState() => _AddSectionState();
}

class _AddSectionState extends State<AddSection> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController categoryOtherController = TextEditingController();

  File? imageFile;
  bool _isImageReady = false;
  final picker = ImagePicker();
  final cloudinary = CloudinaryPublic("dpxcjlg2b", "billk_images", cache: false);

  static const String _imageKey = 'add_section_image_path';
  static const String _tabKey = 'active_tab';
  bool _isSubmitting = false;
  String? _selectedCategory;
  bool _showOtherCategoryField = false;
  bool _isScanning = false;
  String? scannedBatteryId;
  String? scannedBatteryName;
  bool scanning = false;

  List<String> _inventoryTypes = [];

  String generateId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random();
    return "BILLK-${List.generate(8, (_) => chars[rand.nextInt(chars.length)]).join()}";
  }

  @override
  void initState() {
    super.initState();
    nameController.addListener(_updateReadyState);
    _loadPendingImage();
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
          "Other", // always add "Other" option
        ];
        _selectedCategory = _inventoryTypes.isNotEmpty ? _inventoryTypes.first : null;
      });
    } catch (e) {
      setState(() {
        _inventoryTypes = ["Other"];
        _selectedCategory = "Other";
      });
    }
  }

  void _updateReadyState() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    nameController.removeListener(_updateReadyState);
    nameController.dispose();
    super.dispose();
  }

  bool get _isSubmitReady {
    final nameValid = nameController.text.trim().isNotEmpty;
    final imageValid = _isImageReady;

    // If the category is shown as "More" (custom), that field must also be non‑empty
    final categoryValid = !_showOtherCategoryField ||
        categoryOtherController.text.trim().isNotEmpty;

    return nameValid && imageValid && categoryValid;
  }

  Future<void> _loadPendingImage() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString(_imageKey);
    if (path == null) return;
    final file = File(path);
    if (await file.exists() && mounted) {
      setState(() {
        imageFile = file;
        _isImageReady = true;
      });
    }
  }

  Future<void> _clearImage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_imageKey);
    if (mounted) {
      setState(() {
        imageFile = null;
        _isImageReady = false;
      });
    }
  }

  Future<String?> _copyToAppDir(XFile xfile) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final newPath = '${dir.path}/$filename';
      await File(xfile.path).copy(newPath);
      return newPath;
    } catch (e) {
      debugPrint('Copy failed: $e');
      return null;
    }
  }

  Future<void> takePicture() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('_tabActiveTabKey', 1);
    await _clearImage();

    final XFile? photo = await picker.pickImage(source: ImageSource.camera);
    if (photo == null || !mounted) return;

    final persistentPath = await _copyToAppDir(photo);
    if (persistentPath != null) {
      await prefs.setString(_imageKey, persistentPath);
      if (mounted) {
        setState(() {
          imageFile = File(persistentPath);
          _isImageReady = true;
        });
      }
    }
  }

  Future<void> _showLoadingDialog(Future<void> future) async {
    final context = this.context;
    final Completer<void> completer = Completer<void>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 16),
            Text(
              'Uploading...',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    ).then((_) {
      if (!completer.isCompleted) completer.complete();
    });

    await future;

    if (completer.isCompleted) return;
    completer.complete();
    if (context.mounted) Navigator.of(context).pop();
  }

  String toCapitalized(String input) {
    if (input.isEmpty) return input;

    // If the string is already all uppercase (no lowercase letters), keep it as-is
    if (input.contains(RegExp(r'[a-z]'))) {
      return input
          .split(' ')
          .map((word) => word.isNotEmpty
              ? word[0].toUpperCase() + word.substring(1).toLowerCase()
              : word)
          .join(' ');
    }

    return input;
  }

  Future<void> addItem() async {
    if (_isSubmitting) return;

    final name = nameController.text.trim();
    if (name.isEmpty || !_isImageReady) return;

    setState(() => _isSubmitting = true);

    String imageURL = '';
    try {
      final response = await cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile!.path,
          resourceType: CloudinaryResourceType.Image,
        ),
      );
      imageURL = response.secureUrl;
    } catch (e) {
      if (mounted) {
        ToastService.error('Image upload failed: $e');
      }
      setState(() => _isSubmitting = false);
      return;
    }

    final capitalizedName = toCapitalized(name);

    // Compute category (handles "More" case)
    final customCategory = _showOtherCategoryField
        ? categoryOtherController.text.trim().isEmpty
            ? "Uncategorized"
            : categoryOtherController.text.trim()
        : null;

    final String category = toCapitalized(customCategory ?? (_selectedCategory ?? "Uncategorized"));

    if (category == "Bikes") {
      final capitalizedName = toCapitalized(name);
      final bool registered = await isBikeRegistered(capitalizedName);

      if (!registered) {
        ToastService.error("'$capitalizedName' is not registered.");
        if (mounted) {
          setState(() => _isSubmitting = false);
        }
        return; // STOP here
      }
    }

    final item = {
      "id": generateId(),
      "name": capitalizedName,
      "imageURL": imageURL,
      "category": category,
      "isAssigned": false,
      "assignedTo": "None",
      "assignedToUid": "None",
      "confirmedStatus": true,
      "transactions": [],
      "createdAt": FieldValue.serverTimestamp(),
    };

    final String itemId = item["id"] as String;

    try {
      // Save item
      await FirebaseFirestore.instance
          .collection("store")
          .doc(itemId)
          .set(item);

      // Only add category if it is custom ("More" case) and not already one of the standard ones
      if (_showOtherCategoryField && customCategory != "Uncategorized") {
        final generalRef = FirebaseFirestore.instance
            .collection("general")
            .doc("general_variables");

        final doc = await generalRef.get();
        final currentTypes = (doc.data()?["inventory_types"] as List<dynamic>?) ?? [];

        // If this exact category does not exist yet
        if (!currentTypes.map((e) => e.toString()).contains(customCategory)) {
          // Atomically add it to the array
          await generalRef.set(
            {"inventory_types": FieldValue.arrayUnion([customCategory])},
            SetOptions(merge: true),
          );
        }
      }

      // Re‑fetch inventory types so dropdown reflects new category
      await _loadInventoryTypes();

      await _clearImage();

      if (mounted) {
        setState(() => _isSubmitting = false);
        nameController.clear();
        categoryOtherController.clear();
        _showOtherCategoryField = false;
        widget.onAdd(item);
        scannedBatteryId = null;

        ToastService.success('$capitalizedName added successfully!');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ToastService.error('Failed to add item: $e');
      }
    }
  }

  Future<bool> isBikeRegistered(String bikeName) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('general')
          .doc('general_variables')
          .get();

      final bikes = (doc.data()?['bikes'] as Map<String, dynamic>?) ?? {};
      return bikes.containsKey(bikeName);
    } catch (e) {
      return false;
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
    if (_isScanning) {
      ToastService.warning("You can only scan one battery at a time.");
      return;
    }

    setState(() => _isScanning = true);

    try {
      final qrRaw = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const QrScannerPage()),
      );

      if (qrRaw == null) {
        setState(() => _isScanning = false);
        return;
      }

      final qrCode = cleanExtract(qrRaw);

      final query = await FirebaseFirestore.instance
          .collection("batteries")
          .where("qr_code", isEqualTo: qrCode)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ToastService.error("No battery found for scanned QR code.");
        ToastService.error("For batteries, the IT team needs to add it to the system first.");
        setState(() => _isScanning = false);
        return;
      }

      final doc = query.docs.first;
      final data = doc.data();
      final batteryName = data["batteryName"] ?? "Unknown Battery";

      setState(() {
        scannedBatteryId = doc.id;
        scannedBatteryName = batteryName;
        _isScanning = false;
      });

      // Auto‑fill item name if category is still Batteries
      if (_selectedCategory == "Batteries") {
        nameController.text = "$batteryName";
      }
    } catch (e) {
      ToastService.error("Scan didn't return a viable result.");
      setState(() => _isScanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(
        top: 16,
        left: 16,
        right: 16,
        bottom: 20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Heading
          Text(
            "Add new item",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "1. All items in the store must exist as single entities and not a group of similar inventory.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "2. Photo, category and name are required to add a new item to store inventory.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "3. Names for items in the Batteries category will be autofilled through a scan query to the database and not manually written.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "4. Bike names must match the database names as well.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),

          // Preview image or placeholder
          if (_isImageReady && imageFile != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Card(
                elevation: 3,
                surfaceTintColor: colors.surface,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Image.file(
                          imageFile!,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                        ),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: _clearImage,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: colors.error,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 4,
                                    color: colors.shadow.withOpacity(0.3),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.close,
                                color: colors.onError,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 16,
                  color: colors.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'Image ready to upload',
                  style: TextStyle(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ] else ...[
            Center( // ✅ Center the camera placeholder
              child: Card(
                color: colors.surfaceContainer,
                surfaceTintColor: colors.surfaceContainer,
                elevation: 1,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        size: 64,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Tap the camera above to take an item photo',
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),

          // Take Picture button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton.icon(
              onPressed: takePicture,
              icon: const Icon(Icons.camera_alt, size: 18),
              label: const Text('Take Item Photo'),
              style: FilledButton.styleFrom(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

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
                setState(() {
                  final wasBatteryBefore = _selectedCategory == "Batteries";

                  _selectedCategory = value;
                  _showOtherCategoryField = value == "Other";

                  if (value == "Batteries") {
                    // Force: Batteries → no user‑written name; field is controlled by DB only
                    nameController.clear();

                    scanBattery().then((_) {
                      if (_isScanning || scannedBatteryName == null) return;
                      // Auto‑fill item name with batteryName
                      nameController.text = scannedBatteryName!;
                    });
                  } else if (wasBatteryBefore) {
                    // When leaving Batteries, re‑enable manual editing
                    // (user can keep or edit the name)
                    scannedBatteryId = null;
                    scannedBatteryName = null;
                    nameController.clear();
                  }
                });
              },
            ),
            const SizedBox(height: 12),

          // "Other" custom category text field
          if (_showOtherCategoryField)
            TextField(
              controller: categoryOtherController,
              decoration: InputDecoration(
                labelText: 'Custom Category',
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
              ),
            ),
            const SizedBox(height: 20),

          // Scan battery label
          Text(
            "Scan battery",
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),

          // Scan button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _selectedCategory != "Batteries" || scanning || scannedBatteryId != null
                  ? null // disabled if not Batteries, already scanning, or already scanned
                  : scanBattery,
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Item name
          TextField(
            controller: nameController,
            enabled: _selectedCategory != "Batteries" && !_isScanning,
            decoration: InputDecoration(
              labelText: 'Item Name',
              helperText: _selectedCategory == "Batteries" && scannedBatteryName != null
                  ? "Auto‑filled from battery"
                  : null,
              labelStyle: const TextStyle(),
              floatingLabelStyle: TextStyle(
                color: colors.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.outline),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: colors.primary, width: 2),
              ),
              prefixIcon: const Icon(
                Icons.inventory_2,
                size: 20,
              ),
              suffixText: _isSubmitReady ? 'Ready!' : null,
              suffixStyle: TextStyle(color: colors.primary),
              filled: true,
              fillColor: colors.surfaceContainer,
            ),
          ),
          const SizedBox(height: 20),
                    
          // Add button (with confirmation dialog)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isSubmitReady
                  ? () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                            'Confirm item addition',
                            style: theme.textTheme.titleMedium,
                          ),
                          content: Text(
                            'Are you sure you want to add "${nameController.text.trim()}"?',
                            style: theme.textTheme.bodyMedium,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.of(ctx).pop();
                                _showLoadingDialog(addItem());
                              },
                              child: const Text('Add Item'),
                            ),
                          ],
                        ),
                      );
                    }
                  : null, // ← disabled when not valid
              style: FilledButton.styleFrom(
                elevation: 3,
                backgroundColor: _isSubmitReady ? colors.primary : colors.surfaceContainer,
                foregroundColor: _isSubmitReady ? colors.onPrimary : colors.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSubmitting
                  ? SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.onPrimary),
                      ),
                    )
                  : Text(
                      _isSubmitReady ? 'Add Item' : 'Add item (name + photo + category required)',
                      style: TextStyle(
                        color: _isSubmitReady
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
                  
        
        ],
      ),
    );
  }
}
// ========================= create_and_manage_store.dart =========================

import 'package:billkmotolinkltd/store/add_section.dart';
import 'package:billkmotolinkltd/store/assign_section.dart';
import 'package:billkmotolinkltd/store/disburse_section.dart';
import 'package:billkmotolinkltd/store/store_section.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CreateAndManageStore extends StatefulWidget {
  const CreateAndManageStore({super.key});

  @override
  State<CreateAndManageStore> createState() => _CreateAndManageStoreState();
}

class _CreateAndManageStoreState extends State<CreateAndManageStore> {
  int activeTab = 0;
  PageController? _pageController;
  final String? currentUserUid = FirebaseAuth.instance.currentUser?.uid;

  static const String _tabKey = 'active_tab';
  final Map<String, Map<String, dynamic>> store = {};

  @override
  void initState() {
    super.initState();
    _loadActiveTab().then((_) {
      _pageController = PageController(initialPage: activeTab);
    });
  }

  Future<void> _loadActiveTab() async {
    final prefs = await SharedPreferences.getInstance();
    // final savedTab = prefs.getInt(_tabKey) ?? 1; // <-- 1 because Add is now index 0, we want Add as default

    if (mounted) {
      setState(() {
        // activeTab = savedTab;
      });
      await prefs.remove(_tabKey);
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void addItem(Map<String, dynamic> item) {
    setState(() {
      store[item["id"] as String] = item;
    });
  }

  void disburseItem(String id, int qty) {
    if (!store.containsKey(id)) return;

    final item = store[id]!;
    final currentQty = item["quantity"] ?? 0;
    if (currentQty < qty) return;

    setState(() {
      item["quantity"] = currentQty - qty;

      final transactions = item["transactions"] as List;
      transactions.add({
        "type": "OUT",
        "quantity": qty,
        "date": DateTime.now(),
      });
    });
  }

  void _showItemDetails(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item["name"] ?? ""),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("ID: ${item["id"] ?? ""}"),
            Text("Quantity: ${item["quantity"] ?? 0}"),
            Text("Transactions: ${item["transactions"].length}"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }

  // Tab order: Add → Store → Rid → Assign
  List<Widget> get pages => [
        AddSection(onAdd: addItem),
        if (currentUserUid != null)
          StoreSection(currentUserUid: currentUserUid!)
        else
          const SizedBox(),
        DisburseSection(onTap: (context, item) {
          _showItemDetails(context, item);
        }),
        const AssignSection(),
      ];

  Widget _tabButton(String label, IconData icon, int index) {
    final isActive = activeTab == index;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => activeTab = index);
          _pageController?.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isActive
                ? colors.primary.withValues(alpha: 0.15)
                : colors.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive
                  ? colors.primary.withValues(alpha: 0.6)
                  : colors.surfaceContainer,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: isActive ? colors.primary : colors.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium!.copyWith(
                  color: isActive ? colors.primary : colors.onSurfaceVariant,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top tab bar (Add → Store → Rid → Assign)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                _tabButton("Add", Icons.add, 0),
                const SizedBox(width: 10),
                _tabButton("Store", Icons.warehouse_rounded, 1),
                const SizedBox(width: 10),
                _tabButton("Rid", Icons.delete_outline, 2),
                const SizedBox(width: 10),
                _tabButton("Assign", Icons.person_add, 3),
              ],
            ),
          ),

          // Space divider
          const SizedBox(height: 1),

          Divider(
            color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.15),
            height: 1,
          ),

          // Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() => activeTab = index);
              },
              children: pages,
            ),
          ),
        ],
      ),
    );
  }
}
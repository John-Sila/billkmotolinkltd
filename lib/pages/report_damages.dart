import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ReportDamages extends StatefulWidget {
  const ReportDamages({super.key, required this.uid});

  final String uid;

  @override
  State<ReportDamages> createState() => _ReportDamagesState();
}

class _ReportDamagesState extends State<ReportDamages> {
  final TextEditingController _newDamageController = TextEditingController();
  final List<String> _damages = [];

  bool _loading = true;
  bool _submitting = false;
  bool _isClockedIn = false;

  String? _currentBike;
  String? _userName;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _newDamageController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
      final data = doc.data();
      final bike = data?['currentBike'];

      setState(() {
        _isClockedIn = (data?['isClockedIn'] ?? false) == true;
        _currentBike = _isClockedIn && bike != null ? bike.toString() : null;
        _userName = data?['userName']?.toString();
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _isClockedIn = false;
        _loading = false;
      });
    }
  }

  void _addDamage() {
    final text = _newDamageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _damages.add(text);
      _newDamageController.clear();
    });
  }

  void _removeDamage(int index) {
    setState(() {
      _damages.removeAt(index);
    });
  }

  String capitalizeFirstLetter(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  Future<void> _submitDamages() async {
    if (!_isClockedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clock in first before submitting damages.')),
      );
      return;
    }

    if (_currentBike == null || _currentBike!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Current bike not found.')),
      );
      return;
    }

    if (_damages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one damage.')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();

      // 🔴 Ensure parent bike document exists
      final bikeDocRef = firestore
          .collection('damagesReports')
          .doc(_currentBike);

      batch.set(
        bikeDocRef,
        {
          'bikeId': _currentBike,
          'lastUpdated': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      // Subcollection reference
      final itemsRef = bikeDocRef.collection('items');

      for (final damage in _damages) {
        final cleanDamage = capitalizeFirstLetter(damage);

        final docRef = itemsRef.doc();

        batch.set(docRef, {
          'timestamp': FieldValue.serverTimestamp(),
          'createdAt': DateTime.now(), // local fallback
          'message': cleanDamage,
          'postedBy': _userName ?? 'Unknown',
          'resolved': false,
          'confirmed': false,
          'declined': false ,
          'canDelete': false,
          'bike': _currentBike,
        });
      }

      await batch.commit();

      if (!mounted) return;

      setState(() {
        _damages.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Damage report submitted.')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
    
  
  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildHeroCard(cs),
              const SizedBox(height: 16),
              _buildStatusCard(cs, isDark),
              const SizedBox(height: 16),
              _buildInputCard(cs),
              const SizedBox(height: 16),
              _buildDamagesCard(cs),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: (_isClockedIn && _damages.isNotEmpty && !_submitting)
                      ? _submitDamages
                      : null,
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded),
                  label: Text(_submitting ? 'Submitting...' : 'Submit Damages'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cs.primary,
                    foregroundColor: cs.onPrimary,
                    disabledBackgroundColor: cs.surfaceContainerHighest,
                    disabledForegroundColor: cs.outline,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard(ColorScheme cs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.build_circle_rounded, color: cs.primary),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Damage Wall',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 4),
                Text(
                  'Log issues for the active bike in a clean, trackable way. \nPost every issue independently.',
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(ColorScheme cs, bool isDark) {
    final inColor = Colors.green;
    final outColor = Colors.orange;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (_isClockedIn ? inColor : outColor).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isClockedIn ? Icons.verified_rounded : Icons.lock_outline_rounded,
              color: _isClockedIn ? inColor : outColor,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isClockedIn ? 'Clocked In' : 'Not Clocked In',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _isClockedIn ? inColor : outColor,
                  ),
                ),
                const SizedBox(height: 4),
                _isClockedIn
                  ? RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                        ),
                        children: [
                          const TextSpan(text: 'Current Bike: '),
                          TextSpan(
                            text: _currentBike ?? 'Unavailable',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Text(
                      'You can only submit once you are clocked in.',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Add Damage',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _newDamageController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Describe the issue...',
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.35),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.primary, width: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _addDamage,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Damage'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDamagesCard(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Damage Queue (${_damages.length})',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (_damages.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'No damages added yet.',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
            )
          else
            ..._damages.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: cs.primary.withValues(alpha: 0.14),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: cs.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => _removeDamage(index),
                    icon: const Icon(Icons.close_rounded),
                    color: cs.error,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
                        
            
            }),
        
        
        
        ],
      ),
    );
  }
}
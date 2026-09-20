import 'package:billkmotolinkltd/services/toast_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Bike <-> Rider assignment screen.
///
/// Visible to IT, Manager (Admin) and CEO. Riders sit on the left, bikes on
/// the right. Tapping a rider collapses the rest of the list and pops that
/// rider's card front and center; tapping the same rider again reverses the
/// animation and brings everyone back. The bike pane behaves the same way.
/// Once one of each is selected, an "Assign" button appears.
///
/// SHIFTS: every bike has two independent slots, so one bike can serve two
/// riders (one per shift). The shift bar at the top decides which slot the
/// next assignment goes into.
///
///   general/general_variables
///     bikes.<bike>.day   = { assignedRider, isAssigned }
///     bikes.<bike>.night = { assignedRider, isAssigned }
///
/// A rider holds exactly one (bike, shift) pair, stored on the user doc as
/// `assignedBikeName` + `assignedShift` ('day' | 'night').
class Assignments extends StatefulWidget {
  const Assignments({super.key});

  @override
  State<Assignments> createState() => _AssignmentsState();
}

const List<String> _kShifts = ['day', 'night'];

String _shiftLabel(String shift) => shift == 'night' ? 'Night' : 'Day';

IconData _shiftIcon(String shift) =>
    shift == 'night' ? Icons.nightlight_round : Icons.wb_sunny_rounded;

Color _shiftColor(String shift) =>
    shift == 'night' ? const Color(0xFF5C6BC0) : const Color(0xFFF9A825);

/// Returns 'day' / 'night', or null for anything else (missing, "None", etc.).
String? _cleanShift(dynamic value) {
  final s = value?.toString().trim().toLowerCase();
  return (s == 'day' || s == 'night') ? s : null;
}

class _Rider {
  final String uid;
  final String name;
  final String? assignedBikeName;
  final String? assignedShift; // 'day' | 'night' | null

  _Rider({
    required this.uid,
    required this.name,
    this.assignedBikeName,
    this.assignedShift,
  });
}

class _AssignmentsState extends State<Assignments> {
  bool _loading = true;
  bool _assigning = false;

  List<_Rider> _riders = [];
  List<String> _bikeNames = [];
  Map<String, dynamic> _bikesData = {};

  String? _selectedRiderUid;
  String? _selectedBikeName;

  /// Which shift slot the next assignment will go into.
  String _shift = 'day';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final fs = FirebaseFirestore.instance;

      final ridersSnap =
          await fs.collection('users').where('userRank', isEqualTo: 'Rider').get();

      final riders = ridersSnap.docs.map((d) {
        final data = d.data();
        final bikeRaw = data['assignedBikeName']?.toString().trim();
        return _Rider(
          uid: d.id,
          name: (data['userName'] ?? 'Unnamed').toString(),
          assignedBikeName: (bikeRaw == null || bikeRaw.isEmpty) ? null : bikeRaw,
          assignedShift: _cleanShift(data['assignedShift']),
        );
      }).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      final generalDoc =
          await fs.collection('general').doc('general_variables').get();
      final bikes = Map<String, dynamic>.from(generalDoc.data()?['bikes'] ?? {});
      final bikeNames = bikes.keys.toList()..sort();

      if (!mounted) return;
      setState(() {
        _riders = riders;
        _bikesData = bikes;
        _bikeNames = bikeNames;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ToastService.error("Failed to load assignment data: $e");
    }
  }

  /// Name of the rider holding [bikeName]'s [shift] slot, or null if it's free.
  String? _slotRiderName(String bikeName, String shift) {
    final bike = _bikesData[bikeName];
    if (bike is! Map) return null;
    final slot = bike[shift];
    if (slot is! Map) return null;
    final rider = slot['assignedRider']?.toString();
    if (rider == null || rider.isEmpty || rider == 'None') return null;
    return rider;
  }

  void _tapRider(String uid) {
    setState(() {
      _selectedRiderUid = _selectedRiderUid == uid ? null : uid;
    });
  }

  void _tapBike(String name) {
    setState(() {
      _selectedBikeName = _selectedBikeName == name ? null : name;
    });
  }

  Future<void> _assign() async {
    if (_selectedRiderUid == null || _selectedBikeName == null || _assigning) return;

    final rider = _riders.firstWhere((r) => r.uid == _selectedRiderUid);
    final bikeName = _selectedBikeName!;
    final shift = _shift;

    // Who would lose this bike + shift? Riders whose own doc points at it, plus
    // whoever the bike's slot names (covers a slot that's out of sync with the
    // user docs).
    final displaced = <String>{
      for (final r in _riders)
        if (r.uid != rider.uid &&
            r.assignedBikeName == bikeName &&
            r.assignedShift == shift)
          r.name,
    };
    final slotHolder = _slotRiderName(bikeName, shift);
    if (slotHolder != null && slotHolder != rider.name) displaced.add(slotHolder);

    // Only ask if someone else already holds this exact bike + shift.
    // Otherwise carry straight on.
    if (displaced.isNotEmpty) {
      final confirmed = await _confirmOverwrite(
        incomingName: rider.name,
        outgoingNames: displaced.join(', '),
        bikeName: bikeName,
        shift: shift,
      );
      if (!confirmed || !mounted) return;
    }

    setState(() => _assigning = true);

    try {
      final fs = FirebaseFirestore.instance;
      final batch = fs.batch();

      // 1. Whoever currently holds this bike + shift loses it. (The other
      //    shift on the same bike is untouched — that's the whole point.)
      for (final r in _riders) {
        if (r.uid == rider.uid) continue;
        if (r.assignedBikeName == bikeName && r.assignedShift == shift) {
          batch.update(fs.collection('users').doc(r.uid), {
            'assignedBikeName': FieldValue.delete(),
            'assignedShift': FieldValue.delete(),
          });
        }
      }

      // 2. The rider gets the new bike + shift.
      batch.update(fs.collection('users').doc(rider.uid), {
        'assignedBikeName': bikeName,
        'assignedShift': shift,
      });

      // 3. Bike slots. Field-level updates (not a rewrite of the whole `bikes`
      //    map) so we never clobber another bike, or the other shift.
      final bikeUpdates = <String, dynamic>{};

      // A rider only holds one slot, so free any slot they held before.
      for (final name in _bikeNames) {
        for (final s in _kShifts) {
          if (name == bikeName && s == shift) continue;
          if (_slotRiderName(name, s) == rider.name) {
            bikeUpdates['bikes.$name.$s.assignedRider'] = 'None';
            bikeUpdates['bikes.$name.$s.isAssigned'] = false;
          }
        }
      }

      bikeUpdates['bikes.$bikeName.$shift.assignedRider'] = rider.name;
      bikeUpdates['bikes.$bikeName.$shift.isAssigned'] = true;

      batch.update(
        fs.collection('general').doc('general_variables'),
        bikeUpdates,
      );

      await batch.commit();

      if (!mounted) return;
      ToastService.success(
          "${rider.name} assigned to $bikeName (${_shiftLabel(shift)} shift)"
          "${displaced.isEmpty ? '' : ', replacing ${displaced.join(', ')}'}");

      setState(() {
        _selectedRiderUid = null;
        _selectedBikeName = null;
        _assigning = false;
      });

      _loadData();
    } catch (e) {
      if (!mounted) return;
      setState(() => _assigning = false);
      ToastService.error("Assignment failed: $e");
    }
  }

  /// Small "Overwrite?" prompt, shown only when the chosen bike + shift is
  /// already taken by someone else. Returns true only if the admin taps Overwrite.
  Future<bool> _confirmOverwrite({
    required String incomingName,
    required String outgoingNames,
    required String bikeName,
    required String shift,
  }) async {
    final theme = Theme.of(context);
    const bold = TextStyle(fontWeight: FontWeight.w700);

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(_shiftIcon(shift), color: _shiftColor(shift), size: 36),
        title: Text(
          'Overwrite assignment?',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        content: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: outgoingNames, style: bold),
              const TextSpan(text: ' already has '),
              TextSpan(text: bikeName, style: bold),
              TextSpan(text: ' on the ${_shiftLabel(shift)} shift.\nOverwrite with '),
              TextSpan(text: incomingName, style: bold),
              const TextSpan(text: '?'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF57C00),
              foregroundColor: Colors.white,
            ),
            child: const Text('Overwrite'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bothSelected = _selectedRiderUid != null && _selectedBikeName != null;

    return Scaffold(
      // appBar: AppBar(title: const Text('Assignments')),
      body: SafeArea(
        top: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                    child: Row(
                      children: [
                        Icon(Icons.assignment_ind_rounded,
                            color: theme.colorScheme.primary, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assign Bikes to Riders',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              Text(
                                'Pick a shift, tap a rider, then tap a bike',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildShiftBar(theme),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: _buildRiderPane(theme)),
                        Container(width: 1, color: theme.colorScheme.outlineVariant),
                        Expanded(child: _buildBikePane(theme)),
                      ],
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    child: bothSelected
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _assigning ? null : _assign,
                                icon: _assigning
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_outline),
                                label: Text(_assigning
                                    ? 'Assigning...'
                                    : 'Assign to ${_shiftLabel(_shift)} shift'),
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : const SizedBox(width: double.infinity, height: 0),
                  ),
                ],
              ),
      ),
    );
  }

  // ---------- SHIFT BAR ----------

  Widget _buildShiftBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          showSelectedIcon: false,
          segments: [
            for (final s in _kShifts)
              ButtonSegment<String>(
                value: s,
                icon: Icon(_shiftIcon(s), size: 18),
                label: Text('${_shiftLabel(s)} shift'),
              ),
          ],
          selected: {_shift},
          onSelectionChanged: _assigning
              ? null
              : (selection) => setState(() => _shift = selection.first),
          style: SegmentedButton.styleFrom(
            selectedBackgroundColor: _shiftColor(_shift),
            selectedForegroundColor: Colors.white,
          ),
        ),
      ),
    );
  }

  // ---------- RIDER PANE ----------

  Widget _buildRiderPane(ThemeData theme) {
    if (_riders.isEmpty) {
      return _emptyState(theme, "No riders found");
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: _selectedRiderUid == null
          ? ListView.builder(
              key: const ValueKey('riders-list'),
              padding: const EdgeInsets.fromLTRB(10, 4, 6, 12),
              itemCount: _riders.length,
              itemBuilder: (context, i) => _riderTile(theme, _riders[i]),
            )
          : Padding(
              key: ValueKey('rider-selected-$_selectedRiderUid'),
              padding: const EdgeInsets.all(14),
              child: _riderTile(
                theme,
                _riders.firstWhere((r) => r.uid == _selectedRiderUid),
                expanded: true,
              ),
            ),
    );
  }

  String _riderSubtitle(_Rider rider) {
    if (rider.assignedBikeName == null) return 'No bike assigned';
    final shift = rider.assignedShift;
    final shiftText = shift == null ? 'shift not set' : '${_shiftLabel(shift)} shift';
    return 'Rides: ${rider.assignedBikeName} • $shiftText';
  }

  Widget _riderTile(ThemeData theme, _Rider rider, {bool expanded = false}) {
    final selected = _selectedRiderUid == rider.uid;

    return GestureDetector(
      onTap: () => _tapRider(rider.uid),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.symmetric(vertical: expanded ? 0 : 6, horizontal: 2),
        padding: EdgeInsets.all(expanded ? 22 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(expanded ? 24 : 16),
          gradient: selected
              ? LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.primary.withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: expanded
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: expanded ? 34 : 18,
              backgroundColor: selected
                  ? Colors.white.withValues(alpha: 0.25)
                  : theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(
                Icons.person_rounded,
                color: selected ? Colors.white : theme.colorScheme.primary,
                size: expanded ? 34 : 20,
              ),
            ),
            SizedBox(height: expanded ? 14 : 8),
            Text(
              rider.name,
              textAlign: expanded ? TextAlign.center : TextAlign.start,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (expanded ? theme.textTheme.titleLarge : theme.textTheme.bodyMedium)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: expanded ? 10 : 2),
            Text(
              _riderSubtitle(rider),
              textAlign: expanded ? TextAlign.center : TextAlign.start,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected
                    ? Colors.white.withValues(alpha: 0.85)
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (expanded) ...[
              const SizedBox(height: 16),
              Icon(Icons.touch_app_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 18),
              const SizedBox(height: 4),
              Text(
                'Tap to deselect',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- BIKE PANE ----------

  Widget _buildBikePane(ThemeData theme) {
    if (_bikeNames.isEmpty) {
      return _emptyState(theme, "No bikes found");
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: anim, child: child),
      ),
      child: _selectedBikeName == null
          ? ListView.builder(
              key: const ValueKey('bikes-list'),
              padding: const EdgeInsets.fromLTRB(6, 4, 10, 12),
              itemCount: _bikeNames.length,
              itemBuilder: (context, i) => _bikeTile(theme, _bikeNames[i]),
            )
          : Padding(
              key: ValueKey('bike-selected-$_selectedBikeName'),
              padding: const EdgeInsets.all(14),
              child: _bikeTile(theme, _selectedBikeName!, expanded: true),
            ),
    );
  }

  /// One line showing who holds a bike's day / night slot.
  Widget _bikeShiftLine(
    ThemeData theme,
    String bikeName,
    String shift, {
    required bool tileSelected,
  }) {
    final rider = _slotRiderName(bikeName, shift);
    // The slot the shift bar is currently pointing at reads a touch bolder.
    final isTarget = shift == _shift;

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _shiftIcon(shift),
            size: 13,
            color: tileSelected
                ? Colors.white.withValues(alpha: 0.9)
                : _shiftColor(shift),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '${_shiftLabel(shift)}: ${rider ?? 'Unassigned'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: tileSelected
                    ? Colors.white.withValues(alpha: isTarget ? 1.0 : 0.8)
                    : (rider == null
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface),
                fontWeight: isTarget ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bikeTile(ThemeData theme, String bikeName, {bool expanded = false}) {
    final selected = _selectedBikeName == bikeName;

    return GestureDetector(
      onTap: () => _tapBike(bikeName),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: EdgeInsets.symmetric(vertical: expanded ? 0 : 6, horizontal: 2),
        padding: EdgeInsets.all(expanded ? 22 : 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(expanded ? 24 : 16),
          gradient: selected
              ? const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF00C6A2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          border: Border.all(
            color: selected ? const Color(0xFF00796B) : theme.colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: const Color(0xFF00796B).withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              expanded ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: expanded ? 34 : 18,
              backgroundColor: selected
                  ? Colors.white.withValues(alpha: 0.25)
                  : theme.colorScheme.primary.withValues(alpha: 0.15),
              child: Icon(
                Icons.electric_bike_rounded,
                color: selected ? Colors.white : theme.colorScheme.primary,
                size: expanded ? 34 : 20,
              ),
            ),
            SizedBox(height: expanded ? 14 : 8),
            Text(
              bikeName,
              textAlign: expanded ? TextAlign.center : TextAlign.start,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: (expanded ? theme.textTheme.titleLarge : theme.textTheme.bodyMedium)
                  ?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: expanded ? 10 : 2),
            // Both shifts, always — so you can see at a glance which slots are free.
            for (final s in _kShifts)
              _bikeShiftLine(theme, bikeName, s, tileSelected: selected),
            if (expanded) ...[
              const SizedBox(height: 16),
              Icon(Icons.touch_app_rounded,
                  color: Colors.white.withValues(alpha: 0.7), size: 18),
              const SizedBox(height: 4),
              Text(
                'Tap to deselect',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeData theme, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
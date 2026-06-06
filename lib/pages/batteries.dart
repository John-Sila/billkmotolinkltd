import 'package:billkmotolinkltd/utils/utility_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

class Batteries extends StatefulWidget {
  final String uid;

  const Batteries({super.key, required this.uid});

  @override
  State<Batteries> createState() => _BatteriesState();
}

class _BatteriesState extends State<Batteries> {
  String? currentUserName;
  Map<String, dynamic> batteries = {};
  final expanded = <String>{};
  bool isLoading = true;
  Set<String> busy = {};


  @override
  void initState() {
    super.initState();
    _loadData();
    // deleteOldTracesForAllBatteries();
  }

  Future<void> _loadData() async {
    await _fetchUserName();
    await _fetchBatteries();
  }

  Future<void> _fetchUserName() async {
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    setState(() {
      currentUserName = snap.data()?['userName'] ?? '';
    });
  }

  Future<void> deleteOldTracesForAllBatteries({
    Duration maxAge = const Duration(days: 7),
  }) async {
    final firestore = FirebaseFirestore.instance;
    final batteriesSnapshot = await firestore.collection('batteries').get();

    for (final doc in batteriesSnapshot.docs) {
      await deleteOldTracesForBattery(
        batteryId: doc.id,
        maxAge: maxAge,
      );
    }
  }

  Future<void> deleteOldTracesForBattery({
    required String batteryId,
    Duration maxAge = const Duration(days: 7),
  }) async {
    final firestore = FirebaseFirestore.instance;
    final docRef = firestore.collection('batteries').doc(batteryId);

    try {
      final snapshot = await docRef.get();
      if (!snapshot.exists) return;

      final data = snapshot.data();
      if (data == null) return;

      final traces = data['traces'] as Map<String, dynamic>?;

      if (traces == null || traces.isEmpty) return;

      final now = DateTime.now();
      final cutoff = now.subtract(maxAge);

      final Map<String, dynamic> updates = {};

      traces.forEach((traceKey, traceValue) {
        if (traceValue is Map<String, dynamic>) {
          final Timestamp? ts = traceValue['dateEdited'] as Timestamp?;
          if (ts != null) {
            final dateEdited = ts.toDate();
            if (dateEdited.isBefore(cutoff)) {
              // mark this trace for deletion
              updates['traces.$traceKey'] = FieldValue.delete();
            }
          }
        }
      });

      if (updates.isNotEmpty) {
        await docRef.update(updates);
      }
    } catch (e) {
      // handle/log error as needed
    }
  }

  Future<void> _fetchBatteries() async {
    setState(() => isLoading = true);

    final snap = await FirebaseFirestore.instance.collection('batteries').get();
    final now = DateTime.now();
    final batch = FirebaseFirestore.instance.batch();

    final sortedEntries = snap.docs.toList()
      ..sort((a, b) {
        final aNum = int.tryParse(a['batteryName']?.split('-').last ?? '0') ?? 0;
        final bNum = int.tryParse(b['batteryName']?.split('-').last ?? '0') ?? 0;
        return aNum.compareTo(bNum);
      });

    final Map<String, dynamic> tempBatteries = {};

    for (var doc in sortedEntries) {
      final data = doc.data();
      tempBatteries[doc.id] = data;

      final isBooked = data['isBooked'] ?? false;
      final bookTime = data['bookTime'];

      if (isBooked && bookTime != null) {
        DateTime bookDateTime;
        if (bookTime is Timestamp) {
          bookDateTime = bookTime.toDate();
        } else if (bookTime is DateTime) {
          bookDateTime = bookTime;
        } else {
          continue;
        }

        if (now.difference(bookDateTime).inMinutes >= 60) {
          // mark as unbooked
          batch.update(doc.reference, {'isBooked': false});
          tempBatteries[doc.id]['isBooked'] = false;
        }
      }
    }

    await batch.commit();

    setState(() {
      batteries = tempBatteries;
      isLoading = false;
    });
  }

  String formatTimeAgo(Timestamp? ts) {
    if (ts == null) return "N/A";

    final date = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) {
      return "Just now";
    }

    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;

    final buffer = StringBuffer();

    if (hours > 0) {buffer.write("${hours}h ${minutes}m");}
    else if (minutes > 0) {buffer.write("${minutes}m");}
    else if (seconds > 0) {buffer.write("${seconds}s");}

    return "${buffer.toString().trim()} ago";
  }


  @override
  Widget build(BuildContext context) {
    if (currentUserName == null || isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (batteries.isEmpty) {
      return const Center(child: Text("No batteries available"));
    }

  final sortedBatteries = batteries.entries.toList()
    ..sort((a, b) {
      final nameA = a.value['batteryName'] ?? '';
      final nameB = b.value['batteryName'] ?? '';
      final regex = RegExp(r'\d+');
      final numA = int.tryParse(regex.firstMatch(nameA)?.group(0) ?? '0') ?? 0;
      final numB = int.tryParse(regex.firstMatch(nameB)?.group(0) ?? '0') ?? 0;
      return numA.compareTo(numB);
    });

  return ListView(
    padding: const EdgeInsets.all(16),
    children: sortedBatteries.map((entry) {
      final id = entry.key;
      final data = entry.value;

      final batteryName = data['batteryName'] ?? "Unknown";
      final assignedRider = data['assignedRider'] ?? "None";
      final isBooked = data['isBooked'] ?? false;
      final bookedBy = data['bookedBy'] ?? "";

      final Color titleColor;
      if (!isBooked) {
        if (assignedRider == currentUserName) {
          titleColor = Colors.green;
        } else if (assignedRider != 'None' && assignedRider != currentUserName) {
          titleColor = Colors.red;
        } else {
          titleColor = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.black;
        }
      } else {
        titleColor = Colors.blue;
      }

      final isOpen = expanded.contains(id);

      return Card(
        elevation: 3,
        shadowColor: Colors.black26,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                isOpen ? expanded.remove(id) : expanded.add(id);
              });
            },
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    batteryName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                    ),
                  ),
                  subtitle: Text(
                    isBooked
                        ? "Booked by ${bookedBy == currentUserName ? "me" : bookedBy}"
                        : assignedRider == "None" ? "Available" : "Assigned to $assignedRider",
                  ),

                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // LOADER (shown when this battery is performing an action)
                      if (busy.contains(id))
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),

                      // book
                      if (!busy.contains(id) && !isBooked && assignedRider == "None")
                        IconButton(
                          icon: const Icon(Icons.add_box, color: Colors.teal),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Confirm Booking"),
                                content: Text("Do you want to book $batteryName? This will freeze it for 1 hour."),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("Confirm"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm ?? false) {
                              setState(() => busy.add(id)); // activate loader

                              final now = Timestamp.now();
                              await FirebaseFirestore.instance
                                  .collection('batteries')
                                  .doc(id)
                                  .update({
                                'isBooked': true,
                                'bookedBy': currentUserName,
                                'bookTime': now,
                              });

                              setState(() {
                                batteries[id]?['isBooked'] = true;
                                batteries[id]?['bookedBy'] = currentUserName;
                                batteries[id]?['bookTime'] = now;
                                busy.remove(id);                 // deactivate loader
                              });

                              Fluttertoast.showToast(msg: "$batteryName successfully booked.");
                            }
                          },
                        ),

                      // Unbook
                      if (!busy.contains(id) && isBooked && bookedBy == currentUserName)
                        IconButton(
                          icon: const Icon(Icons.cancel_rounded, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text("Confirm Drop"),
                                content: Text("Do you want to unbook $batteryName?"),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text("Cancel"),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text("Confirm"),
                                  ),
                                ],
                              ),
                            );

                            if (confirm ?? false) {
                              setState(() => busy.add(id)); // show loader

                              final now = Timestamp.now();
                              await FirebaseFirestore.instance
                                  .collection('batteries')
                                  .doc(id)
                                  .update({
                                'isBooked': false,
                                'bookedBy': "None",
                                'bookTime': now,
                              });

                              setState(() {
                                batteries[id]?['isBooked'] = false;
                                batteries[id]?['bookedBy'] = "None";
                                batteries[id]?['bookTime'] = now;
                                busy.remove(id); // remove loader
                              });

                              Fluttertoast.showToast(msg: "$batteryName successfully dropped.");
                              _fetchBatteries();
                            }
                          },
                        ),

                      
                      // EXPAND/COLLAPSE ICON
                      if (!busy.contains(id))
                        Icon(isOpen ? Icons.expand_less : Icons.expand_more),
                    ],
                  )






                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _info(const Icon(Icons.location_on, size: 16, color: Colors.teal), data['batteryLocation']),
                        _info(const Icon(Icons.pedal_bike_sharp, size: 16, color: Colors.teal), data['assignedBike']),
                        _info(
                          const Icon(Icons.qr_code, size: 16, color: Colors.teal),
                          (data['qr_code']?.toString().substring(
                                data['qr_code'].toString().length - 5,
                              )) ?? "N/A",
                        ),

                        _info(const Icon(Icons.timer_rounded, size: 16, color: Colors.teal), formatTimeAgo(data['offTime'])),
                      ],
                    ),
                  ),
                  crossFadeState: isOpen
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 250),
                ),
              ],
            ),
          ),
        ),
      );
    
    
    
    
    
    }).toList(), // <--- ensures type is List<Widget>
  );

    
  
  
  
  
  
  }

  Widget _info(Widget labelWidget, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          labelWidget,
          const SizedBox(width: 6),
          Text("${value ?? 'N/A'}"),
        ],
      ),
    );
  }

}

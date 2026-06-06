### 1. activity_scheduler.dart
# Event Scheduling Utils
**File:** `lib/utils/event_scheduler.dart`

## 🔧 Dependencies
```yaml
cloud_firestore: ^5.0.1
intl: ^0.19.0
```

## 📊 Required State
```dart
TextEditingController _titleController, _descriptionController;
DateTime? _selectedDate;
TimeOfDay? _selectedTime;
bool _isSubmitting = false;
```

## 🎯 Functions

### `_pickDate()` 
**Shows** custom calendar modal → **Sets** `_selectedDate`

### `_pickTime()` 
**Shows** analog-only time picker → **Sets** `_selectedTime`

### `_submit()` 
**Validates** → **Confirms** → **Creates** event → **Notifies all users** → **Resets form**

**Firestore writes:**


# Company Event Utils
**File:** `lib/utils/company_events.dart`

## 🔧 Dependencies
```yaml
cloud_firestore: ^5.0.1
firebase_auth: ^5.1.1
add_2_calendar: ^2.2.5
fluttertoast: ^8.2.4
```

## 📊 Required State
```dart
final _formKey = GlobalKey<FormState>();
TextEditingController _titleController, _locationController, _descriptionController;
DateTime? _selectedDate;
TimeOfDay? _startTime, _endTime;
```

## 🎯 Functions

### `_selectDate()` 
**Picks** future date (today → +365d) → **Sets** `_selectedDate`

### `_selectStartTime()` 
**Picks** current time → **Sets** `_startTime`

### `_selectEndTime()` 
**Picks** current+1h → **Sets** `_endTime`

### `_addToCalendar()` 
**Validates** form/time logic → **Creates** Firestore event → **Adds** to device calendar

**Firestore:** `companyEvents/{id}`

# Notification Utils
**File:** `lib/utils/notifications.dart`

## 🔧 Dependencies
```yaml
cloud_firestore: ^5.0.1
intl: ^0.19.0
```

## 📊 Required Model
```dart
class AppNotificationModel {
  final String id, message;
  final DateTime time;
  final bool isRead;
  AppNotificationModel({required this.id, required this.message, required this.time, required this.isRead});
}
```

## 📊 Extension (for formatting)
```dart
extension DateTimeExtension on DateTime {
  bool get isToday => ...; // isSameDate(now)
  bool get isYesterday => ...; // isSameDate(now.subtract(Duration(days:1)))
}
```

## 🎯 Functions

### `resetNotificationCounter(uid)`
**Sets** `users/{uid}/numberOfNotifications` → `0`

### `fetchNotifications(uid)` 
**Returns** sorted `List<AppNotificationModel>` from `users/{uid}/notifications`

**Parses:** `id`, `message`, `time`(Timestamp), `isRead`

### `formatTimestamp(dt)`
**Formats** DateTime → human readable:
- `HH:mm` (today)
- `Yesterday HH:mm`
- `MMM d, yyyy at HH:mm`

### `markAllAsRead(uid, list)`
**Batch updates** all notifications → `isRead: true`

## 🚀 Usage
```dart
resetNotificationCounter(uid);
final notifs = await fetchNotifications(uid);
final formatted = formatTimestamp(DateTime.now());
await markAllAsRead(uid, notifs);
```

**Firestore Path:** `users/{uid}/notifications/{id}`

---
*Condensed: April 09, 2026*


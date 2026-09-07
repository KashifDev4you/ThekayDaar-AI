import 'package:cloud_firestore/cloud_firestore.dart';

// UPWORK-STYLE RELATIVE TIMESTAMP HELPER
// =============================================================================
// Usage: wherever you show a posted project's date, replace the raw
// date text with:
//
//   Text(timeAgo(d['createdAt']))
//
// where d['createdAt'] is the Firestore Timestamp field you already
// save when the project is posted (FieldValue.serverTimestamp()).
//
// Handles: Timestamp, DateTime, or null (falls back to '').
// =============================================================================
String timeAgo(dynamic value) {
  if (value == null) return '';

  DateTime dateTime;
  if (value is Timestamp) {
    dateTime = value.toDate();
  } else if (value is DateTime) {
    dateTime = value;
  } else {
    return '';
  }

  final diff = DateTime.now().difference(dateTime);

  if (diff.inSeconds < 60) {
    return 'Just now';
  } else if (diff.inMinutes < 60) {
    final m = diff.inMinutes;
    return '$m minute${m == 1 ? '' : 's'} ago';
  } else if (diff.inHours < 24) {
    final h = diff.inHours;
    return '$h hour${h == 1 ? '' : 's'} ago';
  } else if (diff.inDays < 7) {
    final d = diff.inDays;
    return '$d day${d == 1 ? '' : 's'} ago';
  } else if (diff.inDays < 30) {
    final w = (diff.inDays / 7).floor();
    return '$w week${w == 1 ? '' : 's'} ago';
  } else if (diff.inDays < 365) {
    final mo = (diff.inDays / 30).floor();
    return '$mo month${mo == 1 ? '' : 's'} ago';
  } else {
    final y = (diff.inDays / 365).floor();
    return '$y year${y == 1 ? '' : 's'} ago';
  }
}
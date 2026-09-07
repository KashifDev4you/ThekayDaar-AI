import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

/// Keeps `thekaydaars/{uid}.lastActive` fresh while the contractor
/// app is open. Call `start()` once (e.g. in the contractor home
/// screen's initState) and `stop()` in dispose.
///
/// NOTE: writes to `thekaydaars`, NOT `users` — the `role` field
/// clients query against lives on the `thekaydaars` doc, so
/// lastActive has to live there too or the client-side query
/// (role + lastActive) will never match.
class PresenceService with WidgetsBindingObserver {
  PresenceService._();
  static final PresenceService instance = PresenceService._();

  Timer? _timer;
  bool _started = false;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);

    // Write immediately on start (covers login/app open)
    _writeLastActive();

    // Then keep pinging every 60s while app is in foreground
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      _writeLastActive();
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    _started = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Ping again whenever app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _writeLastActive();
    }
  }

  Future<void> _writeLastActive() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      // update() only touches the lastActive field — it never
      // touches fullName/nicNumber/etc, so it can't wipe other data.
      await FirebaseFirestore.instance
          .collection('thekaydaars')
          .doc(uid)
          .update({'lastActive': FieldValue.serverTimestamp()});
    } catch (e) {
      // update() fails if the doc doesn't exist yet — fall back to
      // a merge-set that ONLY writes lastActive, nothing else.
      try {
        await FirebaseFirestore.instance
            .collection('thekaydaars')
            .doc(uid)
            .set({'lastActive': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      } catch (e2) {
        debugPrint('PresenceService: failed to write lastActive: $e2');
      }
    }
  }
}
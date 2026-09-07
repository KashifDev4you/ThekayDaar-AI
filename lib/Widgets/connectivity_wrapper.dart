import 'dart:async';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:ali_app/utils/app_theme.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper> {
  bool _hasInternet = true;
  bool _isChecking = false;
  late StreamSubscription<List<ConnectivityResult>> _subscription;

  @override
  void initState() {
    super.initState();
    _checkInitial();
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) {
      final connected = results.any((r) => r != ConnectivityResult.none);
      if (mounted) {
        setState(() => _hasInternet = connected);
      }
    });
  }

  Future<void> _checkInitial() async {
    final results = await Connectivity().checkConnectivity();
    final connected = results.any((r) => r != ConnectivityResult.none);
    if (mounted) setState(() => _hasInternet = connected);
  }

  Future<void> _onRetry() async {
    setState(() => _isChecking = true);

    final results = await Connectivity().checkConnectivity();
    final connected = results.any((r) => r != ConnectivityResult.none);

    // Small delay so the spinner doesn't just flash instantly
    await Future.delayed(const Duration(milliseconds: 400));

    if (mounted) {
      setState(() {
        _hasInternet = connected;
        _isChecking = false;
      });

      if (!connected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Still no connection. Please try again.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (!_hasInternet)
          _NoInternetPage(
            isChecking: _isChecking,
            onRetry: _onRetry,
          ),
      ],
    );
  }
}

class _NoInternetPage extends StatelessWidget {
  final bool isChecking;
  final VoidCallback onRetry;

  const _NoInternetPage({
    required this.isChecking,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bg,
      child: SizedBox.expand(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wifi_off_rounded, size: 90, color: AppTheme.emerald),
                const SizedBox(height: 20),
                const Text(
                  'No Internet Connection',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textMuted),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 140,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: isChecking ? null : onRetry,
                    child: isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppTheme.emerald,
                            ),
                          )
                        : const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
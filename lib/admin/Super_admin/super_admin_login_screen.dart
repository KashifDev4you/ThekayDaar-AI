// =============================================================================
// super_admin_login_screen.dart
//
// Dedicated login screen for the ONE Super Admin (you).
// Email is hardcoded in SuperAdminConfig — if the logged-in email
// doesn't match, access is denied even if Firebase Auth succeeds.
//
// FLOW:
//   1. Super Admin enters email + password
//   2. Firebase Auth signs in
//   3. App checks if email == SuperAdminConfig.superAdminEmail
//   4. Match  → navigate to SuperAdminRequestsScreen (dashboard)
//   5. No match → sign out + show "Not authorised" error
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ali_app/utils/app_theme.dart';
import 'config.dart';
import 'Super_admin_dashboard/super_admin_requests_screen.dart';

class SuperAdminLoginScreen extends StatefulWidget {
  const SuperAdminLoginScreen({super.key});

  @override
  State<SuperAdminLoginScreen> createState() => _SuperAdminLoginScreenState();
}

class _SuperAdminLoginScreenState extends State<SuperAdminLoginScreen> {
  // ── Theme ──────────────────────────────────────────────────────
  static const Color _navy   = Color(0xFF0E3B2E);
  static const Color _amber  = Color(0xFFC9A227);
  static const Color _white  = Color(0xFFFFFFFF);
  static const Color _label  = Color(0xFF1F2A26);
  static const Color _sub    = Color(0xFF5D6B64);
  static const Color _border = Color(0xFFE3E0D5);
  static const Color _fill   = Color(0xFFF7F5EF);

  final _formKey       = GlobalKey<FormState>();
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();

  bool _isLoading     = false;
  bool _obscure       = true;
  int  _failedAttempts = 0;  // lock out after 5 wrong attempts

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Login ──────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    // Hard lockout after 5 failed attempts — prevents brute force
    if (_failedAttempts >= 5) {
      _snack('Too many failed attempts. Please try again later.',
          Colors.red.shade800);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Step 1: Firebase Auth sign-in
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email   : _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
      );

      final loggedEmail = cred.user?.email?.toLowerCase() ?? '';

      // Step 2: Verify this is the ONE Super Admin
      // Even if someone guesses the password, they must match the
      // hardcoded email in SuperAdminConfig — nothing else gets through
      if (!SuperAdminConfig.isSuperAdmin(loggedEmail)) {
        // Wrong account — sign them out immediately
        await FirebaseAuth.instance.signOut();
        _failedAttempts++;
        _snack(
          'Access denied. This portal is restricted to Super Admin only.',
          Colors.red.shade800,
        );
        return;
      }

      debugPrint('[SuperAdminLogin] ✅ Super Admin authenticated: $loggedEmail');

      if (!mounted) return;

      // Step 3: Navigate to dashboard, clearing back stack
      // Super Admin should not be able to go back to login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
            builder: (_) => SuperAdminRequestsScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _failedAttempts++;
      debugPrint('[SuperAdminLogin] Auth error: ${e.code}');
      final msg = switch (e.code) {
        'user-not-found'   => 'No account found with this email.',
        'wrong-password'   => 'Incorrect password.',
        'invalid-email'    => 'Invalid email format.',
        'user-disabled'    => 'This account has been disabled.',
        'too-many-requests'=> 'Too many attempts. Try again later.',
        _                  => 'Login failed (${e.code}).',
      };
      _snack(msg, Colors.redAccent);
    } catch (e) {
      _snack('Unexpected error: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg,
            style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
  }

  // ── Build ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Super Admin Portal',
          style: TextStyle(
              color: _white, fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Header ─────────────────────────────────────
                // Shield icon in a colored container
                Container(
                  width : 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: _navy,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.admin_panel_settings_rounded,
                      color: Color(0xFFC9A227), size: 28),
                ),
                const SizedBox(height: 20),

                const Text(
                  'Super Admin\nLogin',
                  style: TextStyle(
                    color: _label, fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5, height: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Restricted access. Only the registered Super Admin can log in here.',
                  style: TextStyle(color: _sub, fontSize: 13.5, height: 1.5),
                ),
                const SizedBox(height: 8),

                // ── Lockout warning (shows after 3 failures) ───
                if (_failedAttempts >= 3)
                  Container(
                    margin: const EdgeInsets.only(top: 8, bottom: 4),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${5 - _failedAttempts} attempt(s) remaining before lockout.',
                            style: TextStyle(
                              color: Colors.red.shade800,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 32),

                // ── Email ──────────────────────────────────────
                _fieldLabel('Email Address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller  : _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s')),
                  ],
                  style: const TextStyle(color: _label, fontSize: 14),
                  decoration: _deco('Enter your email', Icons.mail_outline_rounded),
                  validator: (v) {
                    if ((v ?? '').trim().isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(v!.trim())) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // ── Password ───────────────────────────────────
                _fieldLabel('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller : _passwordCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: _label, fontSize: 14),
                  decoration: _deco('Enter your password',
                      Icons.lock_outline_rounded).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AppTheme.textMuted,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Password is required';
                    if (v!.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),

                const SizedBox(height: 36),

                // ── Login button ───────────────────────────────
                SizedBox(
                  width : double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _failedAttempts >= 5)
                        ? null
                        : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: _navy,
                      disabledBackgroundColor: _amber.withValues(alpha: 0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width : 22, height: 22,
                            child : CircularProgressIndicator(
                                color: Color(0xFF0E3B2E),
                                strokeWidth: 2.5),
                          )
                        : const Text(
                            'Access Dashboard',
                            style: TextStyle(
                                fontSize  : 15.5,
                                fontWeight: FontWeight.w700),
                          ),
                  ),
                ),

                const SizedBox(height: 32),

                // ── Restricted notice ──────────────────────────
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.security_rounded,
                            size: 13, color: _sub),
                        const SizedBox(width: 6),
                        Text(
                          'Thekaydaar · Super Admin Portal',
                          style: TextStyle(
                            color: _sub,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: _label, fontSize: 13.5,
          fontWeight: FontWeight.w700, letterSpacing: 0.1,
        ),
      );

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText  : hint,
        hintStyle : const TextStyle(
            color: AppTheme.textMuted, fontSize: 13.5),
        prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
        filled    : true,
        fillColor : _fill,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _navy, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        errorStyle: const TextStyle(fontSize: 12),
      );
}
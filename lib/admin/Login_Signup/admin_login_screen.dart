import 'package:ali_app/admin/Super_admin/super_admin_login_screen.dart';
import 'package:ali_app/admin/area_handler/area_handler_dashboard.dart';
import 'package:ali_app/admin/Regional_Admin/regional_admin_dashboard.dart';
import 'package:ali_app/admin/support_desk/support_desk_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/utils/app_theme.dart';
import 'admin_location_screen.dart';

const Map<String, String> _roleToCollection = {
  'AreaHandler'  : 'area_handler',
  'SupportDesk'  : 'support_desk',
  'RegionalAdmin': 'regional_admin',
};

class UniversalLoginScreen extends StatefulWidget {
  const UniversalLoginScreen({super.key});
  @override
  State<UniversalLoginScreen> createState() => _UniversalLoginScreenState();
}

class _UniversalLoginScreenState extends State<UniversalLoginScreen> {
  static const Color _navy   = Color(0xFF0E3B2E);
  static const Color _amber  = Color(0xFFC9A227);
  static const Color _white  = Color(0xFFFFFFFF);
  static const Color _label  = Color(0xFF1F2A26);
  static const Color _sub    = Color(0xFF5D6B64);
  static const Color _border = Color(0xFFE3E0D5);
  static const Color _fill   = Color(0xFFF7F5EF);

  final _formKey      = GlobalKey<FormState>();
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isLoading     = false;
  bool _obscure       = true;
  int  _failedAttempts = 0;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Find admin doc across all role collections ───────────────
  Future<({String role, Map<String, dynamic> data})?> _findAdminDoc(String uid) async {
    final db = FirebaseFirestore.instance;
    for (final entry in _roleToCollection.entries) {
      try {
        final doc = await db
            .collection('admins')
            .doc(entry.value)
            .collection('members')
            .doc(uid)
            .get();
        if (doc.exists && doc.data() != null) {
          debugPrint('[Login] Found in admins/${entry.value}/members/$uid');
          return (role: entry.key, data: {...doc.data()!, 'role': entry.key});
        }
      } catch (e) {
        debugPrint('[Login] Not in admins/${entry.value}: $e');
      }
    }
    return null;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_failedAttempts >= 5) {
      _snack('Too many failed attempts. Please restart the app.', Colors.red.shade800);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email   : _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) throw Exception('UID null after login.');

      final adminResult = await _findAdminDoc(uid);

      String role;
      String userName;
      Map<String, dynamic> userData;

      if (adminResult != null) {
        role     = adminResult.role;
        userData = adminResult.data;
        userName = (userData['fullName'] as String? ?? 'Admin').trim();
      } else {
        // Fallback: check users collection
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (!doc.exists) {
          await FirebaseAuth.instance.signOut();
          _failedAttempts++;
          _snack('Account not found. Make sure your account was approved and registered.', Colors.redAccent);
          return;
        }

        userData = doc.data()!;
        role     = (userData['role']     as String? ?? '').trim();
        userName = (userData['fullName'] as String? ?? 'Admin').trim();
      }

      // Check account status
      final status = (userData['accountStatus'] as String? ?? 'active').trim();
      if (status == 'suspended') {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        await _showSuspendedDialog();
        return;
      }

      debugPrint('════════════════════════════════════');
      debugPrint('[Login] uid      = $uid');
      debugPrint('[Login] role     = "$role"');
      debugPrint('[Login] fullName = "$userName"');
      debugPrint('[Login] city     = "${userData['operationalCity'] ?? userData['city']}"');
      debugPrint('[Login] area     = "${userData['assignedArea'] ?? userData['area']}"');
      debugPrint('════════════════════════════════════');

      // Block super admin from using this portal
      if (role == 'SuperAdmin' || role == 'Admin') {
        await FirebaseAuth.instance.signOut();
        _failedAttempts++;
        _snack('SuperAdmin must use the Staff Portal login.', const Color(0xFFA8861D));
        return;
      }

      // Update lastLoginAt
      try {
        if (adminResult != null) {
          await FirebaseFirestore.instance
              .collection('admins')
              .doc(_roleToCollection[role]!)
              .collection('members')
              .doc(uid)
              .update({'lastLoginAt': FieldValue.serverTimestamp()});
        } else {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .update({'lastLoginAt': FieldValue.serverTimestamp()});
        }
      } catch (e) {
        debugPrint('[Login] lastLoginAt update failed: $e');
      }

      if (!mounted) return;
      _navigateTo(role, userName, userData);
    } on FirebaseAuthException catch (e) {
      _failedAttempts++;
      final msg = switch (e.code) {
        'user-not-found'       => 'No account found with this email.',
        'wrong-password'       => 'Incorrect password.',
        'invalid-email'        => 'Invalid email address.',
        'user-disabled'        => 'This account has been suspended.',
        'too-many-requests'    => 'Too many attempts. Try later.',
        'network-request-failed' => 'No internet connection.',
        'invalid-credential'   => 'Email or password is incorrect.',
        _                      => 'Login failed (${e.code}).',
      };
      _snack(msg, Colors.redAccent);
    } catch (e) {
      _failedAttempts++;
      debugPrint('[Login] Unexpected error: $e');
      _snack('Something went wrong. Try again.', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showSuspendedDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(children: [
          Container(width: 40, height: 40,
              decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.block_rounded, color: Colors.redAccent, size: 20)),
          const SizedBox(width: 12),
          const Expanded(child: Text('Account Suspended',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
        ]),
        content: const Text(
          'Your account has been suspended by the Super Admin.\n\n'
          'Please contact support if you believe this is a mistake.',
          style: TextStyle(fontSize: 13.5, color: Color(0xFF5D6B64), height: 1.55)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ── Route to correct dashboard based on role ─────────────────
  void _navigateTo(String role, String name, Map<String, dynamic> userData) {
    _snack('Welcome, $name!', AppTheme.emerald);

    switch (role) {
      // ── Regional Admin ───────────────────────────────────────
      case 'RegionalAdmin':
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const RegionalAdminDashboard(adminName: '', adminCity: '', userData: {})));
        break;

      // ── Support Desk — NOW GOES TO REAL DASHBOARD ────────────
      case 'SupportDesk':
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const SupportDeskDashboard()));
        break;

      // ── Area Handler ─────────────────────────────────────────
      case 'AreaHandler':
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => AreaHandlerDashboard(userData: userData)));
        break;

      default:
        FirebaseAuth.instance.signOut();
        _snack(
          'Unknown role: "$role". Expected "RegionalAdmin", "SupportDesk", or "AreaHandler".',
          Colors.red.shade800,
        );
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
        backgroundColor: bg,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 52),
                Container(
                  width: 52, height: 52,
                  decoration: BoxDecoration(
                      color: _navy, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.token_rounded, color: _amber, size: 26),
                ),
                const SizedBox(height: 24),
                const Text('THEKAYDAAR',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 11,
                        fontWeight: FontWeight.w700, letterSpacing: 3.5)),
                const SizedBox(height: 8),
                const Text('Sub-Admin\nPortal',
                    style: TextStyle(color: _label, fontSize: 36,
                        fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.1)),
                const SizedBox(height: 6),
                const Text('سب ایڈمن پورٹل',
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 15, height: 1.4)),
                const SizedBox(height: 36),

                // Failed attempts warning
                if (_failedAttempts >= 3) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade100)),
                    child: Row(children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text('${5 - _failedAttempts} attempt(s) remaining.',
                          style: TextStyle(color: Colors.red.shade800, fontSize: 12.5,
                              fontWeight: FontWeight.w500))),
                    ]),
                  ),
                ],

                _fieldLabel('Email Address'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
                  style: const TextStyle(color: _label, fontSize: 14),
                  decoration: _deco('Enter your email', Icons.mail_outline_rounded),
                  validator: (v) {
                    final val = (v ?? '').trim();
                    if (val.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$').hasMatch(val)) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                _fieldLabel('Password'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: _label, fontSize: 14),
                  decoration: _deco('Enter your password', Icons.lock_outline_rounded).copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppTheme.textMuted, size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Password is required';
                    if (v!.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10), foregroundColor: _sub),
                    child: const Text('Forgot password?', style: TextStyle(fontSize: 13)),
                  ),
                ),
                const SizedBox(height: 4),

                SizedBox(
                  width: double.infinity, height: 54,
                  child: ElevatedButton(
                    onPressed: (_isLoading || _failedAttempts >= 5) ? null : _handleLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber, foregroundColor: _navy,
                      disabledBackgroundColor: _amber.withValues(alpha:0.4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(color: _navy, strokeWidth: 2.5))
                        : const Text('Login',
                            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 28),

                Row(children: [
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Text('OR', style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 12, letterSpacing: 1.5)),
                  ),
                  Expanded(child: Divider(color: Colors.grey.shade200)),
                ]),
                const SizedBox(height: 24),

                Center(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Text("Don't have an account? ",
                        style: TextStyle(color: _sub, fontSize: 14)),
                    GestureDetector(
                      onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const AdminLocationScreen())),
                      child: const Text('Register',
                          style: TextStyle(color: _navy, fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Super admin portal link
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const SuperAdminLoginScreen())),
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        foregroundColor: const Color(0xFFA9B5AE)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.admin_panel_settings_outlined, size: 13, color: Color(0xFFA9B5AE)),
                      SizedBox(width: 5),
                      Text('Staff portal',
                          style: TextStyle(fontSize: 12, color: Color(0xFFA9B5AE), letterSpacing: 0.3)),
                    ]),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(color: _label, fontSize: 13.5,
          fontWeight: FontWeight.w700, letterSpacing: 0.1));

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFA6B2AB), fontSize: 13.5),
    prefixIcon: Icon(icon, color: const Color(0xFFA6B2AB), size: 20),
    filled: true, fillColor: _fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _amber, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    errorStyle: const TextStyle(fontSize: 12),
  );
}
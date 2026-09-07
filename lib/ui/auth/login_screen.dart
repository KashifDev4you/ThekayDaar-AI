import 'dart:async';

import 'package:ali_app/ui/auth/sign_up.dart';
import 'package:ali_app/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isObscure = true;
  final TextEditingController nicController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  void dispose() {
    nicController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  // ── Login Logic ───────────────────────────────────────────────
  Future<void> _login(String role) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      // Step 1: NIC se email banao aur Firebase Auth se login karo
      final String cleanNIC = nicController.text
          .trim()
          .replaceAll('-', '')
          .replaceAll(' ', '');
      final String loginEmail = '$cleanNIC@thekaydaar.pk';

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: loginEmail,
        password: passwordController.text.trim(),
      );

      final String uid = userCredential.user!.uid;

      // Step 2: Sahi collection mein user dhundo
      DocumentSnapshot? userDoc;
      String? foundInCollection;

      // Pehle clients/ collection check karo
      final clientDoc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(uid)
          .get();

      if (clientDoc.exists) {
        userDoc = clientDoc;
        foundInCollection = 'clients';
      } else {
        // Phir thekaydaars/ collection check karo
        final thekaydaarDoc = await FirebaseFirestore.instance
            .collection('thekaydaars')
            .doc(uid)
            .get();

        if (thekaydaarDoc.exists) {
          userDoc = thekaydaarDoc;
          foundInCollection = 'thekaydaars';
        }
      }

      // Step 3: Agar document nahi mila
      if (userDoc == null || !userDoc.exists) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account nahi mila. Pehle register karein.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Step 4: Firestore ka poora data Map mein lo
      // Yeh data profile screen ko bheja jayega
      final Map<String, dynamic> userData =
          userDoc.data() as Map<String, dynamic>;

      // Step 5: Role match check karo
      final String firestoreRole =
          (userData['role'] ?? '').toString().trim().toLowerCase();
      final String selectedRoleLower = role.trim().toLowerCase();

      // Contractor aur Thekaydaar dono same hain
      final bool roleMatches =
          firestoreRole == selectedRoleLower ||
          (firestoreRole == 'contractor' &&
              selectedRoleLower == 'thekaydaar') ||
          (firestoreRole == 'thekaydaar' &&
              selectedRoleLower == 'contractor');

      if (!roleMatches) {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Yeh account "$firestoreRole" role ka hai. '
              'Sahi role se login karein.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Step 6: Account suspended check karo
      final String accountStatus =
          (userData['accountStatus'] ?? 'active').toString();
      if (accountStatus == 'suspended') {
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aapka account suspend kar diya gaya hai. '
              'Admin se rabta karein.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Step 7: Sab theek — success snackbar dikhao
      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login successful! Redirecting...'),
          backgroundColor: AppTheme.emerald,
        ),
      );

      // Step 8: 2 second baad sahi dashboard par bhejo
      // userData map arguments mein bhejo taake profile screen use kar sake
      Timer(const Duration(seconds: 2), () {
        if (!mounted) return;

        if (foundInCollection == 'thekaydaars') {
          // ── Contractor dashboard ──────────────────────────────
          // userData mein yeh fields honi chahiye:
          //   fullName, nicNumber, role, uid, displayId,
          //   accountStatus, createdAt
          Navigator.pushReplacementNamed(
            context,
            '/thekaydaar',
            arguments: userData, // ← poora user data bhej do
          );
        } else if (foundInCollection == 'clients') {
          // ── Client dashboard ──────────────────────────────────
          Navigator.pushReplacementNamed(
            context,
            '/Client',
            arguments: userData, // ← poora user data bhej do
          );
        }
      });
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage = 'Login failed. Please try again.';
      if (e.code == 'user-not-found' ||
          e.code == 'wrong-password' ||
          e.code == 'invalid-credential') {
        errorMessage = 'NIC ya password ghalat hai.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Bahut zyada attempts. Thodi der baad try karein.';
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Yeh account disable kar diya gaya hai.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage,
              style: const TextStyle(fontFamily: 'Poppins')),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Route se role lo — agar null ho to empty string
    final String role =
        (ModalRoute.of(context)?.settings.arguments as String?) ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(role.isNotEmpty ? 'Login as $role' : 'Login'),
      ),
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Brand label ──────────────────────────────────
                Center(
                  child: Text(
                    'THEKAYDAAR',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2.0,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── Heading ──────────────────────────────────────
                Center(
                  child: Text(
                    'Welcome back',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textBody,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'لاگ ان کریں',
                    style: TextStyle(
                      fontSize: 20,
                      color: AppTheme.textMuted,
                      fontFamily: 'Jameel-Noori-Nastaleeq',
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // ── Form ─────────────────────────────────────────
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // NIC Field
                      _buildLabel('NIC Number'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: nicController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9-]')),
                        ],
                        maxLength: 15,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'NIC is required';
                          }
                          if (v.length < 15) return 'Enter a valid NIC';
                          return null;
                        },
                        decoration: _inputDecoration(
                          hint: 'xxxxx-xxxxxxx-x',
                          icon: Icons.credit_card_outlined,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Password Field
                      _buildLabel('Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: passwordController,
                        obscureText: _isObscure,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Password is required';
                          }
                          if (v.length < 6) return 'At least 6 characters';
                          return null;
                        },
                        decoration: _inputDecoration(
                          hint: 'Enter your password',
                          icon: Icons.lock_outline,
                        ).copyWith(
                          suffixIcon: IconButton(
                            icon: Icon(
                              _isObscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: AppTheme.textMuted,
                              size: 18,
                            ),
                            onPressed: () =>
                                setState(() => _isObscure = !_isObscure),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Login Button ──────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : () => _login(role),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.emerald,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Login',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Poppins',
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Register Link ─────────────────────────────────
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "Don't have an account?",
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textMuted,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SignUp(role: role),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.only(left: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.emerald,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppTheme.textMuted,
        fontFamily: 'Poppins',
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
      prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 18),
      filled: true,
      fillColor: AppTheme.surface,
      errorStyle: const TextStyle(
        fontSize: 12,
        color: Colors.redAccent,
        fontFamily: 'Poppins',
      ),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: AppTheme.gold, width: 1.2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.2),
      ),
    );
  }
}
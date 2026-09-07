// =============================================================================
// admin_signUp_Screen.dart — FINAL
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_login_screen.dart';

class _PasscodeException implements Exception {
  final String message;
  const _PasscodeException(this.message);
  @override
  String toString() => message;
}

class _CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 13 ? digits.substring(0, 13) : digits;
    final buf = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 5 || i == 12) buf.write('-');
      buf.write(capped[i]);
    }
    final out = buf.toString();
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

class _PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final capped = digits.length > 11 ? digits.substring(0, 11) : digits;
    final buf = StringBuffer();
    for (int i = 0; i < capped.length; i++) {
      if (i == 4) buf.write('-');
      buf.write(capped[i]);
    }
    final out = buf.toString();
    return TextEditingValue(
      text: out,
      selection: TextSelection.collapsed(offset: out.length),
    );
  }
}

class AdminSignUp extends StatefulWidget {
  final String prefillEmail;

  const AdminSignUp({super.key, this.prefillEmail = ''});

  @override
  State<AdminSignUp> createState() => _AdminSignUpState();
}

class _AdminSignUpState extends State<AdminSignUp> {
  static const Color _navy = Color(0xFF0E3B2E);
  static const Color _amber = Color(0xFFC9A227);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _label = Color(0xFF1F2A26);
  static const Color _sub = Color(0xFF5D6B64);
  static const Color _border = Color(0xFFE3E0D5);
  static const Color _fill = Color(0xFFF7F5EF);

  static const Map<String, String> _roleToCollection = {
    'RegionalAdmin': 'regional_admin',
    'AreaHandler': 'area_handler',
    'SupportDesk': 'support_desk',
  };

  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _verifying = false;

  late final TextEditingController _fullNameCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _nicCtrl;
  late final TextEditingController _secretTokenCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _confirmPasswordCtrl;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;

  String? _verifiedCode;
  String? _verifiedDesignation;
  String? _verifiedRole;
  String? _verifiedCity;
  String? _verifiedArea;

  bool get _isVerified => _verifiedCode != null;

  @override
  void initState() {
    super.initState();
    _fullNameCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _emailCtrl = TextEditingController(text: widget.prefillEmail);
    _nicCtrl = TextEditingController();
    _secretTokenCtrl = TextEditingController();
    _passwordCtrl = TextEditingController();
    _confirmPasswordCtrl = TextEditingController();
  }

  @override
  void dispose() {
    for (final c in [
      _fullNameCtrl,
      _phoneCtrl,
      _emailCtrl,
      _nicCtrl,
      _secretTokenCtrl,
      _passwordCtrl,
      _confirmPasswordCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Snack (post-frame safe) ───────────────────────────────────────────────
  void _snack(String msg, Color bg) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            backgroundColor: bg,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
    });
  }

  // ── Verify passcode ───────────────────────────────────────────────────────
  Future<void> _verifyPasscode() async {
    final code = _secretTokenCtrl.text.trim().toUpperCase();
    if (code.isEmpty) {
      _snack(
        'Enter the passcode from your Super Admin first.',
        Colors.redAccent,
      );
      return;
    }
    setState(() => _verifying = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('admin_passcodes')
          .doc(code)
          .get();

      if (!doc.exists) {
        throw const _PasscodeException(
          'Invalid passcode. Check it carefully and try again.',
        );
      }

      final data = doc.data()!;
      final isUsed = data['isUsed'] as bool? ?? false;
      if (isUsed) {
        throw const _PasscodeException(
          'This passcode has already been used. Ask Super Admin for a new one.',
        );
      }

      final designation = (data['designation'] ?? '').toString();
      final role = (data['role'] ?? '').toString();
      final city = (data['city'] ?? '').toString();
      final area = (data['area'] ?? '').toString();

      if (designation.isEmpty || role.isEmpty || city.isEmpty || area.isEmpty) {
        throw const _PasscodeException(
          'This passcode is missing required data. Contact Super Admin.',
        );
      }
      if (!_roleToCollection.containsKey(role)) {
        throw const _PasscodeException(
          'This passcode has an unrecognized role. Contact Super Admin.',
        );
      }

      if (!mounted) return;
      setState(() {
        _verifiedCode = code;
        _verifiedDesignation = designation;
        _verifiedRole = role;
        _verifiedCity = city;
        _verifiedArea = area;
      });
      _snack('Passcode verified. Complete the form below.', const Color(0xFF10B981));
    } on _PasscodeException catch (e) {
      _snack(e.message, Colors.red.shade800);
    } catch (e) {
      _snack('Could not verify passcode: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _resetPasscode() {
    setState(() {
      _verifiedCode = null;
      _verifiedDesignation = null;
      _verifiedRole = null;
      _verifiedCity = null;
      _verifiedArea = null;
      _secretTokenCtrl.clear();
    });
  }

  // ── Registration ──────────────────────────────────────────────────────────
  Future<void> _handleRegistration() async {
    if (!_isVerified) {
      _snack('Verify your passcode first.', Colors.redAccent);
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      _snack('Please accept the Terms & Conditions.', Colors.redAccent);
      return;
    }

    setState(() => _isLoading = true);

    final code = _verifiedCode!;
    final designation = _verifiedDesignation!;
    final role = _verifiedRole!;
    final city = _verifiedCity!;
    final area = _verifiedArea!;
    final collectionName = _roleToCollection[role]!;

    final email = _emailCtrl.text.trim().toLowerCase();
    final rawNic = _nicCtrl.text.replaceAll('-', '').trim();
    final rawPhone = _phoneCtrl.text.replaceAll('-', '').trim();
    final fullName = _fullNameCtrl.text.trim();
    final password = _passwordCtrl.text;

    String? uid;

    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      uid = cred.user!.uid;

      final db = FirebaseFirestore.instance;
      await db.runTransaction((tx) async {
        final passcodeRef = db.collection('admin_passcodes').doc(code);
        final freshSnap = await tx.get(passcodeRef);

        if (!freshSnap.exists) {
          throw const _PasscodeException('Passcode no longer exists.');
        }
        final freshData = freshSnap.data()!;
        if ((freshData['isUsed'] as bool? ?? false) == true) {
          throw const _PasscodeException(
            'This passcode was just used by someone else. Ask Super Admin for a new one.',
          );
        }

        final sharedPayload = {
          'uid': uid,
          'fullName': fullName,
          'nic': rawNic,
          'phone': rawPhone,
          'email': email,
          'role': role,
          'designation': designation,
          'designationKey': collectionName,
          'city': city,
          'operationalCity': city,   // ← ADD THIS LINE
          'area': area,
          'passcodeUsed': code,
          'accountStatus': 'active',
          'canResetPassword': true,
          'registeredAt': FieldValue.serverTimestamp(),
          'lastLoginAt': null,
          'notes': '',
        };

        tx.set(db.collection('users').doc(uid), {
          'uid': uid,
          'fullName': fullName,
          'nic': rawNic,
          'phone': rawPhone,
          'email': email,
          'role': role,
          'designation': designation,
          'city': city,
          'operationalCity': city,
          'area': area,
          'accountStatus': 'active',
          'createdAt': FieldValue.serverTimestamp(),
        });

        tx.set(
          db
              .collection('admins')
              .doc(collectionName)
              .collection('members')
              .doc(uid),
          sharedPayload,
        );

        tx.set(db.collection('admin_roster').doc(uid), sharedPayload);

        tx.update(passcodeRef, {
          'isUsed': true,
          'usedBy': email,
          'usedByUid': uid,
          'usedAt': FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;
      // Navigate immediately — no snack before navigation
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const UniversalLoginScreen()),
        (route) => false,
      );
    } on _PasscodeException catch (e) {
      await FirebaseAuth.instance.signOut();
      _snack(e.message, Colors.red.shade800);
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'weak-password' => 'Password is too weak (min 6 characters).',
        'email-already-in-use' => 'An account already exists for this email.',
        'invalid-email' => 'The email address format is invalid.',
        _ => 'Authentication error (${e.code}).',
      };
      _snack(msg, Colors.redAccent);
    } catch (e, stack) {
      debugPrint('[AdminSignUp] Unexpected error: $e\n$stack');
      _snack('Unexpected error: ${e.toString()}', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _white,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: _white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Create Admin Account',
          style: TextStyle(
            color: _white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: MouseRegion(
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Security badge
                  const _SecurityBadge(),
                  const SizedBox(height: 18),

                  const Text(
                    'Register Staff Member',
                    style: TextStyle(
                      color: _label,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Enter your passcode to unlock the rest of this form.',
                    style: TextStyle(color: _sub, fontSize: 13.5, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  // ── Passcode row ────────────────────────────────────────────
                  _sectionLabel('Clearance Passcode'),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter the passcode shared privately by your Super Admin.',
                    style: TextStyle(color: Color(0xFFA6B2AB), fontSize: 11.5),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _secretTokenCtrl,
                          enabled: !_isVerified,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                          decoration: _deco(
                            'Enter passcode from Super Admin',
                            Icons.vpn_key_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 54,
                        width: 90,
                        child: ElevatedButton(
                          onPressed: _isVerified
                              ? _resetPasscode
                              : (_verifying ? null : _verifyPasscode),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isVerified ? const Color(0xFF10B981) : _navy,
                            foregroundColor: _white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: _verifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    color: _white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(_isVerified ? 'Change' : 'Verify'),
                        ),
                      ),
                    ],
                  ),

                  // ── Not yet verified hint ───────────────────────────────────
                  if (!_isVerified) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _fill,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _border),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: Color(0xFFA6B2AB),
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Verify your passcode to reveal your jurisdiction '
                              'and the rest of the registration form.',
                              style: TextStyle(
                                color: Color(0xFF5D6B64),
                                fontSize: 12.5,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ── Verified — show full form ───────────────────────────────
                  if (_isVerified) ...[
                    const SizedBox(height: 24),
                    _JurisdictionCard(
                      designation: _verifiedDesignation!,
                      city: _verifiedCity!,
                      area: _verifiedArea!,
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE3E0D5)),
                    const SizedBox(height: 16),

                    _sectionLabel('Full Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _fullNameCtrl,
                      keyboardType: TextInputType.name,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 50,
                      buildCounter: _noCounter,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r"[a-zA-Z\s\.\-']"),
                        ),
                      ],
                      style: const TextStyle(color: _label, fontSize: 14),
                      decoration: _deco(
                        'Your full name',
                        Icons.person_outline_rounded,
                      ),
                      validator: (v) {
                        final name = (v ?? '').trim();
                        if (name.isEmpty) return 'Full name is required';
                        if (name.length < 3) return 'Name is too short';
                        if (!name.contains(' ')) {
                          return 'Enter first and last name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('CNIC Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nicCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 15,
                      buildCounter: _noCounter,
                      inputFormatters: [_CnicInputFormatter()],
                      style: const TextStyle(color: _label, fontSize: 14),
                      decoration: _deco(
                        '42101-1234567-1',
                        Icons.wallet_membership_outlined,
                      ),
                      validator: (v) {
                        final raw = (v ?? '').replaceAll('-', '').trim();
                        if (raw.isEmpty) return 'CNIC is required';
                        if (raw.length != 13) {
                          return 'CNIC must be exactly 13 digits';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('Mobile Number'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      maxLength: 12,
                      buildCounter: _noCounter,
                      inputFormatters: [_PhoneInputFormatter()],
                      style: const TextStyle(color: _label, fontSize: 14),
                      decoration: _deco(
                        '03XX-XXXXXXX',
                        Icons.phone_android_rounded,
                      ),
                      validator: (v) {
                        final raw = (v ?? '').replaceAll('-', '').trim();
                        if (raw.isEmpty) return 'Mobile number is required';
                        if (raw.length != 11) return 'Must be 11 digits';
                        if (!raw.startsWith('03')) return 'Must start with 03';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('Corporate Email'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      maxLength: 100,
                      buildCounter: _noCounter,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      style: const TextStyle(color: _label, fontSize: 14),
                      decoration: _deco(
                        'admin@thekaydaar.pk',
                        Icons.mail_outline_rounded,
                      ),
                      validator: (v) {
                        final e = (v ?? '').trim();
                        if (e.isEmpty) return 'Email is required';
                        if (!RegExp(
                          r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$',
                        ).hasMatch(e)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('Password'),
                    const SizedBox(height: 8),
                    _PasswordField(
                      ctrl: _passwordCtrl,
                      hint: 'Create a password',
                      obscure: _obscurePassword,
                      onToggle: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      deco: _deco,
                      validator: (v) {
                        if ((v ?? '').isEmpty) return 'Password is required';
                        if (v!.length < 6) return 'Minimum 6 characters';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    _sectionLabel('Confirm Password'),
                    const SizedBox(height: 8),
                    _PasswordField(
                      ctrl: _confirmPasswordCtrl,
                      hint: 'Re-enter password',
                      obscure: _obscureConfirm,
                      onToggle: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      deco: _deco,
                      validator: (v) {
                        if ((v ?? '').isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _passwordCtrl.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // Terms checkbox
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 22,
                          width: 22,
                          child: Checkbox(
                            value: _agreeToTerms,
                            activeColor: _amber,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(5),
                            ),
                            side: const BorderSide(
                              color: Color(0xFFA9B5AE),
                              width: 1.5,
                            ),
                            onChanged: (v) =>
                                setState(() => _agreeToTerms = v ?? false),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _agreeToTerms = !_agreeToTerms),
                            child: const Text(
                              'I confirm that the credentials provided match '
                              'my legitimate identity documentation.',
                              style: TextStyle(
                                color: Color(0xFF5D6B64),
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegistration,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _amber,
                          foregroundColor: _navy,
                          disabledBackgroundColor: _amber.withValues(
                            alpha: 0.5,
                          ),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: _navy,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: _label,
      fontSize: 13.5,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.1,
    ),
  );

  Widget? _noCounter(
    BuildContext ctx, {
    required int currentLength,
    required int? maxLength,
    required bool isFocused,
  }) => null;

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFA6B2AB), fontSize: 13.5),
    prefixIcon: Icon(icon, color: const Color(0xFFA6B2AB), size: 20),
    filled: true,
    fillColor: _fill,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _border),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: _amber, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.redAccent),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
    errorStyle: const TextStyle(fontSize: 12),
  );
}

// =============================================================================
// Supporting widgets
// =============================================================================

class _PasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;
  final InputDecoration Function(String, IconData) deco;
  final String? Function(String?)? validator;

  const _PasswordField({
    required this.ctrl,
    required this.hint,
    required this.obscure,
    required this.onToggle,
    required this.deco,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    obscureText: obscure,
    validator: validator,
    style: const TextStyle(color: Color(0xFF1F2A26), fontSize: 14),
    decoration: deco(hint, Icons.lock_outline_rounded).copyWith(
      suffixIcon: IconButton(
        icon: Icon(
          obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: const Color(0xFFA6B2AB),
          size: 20,
        ),
        onPressed: onToggle,
      ),
    ),
  );
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: Colors.red.shade100),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.security_rounded,
                size: 12,
                color: Colors.red.shade700,
              ),
              const SizedBox(width: 6),
              Text(
                'SECURE ADMINISTRATIVE SIGNUP',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.red.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _JurisdictionCard extends StatelessWidget {
  final String designation, city, area;

  const _JurisdictionCard({
    required this.designation,
    required this.city,
    required this.area,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFE7F2ED),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFCFE5DC)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1A5C46).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Color(0xFF1A5C46),
            size: 20,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Locked by Super Admin — cannot be edited',
                style: TextStyle(
                  color: Color(0xFF1A5C46),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                designation,
                style: const TextStyle(
                  color: Color(0xFF0E3B2E),
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$city  ·  $area',
                style: const TextStyle(
                  color: Color(0xFF0E3B2E),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.lock_rounded, color: Color(0xFF1A5C46), size: 18),
      ],
    ),
  );
}

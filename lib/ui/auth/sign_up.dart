// =============================================================================
// sign_up_screen.dart — Client / Thekaydaar Signup
//
// CHANGES FROM ORIGINAL:
//   [NEW 1] City dropdown added
//   [NEW 2] Area dropdown added (changes based on selected city)
//   [NEW 3] city + area saved to Firestore so AreaHandler can filter users
//   [NEW 4] assignedArea field saved (used by AreaHandler dashboard query)
// =============================================================================

import 'dart:async';

import 'package:ali_app/utils/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
// CITY → AREAS MAP  (same as admin registration — keep in sync)
// =============================================================================
const Map<String, List<String>> _cityAreas = {
  'Karachi': [
    'Clifton / DHA', 'Gulshan-e-Iqbal', 'Nazimabad / North Nazimabad',
    'Johar / Malir', 'Saddar / Lyari', 'FB Area / Liaquatabad',
    'Bahria Town / DHA City', 'Korangi / Landhi', 'Orangi Town / SITE',
  ],
  'Lahore': [
    'Gulberg', 'DHA Lahore', 'Model Town', 'Johar Town',
    'Bahria Town Lahore', 'Cantt', 'Iqbal Town', 'Township', 'Wapda Town',
  ],
  'Islamabad': [
    'F-6 / F-7', 'F-8 / F-10', 'G-9 / G-10', 'G-11 / G-12',
    'I-8 / I-9', 'Bahria Town Islamabad', 'DHA Islamabad', 'Blue Area',
  ],
  'Rawalpindi': [
    'Saddar', 'Chaklala', 'Bahria Town Rawalpindi',
    'Satellite Town', 'Gulraiz', 'Westridge',
  ],
  'Peshawar': [
    'University Town', 'Hayatabad', 'Saddar / Cantonment',
    'Gulbahar', 'Tehkal', 'Regi Model Town',
  ],
  'Quetta': [
    'Jinnah Town', 'Satellite Town', 'Brewery Road',
    'Pishin Stop', 'Airport Road', 'Sariab',
  ],
  'Multan': [
    'Cantt', 'Shah Rukn-e-Alam', 'Gulgasht Colony',
    'Wapda Town', 'New Multan', 'Bosan Road',
  ],
  'Faisalabad': [
    'Peoples Colony', 'Gulberg Faisalabad', 'D Ground',
    'Samanabad', 'Canal Road', 'Jinnah Colony',
  ],
};

const List<String> _allCities = [
  'Karachi', 'Lahore', 'Islamabad', 'Rawalpindi',
  'Peshawar', 'Quetta', 'Multan', 'Faisalabad',
];

// =============================================================================
// Custom ID generator (unchanged from original)
// =============================================================================
Future<String> generateCustomId() async {
  final docRef = FirebaseFirestore.instance
      .collection('metadata')
      .doc('user_counters');

  final result = await FirebaseFirestore.instance.runTransaction<int>(
    (transaction) async {
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        transaction.set(docRef, {'last_id': 1});
        return 1;
      }
      final int newId =
          (snapshot.data() as Map<String, dynamic>)['last_id'] + 1;
      transaction.update(docRef, {'last_id': newId});
      return newId;
    },
  );

  return "TKD-${result.toString().padLeft(4, '0')}";
}

// =============================================================================
// SignUp Widget
// =============================================================================
class SignUp extends StatefulWidget {
  const SignUp({required this.role, super.key});
  final String role;

  @override
  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController nameController            = TextEditingController();
  final TextEditingController nicController             = TextEditingController();
  final TextEditingController passwordController        = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // [NEW 1] City & area state
  String? _selectedCity;
  String? _selectedArea;

  bool _isObscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    nameController.dispose();
    nicController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // Areas available for the currently selected city
  List<String> get _areasForCity {
    if (_selectedCity == null) return [];
    return _cityAreas[_selectedCity] ?? [];
  }

  /// Role ke mutabiq sahi collection choose karo
  String get _targetCollection {
    final role = widget.role.trim().toLowerCase();
    if (role == 'thekaydaar' || role == 'contractor') return 'thekaydaars';
    return 'clients';
  }

  // ===========================================================================
  // _register
  // ===========================================================================
  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      // STEP 1 — Firebase Auth account
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email   : "${nicController.text.trim().replaceAll('-', '')}@thekaydaar.pk",
        password: passwordController.text.trim(),
      );

      // STEP 2 — Generate display ID
      String customDisplayId = await generateCustomId();

      // STEP 3 — Save to Firestore
      // [NEW 3] city and area are now saved so AreaHandler can filter
      await FirebaseFirestore.instance
          .collection(_targetCollection)
          .doc(userCredential.user!.uid)
          .set({
        'fullName'      : nameController.text.trim(),
        'nicNumber'     : nicController.text.trim(),
        'role'          : widget.role,
        'uid'           : userCredential.user!.uid,
        'displayId'     : customDisplayId,
        'accountStatus' : 'active',
        'createdAt'     : FieldValue.serverTimestamp(),

        // [NEW 3] Location fields — used by AreaHandler dashboard to filter
        'city'          : _selectedCity,
        'area'          : _selectedArea,

        // [NEW 4] Combined key for easy Firestore querying:
        //   AreaHandler queries: where('assignedArea', '==', '$city|$area')
        'assignedArea'  : '$_selectedCity|$_selectedArea',
      });

      if (!mounted) return;
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content         : Text('Registration successful!'),
          backgroundColor : AppTheme.emerald,
        ),
      );

      // STEP 4 — Navigate to login after 2 seconds
      Timer(const Duration(seconds: 2), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/login',
          arguments: widget.role,
        );
      });

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage = 'Registration failed. Please try again.';
      if (e.code == 'email-already-in-use') {
        errorMessage =
            'Yeh NIC Number pehle se register hai. Baraye meherbani apna NIC daal ke Login karein.';
      } else if (e.code == 'weak-password') {
        errorMessage = 'Password thora mushkil rakhein.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'NIC format mein masla hai.';
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content         : Text(errorMessage,
            style: const TextStyle(fontFamily: 'Poppins')),
        backgroundColor : Colors.redAccent,
      ));

    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      debugPrint('Registration error: $e');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content         : Text('Error: ${e.toString()}'),
        backgroundColor : Colors.redAccent,
      ));
    }
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Signup as ${widget.role}"),
      ),
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Brand label ────────────────────────────────────────────
                Center(
                  child: Text(
                    'THEKAYDAAR',
                    style: const TextStyle(
                      fontSize     : 18,
                      fontWeight   : FontWeight.w600,
                      letterSpacing: 2.0,
                      color        : AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(height: 13),

                // ── Heading ────────────────────────────────────────────────
                Center(
                  child: Text(
                    'Create an account',
                    style: TextStyle(
                        fontSize  : 22,
                        fontWeight: FontWeight.w600,
                        color     : AppTheme.textBody),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    'رجسٹر کریں',
                    style: TextStyle(
                      fontSize  : 20,
                      color     : AppTheme.textMuted,
                      fontFamily: 'Jameel-Noori-Nastaleeq',
                    ),
                  ),
                ),
                const SizedBox(height: 36),

                // ── Form ───────────────────────────────────────────────────
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Full Name ────────────────────────────────────────
                      _buildLabel('Full Name'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller        : nameController,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Name is required';
                          return null;
                        },
                        decoration: _inputDecoration(
                            hint: 'Your full name',
                            icon: Icons.person_outline),
                      ),
                      const SizedBox(height: 16),

                      // ── NIC Number ───────────────────────────────────────
                      _buildLabel('NIC Number'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller     : nicController,
                        keyboardType   : TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[0-9-]')),
                        ],
                        maxLength : 15,
                        validator : (v) {
                          if (v == null || v.isEmpty) return 'NIC is required';
                          if (v.length < 15) return 'Enter a valid NIC';
                          return null;
                        },
                        decoration: _inputDecoration(
                            hint: 'xxxxx-xxxxxxx-x',
                            icon: Icons.credit_card_outlined),
                      ),
                      const SizedBox(height: 16),

                      // ── [NEW 1] City dropdown ────────────────────────────
                      _buildLabel('City'),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue    : _selectedCity,
                        validator: (v) =>
                            v == null ? 'Please select your city' : null,
                        onChanged: (city) {
                          setState(() {
                            _selectedCity = city;
                            // Reset area when city changes
                            _selectedArea = null;
                          });
                        },
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: AppTheme.textMuted, size: 20),
                        decoration: _inputDecoration(
                            hint: 'Select your city',
                            icon: Icons.location_city_outlined),
                        items: _allCities
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c,
                                      style: const TextStyle(fontSize: 13)),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 16),

                      // ── [NEW 2] Area dropdown ────────────────────────────
                      // Only shows after a city is selected
                      if (_selectedCity != null) ...[
                        _buildLabel('Area'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue    : _selectedArea,
                          validator: (v) =>
                              v == null ? 'Please select your area' : null,
                          onChanged: (area) =>
                              setState(() => _selectedArea = area),
                          icon: Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade400, size: 20),
                          decoration: _inputDecoration(
                              hint: 'Select your area',
                              icon: Icons.map_outlined),
                          items: _areasForCity
                              .map((a) => DropdownMenuItem(
                                    value: a,
                                    child: Text(a,
                                        style: const TextStyle(fontSize: 13)),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // ── Password ─────────────────────────────────────────
                      _buildLabel('Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller : passwordController,
                        obscureText: _isObscure,
                        validator  : (v) {
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
                      const SizedBox(height: 16),

                      // ── Confirm Password ─────────────────────────────────
                      _buildLabel('Confirm Password'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller : confirmPasswordController,
                        obscureText: _isObscure,
                        validator  : (v) {
                          if (v == null || v.isEmpty) {
                            return 'Please confirm your password';
                          }
                          if (v != passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                        decoration: _inputDecoration(
                          hint: 'Re-enter your password',
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

                // ── Register Button ────────────────────────────────────────
                SizedBox(
                  width : double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.gold,
                      foregroundColor: AppTheme.emerald,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width : 20,
                            height: 20,
                            child : CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Register'),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Login Link ─────────────────────────────────────────────
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Already have an account?',
                        style: const TextStyle(
                            fontSize  : 13,
                            color     : AppTheme.textMuted,
                            fontFamily: 'Poppins'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(
                          context,
                          '/login',
                          arguments: widget.role,
                        ),
                        style: TextButton.styleFrom(
                          padding      : const EdgeInsets.only(left: 4),
                          minimumSize  : Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Login',
                          style: TextStyle(
                            fontSize  : 13,
                            fontWeight: FontWeight.w600,
                            color     : AppTheme.emerald,
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

  // ===========================================================================
  // HELPERS
  // ===========================================================================
  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
          fontSize  : 12,
          fontWeight: FontWeight.w500,
          color     : AppTheme.textMuted,
          fontFamily: 'Poppins',
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) =>
      InputDecoration(
        counterText : '',
        hintText    : hint,
        hintStyle   : const TextStyle(color: AppTheme.textMuted, fontSize: 13),
        prefixIcon  : Icon(icon, color: AppTheme.textMuted, size: 18),
        filled      : true,
        fillColor   : AppTheme.surface,
        errorStyle  : const TextStyle(
            fontSize: 12, color: Colors.redAccent, fontFamily: 'Poppins'),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide: const BorderSide(color: AppTheme.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide:
                const BorderSide(color: AppTheme.gold, width: 1.2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            borderSide:
                const BorderSide(color: Colors.redAccent, width: 1.2)),
      );
}
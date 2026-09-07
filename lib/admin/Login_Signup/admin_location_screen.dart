// =============================================================================
// admin_location_screen.dart — REWRITTEN
//
// This screen NO LONGER lets a user pick their own city / area / role, and
// it NO LONGER generates a passcode on the client.
//
// It is now a pure "Request Access" form. Super Admin reviews requests from
// super_admin_issue_passcode_screen.dart and is the ONLY place a real
// admin_passcodes/{code} doc gets created — that doc is what decides
// designation, city, and area, not anything typed here.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_sign_up_screen.dart';
import 'admin_login_screen.dart';

const Map<String, String> _adminRoles = {
  'Regional Manager': 'RegionalAdmin',
  'Area Handler': 'AreaHandler',
  'Support Desk': 'SupportDesk',
};

class AdminLocationScreen extends StatefulWidget {
  const AdminLocationScreen({super.key});

  @override
  State<AdminLocationScreen> createState() => _AdminLocationScreenState();
}

class _AdminLocationScreenState extends State<AdminLocationScreen> {
  static const Color _navy = Color(0xFF0E3B2E);
  static const Color _amber = Color(0xFFC9A227);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _label = Color(0xFF1F2A26);
  static const Color _sub = Color(0xFF5D6B64);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String? _selectedRole;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = _emailCtrl.text.trim().toLowerCase();
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    final role = _selectedRole!;
    final note = _noteCtrl.text.trim();

    try {
      final db = FirebaseFirestore.instance;

      // Guard: don't let the same email pile up duplicate pending requests.
      final existing = await db
          .collection('access_requests')
          .where('email', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        _snack(
          'You already have a pending request with this email. '
          'Please wait for Super Admin to contact you.',
          const Color(0xFFA8861D),
        );
        setState(() => _isLoading = false);
        return;
      }

      final docRef = db.collection('access_requests').doc();
      await docRef.set({
        'id': docRef.id,
        'fullName': name,
        'email': email,
        'phone': phone,
        'requestedRole': role, // hint only — NOT authoritative, Super Admin decides
        'note': note,
        'status': 'pending', // pending -> fulfilled
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _RequestSubmittedScreen(email: email, role: role),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to submit request: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color bg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
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
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Request Admin Access',
            style:
                TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SecurityBadge(),
                const SizedBox(height: 20),
                const Text('Request Admin\nAccess',
                    style: TextStyle(
                      color: _label,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.15,
                    )),
                const SizedBox(height: 8),
                const Text(
                  'Submit your details. Super Admin reviews every request manually '
                  'and decides your city, area, and designation before issuing a '
                  'passcode — these are never chosen by you.',
                  style: TextStyle(color: _sub, fontSize: 13.5, height: 1.5),
                ),
                const SizedBox(height: 20),
                const _HowItWorksCard(),
                const SizedBox(height: 24),
                _sectionLabel('Full Name'),
                const SizedBox(height: 8),
                _textField(
                  controller: _nameCtrl,
                  hint: 'Your full name',
                  icon: Icons.person_outline_rounded,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Full name is required' : null,
                ),
                const SizedBox(height: 20),
                _sectionLabel('Corporate Email'),
                const SizedBox(height: 8),
                _textField(
                  controller: _emailCtrl,
                  hint: 'admin@thekaydaar.pk',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  inputFormatters: [
                    FilteringTextInputFormatter.deny(RegExp(r'\s'))
                  ],
                  validator: (v) {
                    final e = (v ?? '').trim();
                    if (e.isEmpty) return 'Email is required';
                    if (!RegExp(r'^[\w\.\+\-]+@[\w\-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(e)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _sectionLabel('Mobile Number'),
                const SizedBox(height: 8),
                _textField(
                  controller: _phoneCtrl,
                  hint: '03XXXXXXXXX',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                  validator: (v) {
                    final raw = (v ?? '').trim();
                    if (raw.isEmpty) return 'Mobile number is required';
                    if (raw.length != 11) return 'Must be 11 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _sectionLabel('Role you are requesting'),
                const SizedBox(height: 6),
                const Text(
                  'For Super Admin\'s reference only — the final designation, '
                  'city, and area are set by Super Admin when issuing your passcode.',
                  style: TextStyle(color: Color(0xFFA6B2AB), fontSize: 11.5),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  validator: (v) => v == null ? 'Please select a role' : null,
                  onChanged: (v) => setState(() => _selectedRole = v),
                  style: const TextStyle(color: _label, fontSize: 14),
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: Color(0xFFA6B2AB), size: 22),
                  decoration: _inputDeco('Select role', Icons.badge_outlined),
                  items: _adminRoles.entries
                      .map((e) =>
                          DropdownMenuItem(value: e.value, child: Text(e.key)))
                      .toList(),
                ),
                const SizedBox(height: 20),
                _sectionLabel('Note (optional)'),
                const SizedBox(height: 8),
                _textField(
                  controller: _noteCtrl,
                  hint: 'Preferred city / area, anything Super Admin should know',
                  icon: Icons.edit_note_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 28),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Already have an account?',
                          style: TextStyle(color: Colors.grey, fontSize: 12)),
                      const SizedBox(width: 2),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const UniversalLoginScreen()),
                        ),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Login',
                            style: TextStyle(
                              color: _navy,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                            )),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: _navy,
                      disabledBackgroundColor: _amber.withValues(alpha: 0.5),
                      elevation: 0,
                      shape:
                          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: _navy, strokeWidth: 2.5))
                        : const Text('Submit Request',
                            style:
                                TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminSignUp(prefillEmail: ''),
                      ),
                    ),
                    child: const Text('I already have a passcode',
                        style: TextStyle(
                            color: _sub, fontSize: 13, fontWeight: FontWeight.w600)),
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

  Widget _sectionLabel(String text) => Text(text,
      style: const TextStyle(
        color: _label,
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        maxLines: maxLines,
        validator: validator,
        style: const TextStyle(color: Color(0xFF1F2A26), fontSize: 14),
        decoration: _inputDeco(hint, icon),
      );

  InputDecoration _inputDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA6B2AB), fontSize: 13.5),
        prefixIcon: Icon(icon, color: const Color(0xFFA6B2AB), size: 20),
        filled: true,
        fillColor: const Color(0xFFF7F5EF),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE3E0D5))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFC9A227), width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.redAccent)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        errorStyle: const TextStyle(fontSize: 12),
      );
}

// =============================================================================
// _RequestSubmittedScreen — confirmation only, carries NOTHING trustable
// (no city, no area, no passcode — just the email, for prefill convenience)
// =============================================================================
class _RequestSubmittedScreen extends StatelessWidget {
  final String email;
  final String role;

  const _RequestSubmittedScreen({required this.email, required this.role});

  @override
  Widget build(BuildContext context) {
    const Color navy = Color(0xFF0E3B2E);
    const Color amber = Color(0xFFC9A227);
    const Color white = Color(0xFFFFFFFF);
    const Color label = Color(0xFF1F2A26);
    const Color sub = Color(0xFF5D6B64);
    const Color fill = Color(0xFFF7F5EF);

    final roleLabel = _adminRoles.entries
        .firstWhere((e) => e.value == role, orElse: () => const MapEntry('', ''))
        .key;

    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        backgroundColor: navy,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Request Submitted',
            style:
                TextStyle(color: white, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.mark_email_read_rounded,
                    color: Color(0xFF0E3B2E), size: 42),
              ),
              const SizedBox(height: 22),
              const Text('Request Received!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: label,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3)),
              const SizedBox(height: 8),
              Text(
                'Your ${roleLabel.isEmpty ? "" : "$roleLabel "}access request has been sent to Super Admin for review.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: sub, fontSize: 13.5, height: 1.55),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE3E0D5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('WHAT HAPPENS NEXT',
                        style: TextStyle(
                            color: sub,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2)),
                    SizedBox(height: 14),
                    _NextStep(
                        number: '1',
                        icon: Icons.admin_panel_settings_outlined,
                        text:
                            'Super Admin reviews your request and decides your city, area, and designation.'),
                    _NextStep(
                        number: '2',
                        icon: Icons.vpn_key_outlined,
                        text:
                            'Super Admin generates a passcode bound to those details and shares it with you privately.'),
                    _NextStep(
                        number: '3',
                        icon: Icons.how_to_reg_rounded,
                        text:
                            'You enter that passcode on the signup screen to complete registration.',
                        isLast: true),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdminSignUp(prefillEmail: email),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: amber,
                    foregroundColor: navy,
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('I have my passcode — Continue',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
                child:
                    const Text('Back to Home', style: TextStyle(color: sub, fontSize: 13.5)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _SecurityBadge extends StatelessWidget {
  const _SecurityBadge();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFC9A227).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline_rounded, color: Color(0xFFC9A227), size: 14),
            SizedBox(width: 6),
            Text('Secure Registry Portal',
                style: TextStyle(
                    color: Color(0xFFC9A227), fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _HowItWorksCard extends StatelessWidget {
  const _HowItWorksCard();
  @override
  Widget build(BuildContext context) {
    const steps = [
      'Submit your name, email, phone, and requested role',
      'Super Admin reviews your request manually',
      'Super Admin decides your real city, area, and designation and issues a passcode',
      'You enter the passcode on the signup screen — those fields are locked to what Super Admin set',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F2ED),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFE5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF1A5C46), size: 15),
              SizedBox(width: 6),
              Text('How admin registration works',
                  style: TextStyle(
                      color: Color(0xFF1A5C46), fontSize: 12.5, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A5C46).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text('${e.key + 1}',
                            style: const TextStyle(
                                color: Color(0xFF1A5C46),
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(e.value,
                          style: const TextStyle(
                              color: Color(0xFF0E3B2E), fontSize: 12.5, height: 1.5)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _NextStep extends StatelessWidget {
  final String number;
  final IconData icon;
  final String text;
  final bool isLast;

  const _NextStep({
    required this.number,
    required this.icon,
    required this.text,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF0E3B2E).withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(number,
                    style: const TextStyle(
                        color: Color(0xFF0E3B2E), fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Icon(icon, color: const Color(0xFF5D6B64), size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style:
                    const TextStyle(color: Color(0xFF1F2A26), fontSize: 13, height: 1.45),
              ),
            ),
          ],
        ),
      );
}
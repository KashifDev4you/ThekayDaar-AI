// =============================================================================
// super_admin_issue_passcode_screen.dart — NEW
//
// This is the ONLY screen that should ever write to admin_passcodes/.
// Super Admin picks designation + city + (area, if Area Handler) here.
// Nothing on a registrant's device writes to this collection.
//
// Pairs with: access_requests/ (written by admin_location_screen.dart)
//             admin_passcodes/ (read + redeemed by admin_signUp_Screen.dart)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const Color _navy = Color(0xFF0E3B2E);
const Color _amber = Color(0xFFC9A227);
const Color _white = Color(0xFFFFFFFF);
const Color _label = Color(0xFF1F2A26);
const Color _sub = Color(0xFF5D6B64);
const Color _border = Color(0xFFE3E0D5);
const Color _fill = Color(0xFFF7F5EF);
const Color _green = Color(0xFF10B981);
const Color _red = Color(0xFFDC2626);

const Map<String, String> _designationToRole = {
  'Regional Manager': 'RegionalAdmin',
  'Area Handler': 'AreaHandler',
  'Support Desk': 'SupportDesk',
};

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

class SuperAdminIssuePasscodeScreen extends StatefulWidget {
  const SuperAdminIssuePasscodeScreen({super.key});

  @override
  State<SuperAdminIssuePasscodeScreen> createState() =>
      _SuperAdminIssuePasscodeScreenState();
}

class _SuperAdminIssuePasscodeScreenState
    extends State<SuperAdminIssuePasscodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();

  String? _selectedDesignation;
  String? _selectedCity;
  String? _selectedArea;
  String? _fulfillingRequestId; // set when generating from a pending request

  bool _isLoading = false;
  Map<String, dynamic>? _lastIssued;

  List<String> get _areasForCity => _cityAreas[_selectedCity] ?? [];

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _prefillFromRequest(QueryDocumentSnapshot<Map<String, dynamic>> req) {
    final data = req.data();
    setState(() {
      _fulfillingRequestId = req.id;
      _emailCtrl.text = (data['email'] ?? '').toString();
      final requestedRole = (data['requestedRole'] ?? '').toString();
      final match = _designationToRole.entries.firstWhere(
        (e) => e.value == requestedRole,
        orElse: () => const MapEntry('', ''),
      );
      _selectedDesignation = match.key.isEmpty ? null : match.key;
      _selectedCity = null;
      _selectedArea = null;
    });
  }

  /// Generates a passcode string and guarantees it doesn't collide with an
  /// existing doc — retries with a fresh suffix up to 5 times before giving
  /// up loudly instead of silently overwriting something.
  Future<String> _generateUniquePasscode({
    required String city,
    required String area,
  }) async {
    final db = FirebaseFirestore.instance;
    final cityPart = city
        .toUpperCase()
        .replaceAll(RegExp(r'[\s/]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'[^A-Z0-9\-]'), '');
    final areaPart = area
        .toUpperCase()
        .replaceAll(RegExp(r'[\s/]'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'[^A-Z0-9\-]'), '');

    for (int attempt = 0; attempt < 5; attempt++) {
      final suffix =
          (1000 + DateTime.now().microsecondsSinceEpoch % 9000).toString();
      final candidate = '$cityPart-$areaPart-$suffix';
      final existing =
          await db.collection('admin_passcodes').doc(candidate).get();
      if (!existing.exists) return candidate;
      await Future.delayed(const Duration(milliseconds: 30));
    }
    throw Exception(
        'Could not generate a unique passcode after 5 attempts. Try again.');
  }

  Future<void> _issuePasscode() async {
    if (!_formKey.currentState!.validate()) return;

    final designation = _selectedDesignation;
    final city = _selectedCity;
    final role = designation == null ? null : _designationToRole[designation];
    final email = _emailCtrl.text.trim().toLowerCase();

    if (designation == null || role == null) {
      _snack('Please select a designation.', _red);
      return;
    }
    if (city == null || city.isEmpty) {
      _snack('Please select a city.', _red);
      return;
    }

    // Area Handler MUST have a real sub-area. Others get a fixed scope label
    // so 'area' is never null/empty downstream.
    String area;
    if (role == 'AreaHandler') {
      if (_selectedArea == null || _selectedArea!.isEmpty) {
        _snack('Please select an area for an Area Handler.', _red);
        return;
      }
      area = _selectedArea!;
    } else {
      area = role == 'RegionalAdmin' ? 'Regional' : 'Support';
    }

    setState(() => _isLoading = true);

    try {
      final db = FirebaseFirestore.instance;
      final code = await _generateUniquePasscode(city: city, area: area);
      final superAdminUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final superAdminEmail =
          FirebaseAuth.instance.currentUser?.email ?? 'unknown';

      final batch = db.batch();

      batch.set(db.collection('admin_passcodes').doc(code), {
        'isUsed': false,
        'status': 'issued',
        'designation': designation,
        'role': role,
        'city': city,
        'area': area,
        'issuedTo': email,
        'issuedByUid': superAdminUid,
        'issuedByEmail': superAdminEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (_fulfillingRequestId != null) {
        batch.update(
          db.collection('access_requests').doc(_fulfillingRequestId),
          {
            'status': 'fulfilled',
            'fulfilledWithPasscode': code,
            'fulfilledAt': FieldValue.serverTimestamp(),
          },
        );
      }

      await batch.commit();

      if (!mounted) return;
      setState(() {
        _lastIssued = {
          'code': code,
          'designation': designation,
          'city': city,
          'area': area,
          'email': email,
        };
        _fulfillingRequestId = null;
        _selectedDesignation = null;
        _selectedCity = null;
        _selectedArea = null;
        _emailCtrl.clear();
      });
      _snack('Passcode issued and saved to Firestore.', _green);
    } catch (e) {
      if (!mounted) return;
      _snack('Failed to issue passcode: $e', _red);
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
        title: const Text('Issue Admin Passcode',
            style:
                TextStyle(color: _white, fontSize: 17, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_lastIssued != null) ...[
                _IssuedPasscodeCard(data: _lastIssued!),
                const SizedBox(height: 24),
              ],

              const _SectionHeader(label: 'Pending Requests', icon: Icons.inbox_rounded),
              const SizedBox(height: 10),
              _PendingRequestsList(onPick: _prefillFromRequest),
              const SizedBox(height: 28),

              const Divider(color: _border),
              const SizedBox(height: 20),

              const _SectionHeader(
                  label: 'Generate Passcode Manually', icon: Icons.vpn_key_rounded),
              const SizedBox(height: 14),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label2('Email of registrant'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      inputFormatters: [
                        FilteringTextInputFormatter.deny(RegExp(r'\s')),
                      ],
                      style: const TextStyle(color: _label, fontSize: 14),
                      decoration:
                          _deco('admin@thekaydaar.pk', Icons.mail_outline_rounded),
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
                    const SizedBox(height: 16),
                    _label2('Designation'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedDesignation,
                      validator: (v) => v == null ? 'Select a designation' : null,
                      onChanged: (v) => setState(() {
                        _selectedDesignation = v;
                        _selectedArea = null;
                      }),
                      style: const TextStyle(color: _label, fontSize: 14),
                      decoration:
                          _deco('Select designation', Icons.assignment_ind_outlined),
                      items: _designationToRole.keys
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                    _label2('City'),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCity,
                      validator: (v) => v == null ? 'Select a city' : null,
                      onChanged: (v) => setState(() {
                        _selectedCity = v;
                        _selectedArea = null;
                      }),
                      style: const TextStyle(color: _label, fontSize: 14),
                      decoration: _deco('Select city', Icons.location_city_outlined),
                      items: _allCities
                          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                    ),
                    if (_selectedDesignation == 'Area Handler' &&
                        _selectedCity != null) ...[
                      const SizedBox(height: 16),
                      _label2('Area'),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedArea,
                        validator: (v) => v == null ? 'Select an area' : null,
                        onChanged: (v) => setState(() => _selectedArea = v),
                        style: const TextStyle(color: _label, fontSize: 14),
                        decoration: _deco('Select area', Icons.map_outlined),
                        items: _areasForCity
                            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _issuePasscode,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _amber,
                          foregroundColor: _navy,
                          disabledBackgroundColor: _amber.withValues(alpha: 0.5),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    color: _navy, strokeWidth: 2.5))
                            : const Text('Generate & Save Passcode',
                                style:
                                    TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label2(String text) => Text(text,
      style: const TextStyle(color: _label, fontSize: 13, fontWeight: FontWeight.w700));

  InputDecoration _deco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA6B2AB), fontSize: 13.5),
        prefixIcon: Icon(icon, color: const Color(0xFFA6B2AB), size: 20),
        filled: true,
        fillColor: _fill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: _amber, width: 1.5)),
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
// Pending requests — live list from access_requests/
// =============================================================================
class _PendingRequestsList extends StatelessWidget {
  final void Function(QueryDocumentSnapshot<Map<String, dynamic>>) onPick;
  const _PendingRequestsList({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('access_requests')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (snapshot.hasError) {
          return Text('Failed to load requests: ${snapshot.error}',
              style: const TextStyle(color: _red, fontSize: 12.5));
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('No pending requests.',
                style: TextStyle(color: _sub, fontSize: 13)),
          );
        }
        return Column(
          children: docs.map((d) {
            final data = d.data();
            final name = (data['fullName'] ?? '—').toString();
            final email = (data['email'] ?? '—').toString();
            final role = (data['requestedRole'] ?? '—').toString();
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name,
                            style: const TextStyle(
                                color: _label, fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text('$email · requested: $role',
                            style: const TextStyle(color: _sub, fontSize: 11.5)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => onPick(d),
                    child: const Text('Use this',
                        style: TextStyle(
                            color: _amber, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _IssuedPasscodeCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _IssuedPasscodeCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final code = data['code'] as String;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFD1FAE5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFCFE5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PASSCODE ISSUED — SHARE PRIVATELY',
              style: TextStyle(
                  color: Color(0xFF0E3B2E),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(code,
                    style: const TextStyle(
                        color: Color(0xFF1A5C46),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        letterSpacing: 1)),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, color: Color(0xFF0E3B2E), size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Passcode copied')),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${data['designation']} · ${data['city']} · ${data['area']}\nFor: ${data['email']}',
            style: const TextStyle(color: Color(0xFF0E3B2E), fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionHeader({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, color: _navy, size: 16),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: _label, fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      );
}
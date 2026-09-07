import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// =============================================================================
// AccountScreen — Area Handler Profile
//
// EDITABLE by the handler:
//   ✅ fullName      (display name)
//   ✅ phone         (contact number)
//   ✅ password      (via Firebase Auth re-auth)
//
// READ-ONLY (set by Super Admin — handler cannot change):
//   🔒 email             (auth identity)
//   🔒 operationalCity   (assigned by Super Admin)
//   🔒 assignedArea      (assigned by Super Admin)
//   🔒 role              (always "AreaHandler")
//   🔒 status            (active / suspended — controlled by Super Admin)
//
// SUSPENSION:
//   • StreamBuilder watches the handler's Firestore doc in real-time.
//   • If status flips to 'suspended' while this screen is open,
//     they are immediately signed out and sent to /login.
// =============================================================================

class AccountScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const AccountScreen({super.key, required this.userData});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const Color _navy = Color(0xFF0E3B2E);
  static const Color _amber = Color(0xFFC9A227);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _bg = Color(0xFFF7F5EF);

  final String? _uid = FirebaseAuth.instance.currentUser?.uid;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final TextEditingController _currentPassCtrl = TextEditingController();
  final TextEditingController _newPassCtrl = TextEditingController();
  final TextEditingController _confirmPassCtrl = TextEditingController();

  bool _isSaving = false;
  bool _isChangingPass = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _suspendedShown = false;

  final _profileKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: widget.userData['fullName'] as String? ?? '',
    );
    _phoneCtrl = TextEditingController(
      text: widget.userData['phone'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  // ── Save name + phone ────────────────────────────────────────
  Future<void> _saveProfile() async {
    if (!_profileKey.currentState!.validate()) return;
    if (_uid == null) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc('area_handler')
          .collection('members')
          .doc(_uid)
          .update({
            'fullName': _nameCtrl.text.trim(),
            'phone': _phoneCtrl.text.trim(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      _snack('Profile updated.', const Color(0xFF10B981));
    } catch (e) {
      _snack('Save failed: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Change password ──────────────────────────────────────────
  Future<void> _changePassword() async {
    if (!_passwordKey.currentState!.validate()) return;
    setState(() => _isChangingPass = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentPassCtrl.text,
      );
      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(_newPassCtrl.text);
      _currentPassCtrl.clear();
      _newPassCtrl.clear();
      _confirmPassCtrl.clear();
      _snack('Password changed successfully.', const Color(0xFF10B981));
    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'wrong-password' => 'Current password is incorrect.',
        'weak-password' => 'New password is too weak (min 6 chars).',
        'requires-recent-login' => 'Sign out and sign back in, then try again.',
        _ => 'Error: ${e.message}',
      };
      _snack(msg, Colors.redAccent);
    } catch (e) {
      _snack('Something went wrong: $e', Colors.redAccent);
    } finally {
      if (mounted) setState(() => _isChangingPass = false);
    }
  }

  // ── Suspension dialog + force sign-out ──────────────────────
  Future<void> _handleSuspension() async {
    if (_suspendedShown || !mounted) return;
    _suspendedShown = true;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
        contentPadding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
        actionsPadding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.block_rounded,
                color: Colors.redAccent,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Account Suspended',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: const Text(
          'Your account has been suspended by the Super Admin.\n\n'
          'You have been signed out. Contact support if you believe '
          'this is a mistake.',
          style: TextStyle(
            fontSize: 13.5,
            color: Color(0xFF5D6B64),
            height: 1.55,
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            child: const Text('OK, Sign Out'),
          ),
        ],
      ),
    );
    if (mounted) {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
      }
    }
  }

  void _snack(String msg, Color bg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(color: _white, fontSize: 13),
          ),
          backgroundColor: bg,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================
  @override
  Widget build(BuildContext context) {
    if (_uid == null) {
      return const Scaffold(body: Center(child: Text('Not authenticated')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admins')
          .doc('area_handler')
          .collection('members')
          .doc(_uid)
          .snapshots(),
      builder: (context, snap) {
        // Real-time suspension check
        if (snap.hasData && snap.data!.exists) {
          final live = snap.data!.data() as Map<String, dynamic>;
          final status = live['status'] as String? ?? 'active';
          if (status == 'suspended') {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _handleSuspension(),
            );
          }
        }

        return Scaffold(
          backgroundColor: _bg,
          appBar: AppBar(
            backgroundColor: _navy,
            foregroundColor: _white,
            elevation: 0,
            title: const Text(
              'My Profile',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // ── Avatar header ──────────────────────────────
              _AvatarHeader(
                name: _nameCtrl.text.isNotEmpty
                    ? _nameCtrl.text
                    : (widget.userData['fullName'] as String? ??
                          'Area Handler'),
                email: widget.userData['email'] as String? ?? 'N/A',
              ),
              const SizedBox(height: 24),

              // ── READ-ONLY section ──────────────────────────
              _SectionCard(
                title: 'Assigned by Super Admin',
                subtitle: 'These fields cannot be changed by you',
                icon: Icons.lock_outline_rounded,
                iconColor: Colors.redAccent,
                children: [
                  _ReadOnlyField(
                    label: 'Role',
                    value: 'Area Handler',
                    icon: Icons.badge_rounded,
                  ),
                  _ReadOnlyField(
                    label: 'Operational City',
                    value:
                        widget.userData['operationalCity'] as String? ??
                        'Not assigned',
                    icon: Icons.location_city_rounded,
                  ),
                  _ReadOnlyField(
                    label: 'Assigned Area',
                    value:
                        widget.userData['assignedArea'] as String? ??
                        'Not assigned',
                    icon: Icons.map_rounded,
                  ),
                  _ReadOnlyField(
                    label: 'Email',
                    value: widget.userData['email'] as String? ?? 'N/A',
                    icon: Icons.mail_outline_rounded,
                  ),
                  _ReadOnlyField(
                    label: 'Account Status',
                    value: (widget.userData['status'] as String? ?? 'active')
                        .toUpperCase(),
                    icon: Icons.verified_user_rounded,
                    valueColor:
                        (widget.userData['status'] as String? ?? 'active') ==
                            'active'
                        ? const Color(0xFF10B981)
                        : Colors.redAccent,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── EDITABLE section ───────────────────────────
              _SectionCard(
                title: 'Edit Your Info',
                subtitle: 'Name and phone number are yours to update',
                icon: Icons.edit_rounded,
                iconColor: _amber,
                children: [
                  Form(
                    key: _profileKey,
                    child: Column(
                      children: [
                        _EditableField(
                          label: 'Full Name',
                          controller: _nameCtrl,
                          icon: Icons.person_outline_rounded,
                          validator: (v) => (v ?? '').trim().isEmpty
                              ? 'Name cannot be empty'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _EditableField(
                          label: 'Phone Number',
                          controller: _phoneCtrl,
                          icon: Icons.phone_outlined,
                          keyboard: TextInputType.phone,
                          validator: (v) {
                            final val = (v ?? '').trim();
                            if (val.isEmpty) return 'Phone cannot be empty';
                            if (val.length < 10) {
                              return 'Enter a valid number';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: _navy,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded, size: 18),
                            label: Text(_isSaving ? 'Saving…' : 'Save Changes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _amber,
                              foregroundColor: _navy,
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── CHANGE PASSWORD section ────────────────────
              _SectionCard(
                title: 'Change Password',
                subtitle: 'Re-authentication required for security',
                icon: Icons.lock_reset_rounded,
                iconColor: const Color(0xFF0E3B2E),
                children: [
                  Form(
                    key: _passwordKey,
                    child: Column(
                      children: [
                        _PasswordField(
                          label: 'Current Password',
                          controller: _currentPassCtrl,
                          obscure: _obscureCurrent,
                          onToggle: () => setState(
                            () => _obscureCurrent = !_obscureCurrent,
                          ),
                          validator: (v) => (v ?? '').isEmpty
                              ? 'Enter your current password'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        _PasswordField(
                          label: 'New Password',
                          controller: _newPassCtrl,
                          obscure: _obscureNew,
                          onToggle: () =>
                              setState(() => _obscureNew = !_obscureNew),
                          validator: (v) {
                            if ((v ?? '').isEmpty) {
                              return 'Enter new password';
                            }
                            if (v!.length < 6) {
                              return 'Minimum 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        _PasswordField(
                          label: 'Confirm New Password',
                          controller: _confirmPassCtrl,
                          obscure: _obscureConfirm,
                          onToggle: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                          validator: (v) {
                            if ((v ?? '').isEmpty) {
                              return 'Confirm your password';
                            }
                            if (v != _newPassCtrl.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton.icon(
                            onPressed: _isChangingPass ? null : _changePassword,
                            icon: _isChangingPass
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      color: _white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_rounded, size: 18),
                            label: Text(
                              _isChangingPass ? 'Updating…' : 'Update Password',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0E3B2E),
                              foregroundColor: _white,
                              elevation: 0,
                              textStyle: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// SUB-WIDGETS
// =============================================================================

class _AvatarHeader extends StatelessWidget {
  final String name, email;
  const _AvatarHeader({required this.name, required this.email});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: const Color(0xFF0E3B2E),
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'A',
            style: const TextStyle(
              color: Color(0xFFC9A227),
              fontSize: 26,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1F2A26),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                email,
                style: const TextStyle(fontSize: 13, color: Color(0xFF5D6B64)),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E3B2E).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Area Handler',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0E3B2E),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E0D5)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1F2A26),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFFA6B2AB),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFF7F5EF)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? valueColor;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 17, color: const Color(0xFFA6B2AB)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFFA6B2AB),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? const Color(0xFF1F2A26),
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: Color(0xFFA9B5AE),
          ),
        ],
      ),
    );
  }
}

class _EditableField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;
  final TextInputType keyboard;
  final String? Function(String?) validator;

  const _EditableField({
    required this.label,
    required this.controller,
    required this.icon,
    required this.validator,
    this.keyboard = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboard,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2A26),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF5D6B64)),
        prefixIcon: Icon(icon, size: 19, color: const Color(0xFFA6B2AB)),
        filled: true,
        fillColor: const Color(0xFFF7F5EF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E0D5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFC9A227), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11.5),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final String? Function(String?) validator;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF1F2A26),
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF5D6B64)),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          size: 19,
          color: Color(0xFFA6B2AB),
        ),
        suffixIcon: IconButton(
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 19,
            color: const Color(0xFFA6B2AB),
          ),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF7F5EF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE3E0D5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0E3B2E), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11.5),
      ),
    );
  }
}

// =============================================================================
// super_admin_config.dart
//
// Single source of truth for Super Admin identity.
// Since there is always exactly ONE Super Admin (you), this is hardcoded.
// Set the email in your `.env` file as SUPER_ADMIN_EMAIL.
// =============================================================================

import 'package:ali_app/services/env_config.dart';

class SuperAdminConfig {
  SuperAdminConfig._(); // not instantiable

  // ── YOUR email — only this address can see pending admin requests ──
  static String get superAdminEmail => EnvConfig.get('SUPER_ADMIN_EMAIL');

  // ── Firestore collections ──────────────────────────────────────
  static const String passcodesCollection = 'admin_passcodes';
  static const String usersCollection     = 'users';

  // ── Check if a logged-in user is the Super Admin ──────────────
  static bool isSuperAdmin(String? email) {
    if (email == null) return false;
    return email.trim().toLowerCase() == superAdminEmail.toLowerCase();
  }
}

import 'package:ali_app/Client/client_profile.dart';
import 'package:ali_app/Client/client_rate_review.dart';
import 'package:ali_app/Client/post_project_screen.dart';
import 'package:ali_app/Theekaydaar/browse_projects_screen.dart';
import 'package:ali_app/Theekaydaar/thekaydaar_active_jobs.dart';
import 'package:ali_app/admin/Login_Signup/admin_login_screen.dart';
import 'package:ali_app/admin/Regional_Admin/regional_admin_dashboard.dart';
import 'package:ali_app/admin/Super_admin/Super_admin_dashboard/super_admin_requests_screen.dart';
import 'package:ali_app/admin/Super_admin/super_admin_login_screen.dart';
import 'package:ali_app/admin/support_desk/support_desk_dashboard.dart';
import 'package:ali_app/onboardingScreens/onboarding_screen.dart';
import 'package:ali_app/scripts/seed_help_support.dart' show seedHelpSupport;
import 'package:ali_app/ui/auth/login_screen.dart';
import 'package:ali_app/ui/material_estimator_screen.dart';
import 'package:ali_app/ui/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'Theekaydaar/theekaydaar.dart';
import 'admin/Login_Signup/admin_location_screen.dart';
import 'ui/auth/sign_up.dart';
import 'Client/client.dart';
import 'Theekaydaar/thekaydaar_profile.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:ali_app/services/env_config.dart';
import 'package:ali_app/house_planner/screens/create_project_wizard.dart';
import 'package:ali_app/Widgets/connectivity_wrapper.dart';
import 'package:ali_app/utils/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables before anything else so Firebase, Gemini,
  // Cloudinary and other configured services can read their secrets.
  await EnvConfig.load();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await seedHelpSupport();
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: false,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('[Firestore] Settings already set: $e');
  }

  runApp(const MyApp());

  // ── DEBUG: auto-activate premium plan for testing ────────────
  // TODO: REMOVE after testing — activates Business (contractor)
  //       and Premium (client) plan for the logged-in user.
  debugActivatePremium();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        // ── Core ──────────────────────────────────────────────
        '/splash_screen': (_) => const SplashScreen(),
        '/OnboardingScreen': (_) => const OnboardingScreen(),
        '/HomeScreen': (_) => const HomeScreen(),

        // ── Auth ──────────────────────────────────────────────
        '/login': (_) => const LoginScreen(),
        '/signup': (_) => SignUp(role: _RoleList.selectedRole),

        // ── Client ────────────────────────────────────────────
        '/Client': (_) => const ClientScreen(),
        '/post_project': (_) => const PostProjectScreen(),
        '/client_completed_jobs': (_) => const ClientCompletedJobsScreen(),

        // ── Thekaydaar ────────────────────────────────────────
        '/thekaydaar': (_) => const Thekaydaar(),
        '/browse_projects': (_) => const BrowseProjectsScreen(),
        '/active_jobs': (_) => const ThekaydaarActiveJobsScreen(),

        // ── Admin ─────────────────────────────────────────────
        '/admin_login': (_) => const UniversalLoginScreen(),
        '/admin_location': (_) => const AdminLocationScreen(),
        '/super_admin_login': (_) => const SuperAdminLoginScreen(),
        '/super_admin_dashboard': (_) => const SuperAdminRequestsScreen(),
        '/regional_admin_dashboard': (_) => const RegionalAdminDashboard(
          adminName: '',
          adminCity: '',
          userData: {},
        ),
        '/support_desk_dashboard': (_) => const SupportDeskDashboard(),
        '/material_estimator': (_) => const MaterialEstimatorScreen(),

        // ── AI House Planner ───────────────────────────────────
        '/create_project': (_) => const CreateProjectWizard(),

        // ── Profiles ──────────────────────────────────────────
        '/thekaydaar_profile': (_) => const ThekaydaarProfileScreen(),
        '/client_profile': (_) => const ClientProfileScreen(),
      },
      builder: (context, child) {
        return ConnectivityWrapper(child: child ?? const SizedBox.shrink());
      },
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const SplashScreen(),
    );
  }
}

// =============================================================================
// HOME SCREEN
// =============================================================================
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Expanded(child: _RoleList()),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 36, 24, 36),
      decoration: const BoxDecoration(
        color: AppTheme.navy,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppTheme.amber,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'THEKAYDAAR.PK',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2.5,
                    color: AppTheme.amber,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Apna role\nselect karain',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose how you want to use the platform',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleList extends StatefulWidget {
  const _RoleList();
  static String selectedRole = '';

  @override
  State<_RoleList> createState() => _RoleListState();
}

class _RoleListState extends State<_RoleList> {
  String _selectedRole = '';

  void _handleRoleSelection(String role) {
    setState(() {
      _selectedRole = role;
      _RoleList.selectedRole = role;
    });

    Future.delayed(const Duration(milliseconds: 220), () {
      if (!mounted) return;
      if (role == 'Admin') {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminLocationScreen()),
        );
      } else {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SignUp(role: role)),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'I AM A…',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            title: 'Client / Maalik',
            subtitle: 'Build a house, hire contractors, or post projects.',
            icon: Icons.home_work_rounded,
            isSelected: _selectedRole == 'Client',
            onTap: () => _handleRoleSelection('Client'),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            title: 'Contractor / ThekayDaar',
            subtitle: 'Find construction leads, bid on jobs, and grow.',
            icon: Icons.engineering_rounded,
            isSelected: _selectedRole == 'Contractor',
            onTap: () => _handleRoleSelection('Contractor'),
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Divider(color: AppTheme.border, thickness: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 16,
                ),
                child: Text(
                  'Admin Registration',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppTheme.textMuted,
                  ),
                ),
              ),
              const Expanded(
                child: Divider(color: AppTheme.border, thickness: 1),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _RoleCard(
            title: 'Official Admin / Staff',
            subtitle: 'Manage the platform and oversee all activities.',
            icon: Icons.admin_panel_settings_rounded,
            isSelected: _selectedRole == 'Admin',
            onTap: () => _handleRoleSelection('Admin'),
          ),
          const SizedBox(height: 20),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  "Already have an account?",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 2),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const UniversalLoginScreen(),
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Login',
                    style: TextStyle(
                      color: AppTheme.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final IconData icon;
  final String title, subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: widget.isSelected
              ? AppTheme.goldSoft
              : (_pressed ? AppTheme.bg : AppTheme.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected ? AppTheme.gold : AppTheme.border,
            width: widget.isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppTheme.gold
                    : AppTheme.emeraldSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                widget.icon,
                size: 24,
                color: widget.isSelected ? Colors.white : AppTheme.navy,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.isSelected
                          ? AppTheme.amberDark
                          : AppTheme.textBody,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppTheme.amber.withValues(alpha: 0.12)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: widget.isSelected
                    ? AppTheme.gold
                    : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _TrustBadge(icon: Icons.verified_rounded, label: 'Verified'),
              const _Dot(),
              _TrustBadge(icon: Icons.lock_rounded, label: 'Secure'),
              const _Dot(),
              _TrustBadge(
                icon: Icons.workspace_premium_rounded,
                label: 'Pakistan',
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '© 2026 ThekayDaar.pk',
            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _TrustBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 13, color: AppTheme.textMuted),
      const SizedBox(width: 4),
      Text(
        label,
        style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
      ),
    ],
  );
}

class _Dot extends StatelessWidget {
  const _Dot();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(horizontal: 8),
    child: Text('•', style: TextStyle(color: AppTheme.border, fontSize: 10)),
  );
}

// =============================================================================
// DEBUG ONLY — Activate Business + Premium plan for the logged-in user.
// REMOVE THIS ENTIRE FUNCTION after testing.
// =============================================================================
void debugActivatePremium() async {
  await Future.delayed(const Duration(seconds: 5)); // wait for app to settle
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    debugPrint('[DEBUG] No user logged in — skipping plan activation.');
    return;
  }
  final db = FirebaseFirestore.instance;

  try {
    // ── Activate Business plan on thekaydaars collection ──────
    final tkDoc = await db.collection('thekaydaars').doc(uid).get();
    if (tkDoc.exists) {
      await db.collection('thekaydaars').doc(uid).set({
        'isPremium': true,
        'planName': 'Business',
        'bidsRemaining': 40,
        'bidsTotal': 40,
        'canBid': true,
        'canPostGig': true,
        'verifiedBadge': true,
        'featuredListing': true,
        'canUseAiTools': true,
        'canUseMaterialEstimator': true,
        'canAccessChat': true,
        'canViewAnalytics': true,
        'prioritySupport': true,
        'planActivatedAt': FieldValue.serverTimestamp(),
        'paymentPending': false,
      }, SetOptions(merge: true));
      debugPrint('✅ [DEBUG] thekaydaars/$uid → Business plan ACTIVATED');
    }

    // ── Activate Premium plan on clients collection ───────────
    final clDoc = await db.collection('clients').doc(uid).get();
    if (clDoc.exists) {
      await db.collection('clients').doc(uid).set({
        'isPremium': true,
        'planName': 'Premium',
        'projectsRemaining': 999,
        'bidsViewLimit': 999,
        'premiumFeatures': true,
        'verifiedBadge': true,
        'canUseAiTools': true,
        'canAccessChat': true,
        'prioritySupport': true,
        'planActivatedAt': FieldValue.serverTimestamp(),
        'paymentPending': false,
      }, SetOptions(merge: true));
      debugPrint('✅ [DEBUG] clients/$uid → Premium plan ACTIVATED');
    }

    if (!tkDoc.exists && !clDoc.exists) {
      debugPrint('⚠️ [DEBUG] User not found in thekaydaars or clients collection.');
    }
  } catch (e) {
    debugPrint('❌ [DEBUG] Plan activation failed: $e');
  }
}

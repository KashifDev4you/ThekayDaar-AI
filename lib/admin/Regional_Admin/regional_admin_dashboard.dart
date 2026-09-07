// =============================================================================
// regional_admin_dashboard.dart
//
// SCREENS IN THIS FILE:
//   1. RegionalAdminDashboard        — main hub with stat cards + feature cards
//   2. AreaHandlerManagementScreen   — full CRUD for area handlers
//   3. CityStatsScreen               — revenue, users, contractors, bookings
//   4. EscalationsScreen             — cross-area case management
//   5. OverrideScreen                — override area handler decisions
//   6. RegionalAdminProfileScreen    — view & edit own profile + change password
//   7. _AreaDetailScreen             — clients + contractors per handler's area
//
// FIRESTORE COLLECTIONS READ:
//   admins/area_handler/members      — area handlers (operationalCity)
//   clients                          — clients (city + area)
//   thekaydaars                      — contractors (city + area)
//   city_stats/{city}                — revenue, user growth, disputes
//   escalations                      — cross-area escalations
//   bookings                         — booking counts
// =============================================================================

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/utils/app_theme.dart';

// ── Palette ───────────────────────────────────────────────────────────────────
const Color _navy    = Color(0xFF0E3B2E);
const Color _navy2   = Color(0xFF1F2A26);
const Color _amber   = Color(0xFFC9A227);
const Color _white   = Color(0xFFFFFFFF);
const Color _surface = Color(0xFFF7F5EF);
const Color _border  = Color(0xFFE3E0D5);
const Color _sub     = Color(0xFF5D6B64);
const Color _label   = Color(0xFF1F2A26);

const Color _green  = AppTheme.emerald;
const Color _red    = Color(0xFFDC2626);
const Color _blue   = AppTheme.emeraldMid;
const Color _purple = AppTheme.goldDark;

// =============================================================================
// 1. REGIONAL ADMIN DASHBOARD
// =============================================================================
class RegionalAdminDashboard extends StatefulWidget {
  final String adminName;
  final String adminCity;
  final Map<String, dynamic> userData;

  const RegionalAdminDashboard({
    super.key,
    required this.adminName,
    required this.adminCity,
    required this.userData,
  });

  @override
  State<RegionalAdminDashboard> createState() =>
      _RegionalAdminDashboardState();
}

class _RegionalAdminDashboardState
    extends State<RegionalAdminDashboard> {
  int _handlerCount    = 0;
  int _bookingCount    = 0;
  int _escalationCount = 0;
  int _contractorCount = 0;
  bool _loading        = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  // Load quick-stat counts for the dashboard header
  Future<void> _loadSummary() async {
    final db   = FirebaseFirestore.instance;
    final city = widget.adminCity;

    // Guard: city must be non-empty before querying
    if (city.trim().isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final results = await Future.wait([
        // Count area handlers in this city
        db
            .collection('admins')
            .doc('area_handler')
            .collection('members')
            .where('operationalCity', isEqualTo: city)
            .count()
            .get(),
        // Count bookings in this city
        db
            .collection('bookings')
            .where('city', isEqualTo: city)
            .count()
            .get(),
        // Count open escalations in this city
        db
            .collection('escalations')
            .where('city', isEqualTo: city)
            .where('status', isEqualTo: 'open')
            .count()
            .get(),
        // Count contractors in this city
        db
            .collection('thekaydaars')
            .where('city', isEqualTo: city)
            .count()
            .get(),
      ]);

      if (!mounted) return;
      setState(() {
        _handlerCount    = results[0].count ?? 0;
        _bookingCount    = results[1].count ?? 0;
        _escalationCount = results[2].count ?? 0;
        _contractorCount = results[3].count ?? 0;
        _loading         = false;
      });
    } catch (e) {
      debugPrint('[Dashboard] Summary load error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final greeting = _greeting();

    return Scaffold(
      backgroundColor: _surface,
      body: SafeArea(
        child: RefreshIndicator(
          color: _amber,
          onRefresh: _loadSummary,
          child: CustomScrollView(
            slivers: [

              // ── Gradient header ────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_navy, _navy2],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding:
                      const EdgeInsets.fromLTRB(24, 20, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          // Role badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _amber.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(20),
                              border: Border.all(
                                  color: _amber.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.shield_outlined,
                                    color: _amber, size: 12),
                                const SizedBox(width: 5),
                                Text(
                                  'Regional Admin · ${widget.adminCity}',
                                  style: const TextStyle(
                                    color: _amber,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            children: [
                              // Navigate to own profile
                              IconButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        RegionalAdminProfileScreen(
                                      userData : widget.userData,
                                      adminCity: widget.adminCity,
                                    ),
                                  ),
                                ),
                                icon: const Icon(
                                    Icons.account_circle_outlined,
                                    color: Colors.white70,
                                    size: 22),
                                tooltip: 'My Profile',
                              ),
                              IconButton(
                                onPressed: _signOut,
                                icon: const Icon(
                                    Icons.logout_rounded,
                                    color: Colors.white54,
                                    size: 20),
                                tooltip: 'Sign Out',
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(greeting,
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(widget.adminName,
                          style: const TextStyle(
                            color: _white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          )),
                      const SizedBox(height: 20),

                      // Quick stat row — shows live counts
                      if (_loading)
                        const Center(
                            child: CircularProgressIndicator(
                                color: _amber, strokeWidth: 2))
                      else
                        Row(
                          children: [
                            _QuickStat(
                                label: 'Handlers',
                                value: '$_handlerCount',
                                icon:
                                    Icons.people_alt_outlined),
                            _vDivider(),
                            _QuickStat(
                                label: 'Bookings',
                                value: '$_bookingCount',
                                icon: Icons
                                    .calendar_today_outlined),
                            _vDivider(),
                            _QuickStat(
                                label: 'Open Cases',
                                value: '$_escalationCount',
                                icon: Icons
                                    .warning_amber_outlined,
                                highlight:
                                    _escalationCount > 0),
                            _vDivider(),
                            _QuickStat(
                                label: 'Contractors',
                                value: '$_contractorCount',
                                icon:
                                    Icons.handyman_outlined),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // ── Feature cards ──────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const _SectionHeading('Management'),
                    const SizedBox(height: 12),

                    // Area Handlers card
                    _FeatureCard(
                      icon     : Icons.people_alt_rounded,
                      iconBg   : _blue,
                      title    : 'Area Handlers',
                      subtitle :
                          'Hire, assign areas, edit profiles, suspend or remove handlers across ${widget.adminCity}.',
                      stat     : '$_handlerCount active',
                      statColor: _blue,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              AreaHandlerManagementScreen(
                            adminCity: widget.adminCity,
                            adminData: widget.userData,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Override Decisions card
                    _FeatureCard(
                      icon     : Icons.gavel_rounded,
                      iconBg   : _purple,
                      title    : 'Override Decisions',
                      subtitle :
                          'Review and override area handler decisions escalated for your approval.',
                      stat     : 'Requires action',
                      statColor: _purple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OverrideScreen(
                            adminCity: widget.adminCity,
                            adminData: widget.userData,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const _SectionHeading('Analytics'),
                    const SizedBox(height: 12),

                    // City-Wide Stats card
                    _FeatureCard(
                      icon     : Icons.bar_chart_rounded,
                      iconBg   : _green,
                      title    : 'City-Wide Stats',
                      subtitle :
                          'Revenue, user growth, contractor performance, booking counts and disputes for ${widget.adminCity}.',
                      stat     : '$_bookingCount bookings',
                      statColor: _green,
                      onTap: () { 
                        debugPrint('adminCity value: "${widget.adminCity}"'); // ← add this
                        Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CityStatsScreen(
                              adminCity: widget.adminCity),
                        ),
                      );
                      },
                    ),
                    const SizedBox(height: 12),

                    // Cross-Area Escalations card
                    // "Cross-area" = a problem in one handler's area that
                    // affects another area or needs the regional admin to
                    // decide — e.g. a contractor working across two areas,
                    // a client dispute that spans areas, or a handler conflict.
                    _FeatureCard(
                      icon     : Icons.swap_horiz_rounded,
                      iconBg   : _red,
                      title    : 'Cross-Area Escalations',
                      subtitle :
                          'Cases raised by area handlers that cross area boundaries or need your decision.',
                      stat     : _escalationCount > 0
                          ? '$_escalationCount open'
                          : 'All clear',
                      statColor: _escalationCount > 0
                          ? _red
                          : _green,
                      badge: _escalationCount > 0
                          ? '$_escalationCount'
                          : null,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EscalationsScreen(
                            adminCity: widget.adminCity,
                            adminData: widget.userData,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Vertical divider between quick-stat items
  Widget _vDivider() => Container(
        height: 28,
        width: 1,
        color: Colors.white12,
        margin: const EdgeInsets.symmetric(horizontal: 8),
      );

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}

// =============================================================================
// 2. AREA HANDLER MANAGEMENT SCREEN
// Lists all area handlers for this city with filter chips.
// Tapping "View [Area]" on a card opens _AreaDetailScreen.
// =============================================================================
class AreaHandlerManagementScreen extends StatefulWidget {
  final String adminCity;
  final Map<String, dynamic> adminData;

  const AreaHandlerManagementScreen({
    super.key,
    required this.adminCity,
    required this.adminData,
  });

  @override
  State<AreaHandlerManagementScreen> createState() =>
      _AreaHandlerManagementScreenState();
}

// =============================================================================
// REPLACE _AreaHandlerManagementScreenState completely
// The stream now correctly filters by operationalCity
// and the form pre-fills city from the handler doc when editing
// =============================================================================

class _AreaHandlerManagementScreenState
    extends State<AreaHandlerManagementScreen> {
  String _filter = 'all';

  // ✅ Stream filters handlers where operationalCity matches adminCity
  // This ensures each regional admin ONLY sees handlers assigned to their city
  Stream<QuerySnapshot> get _handlersStream =>
      FirebaseFirestore.instance
          .collection('admins')
          .doc('area_handler')
          .collection('members')
          .where('operationalCity', isEqualTo: widget.adminCity)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _appBar('Area Handlers', widget.adminCity),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showHandlerSheet(context, null),
        backgroundColor: _navy,
        foregroundColor: _amber,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Handler',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          // ── Filter chips ────────────────────────────────────
          Container(
            color: _white,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _Chip(
                    label: 'All',
                    active: _filter == 'all',
                    onTap: () =>
                        setState(() => _filter = 'all')),
                const SizedBox(width: 8),
                _Chip(
                    label: 'Active',
                    active: _filter == 'active',
                    onTap: () =>
                        setState(() => _filter = 'active')),
                const SizedBox(width: 8),
                _Chip(
                    label: 'Suspended',
                    active: _filter == 'suspended',
                    onTap: () => setState(
                        () => _filter = 'suspended')),
              ],
            ),
          ),

          // ── Handler list ────────────────────────────────────
          Expanded(
            child: widget.adminCity.trim().isEmpty
                // Guard: if city is somehow empty show error
                ? const _EmptyState(
                    icon    : Icons.location_off_outlined,
                    title   : 'City not set',
                    subtitle:
                        'Your operational city is missing. Contact Super Admin.',
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: _handlersStream,
                    builder: (ctx, snap) {
                      if (snap.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: _amber));
                      }
                      if (snap.hasError) {
                        return _ErrorState(
                            message: snap.error.toString());
                      }

                      var docs = snap.data?.docs ?? [];

                      // Client-side filter by accountStatus
                      if (_filter != 'all') {
                        docs = docs.where((d) {
                          final data = d.data()
                              as Map<String, dynamic>;
                          return (data['accountStatus'] ??
                                  'active') ==
                              _filter;
                        }).toList();
                      }

                      if (docs.isEmpty) {
                        return _EmptyState(
                          icon    : Icons.people_outline,
                          title   : 'No handlers found',
                          subtitle: _filter == 'all'
                              ? 'Add your first area handler for ${widget.adminCity}.'
                              : 'No $_filter handlers in ${widget.adminCity}.',
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: docs.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final data = docs[i].data()
                              as Map<String, dynamic>;
                          final uid    = docs[i].id;
                          final status =
                              data['accountStatus'] ?? 'active';
                          // Read area from handler's own document
                          final area =
                              data['assignedArea'] as String? ??
                                  '';

                          return _HandlerCard(
                            data    : data,
                            uid     : uid,
                            onEdit  : () => _showHandlerSheet(
                                context, docs[i]),
                            onToggle: () =>
                                _toggleStatus(uid, status),
                            onDelete: () => _confirmDelete(uid,
                                data['name'] ?? 'Handler'),
                            onAssign: () => _showAssignSheet(
                                context, uid, data),
                            // Only show "View Area" when area is assigned
                            onViewArea: area.isNotEmpty
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            _AreaDetailScreen(
                                          city: widget.adminCity,
                                          area: area,
                                          handlerName:
                                              data['name'] ??
                                                  'Handler',
                                        ),
                                      ),
                                    )
                                : null,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleStatus(String uid, String current) async {
    if (uid.trim().isEmpty) return;
    final next =
        current == 'active' ? 'suspended' : 'active';
    await FirebaseFirestore.instance
        .collection('admins')
        .doc('area_handler')
        .collection('members')
        .doc(uid)
        .update({'accountStatus': next});
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(next == 'active'
          ? 'Handler activated'
          : 'Handler suspended'),
      backgroundColor: next == 'active' ? _green : _red,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Future<void> _confirmDelete(String uid, String name) async {
    if (uid.trim().isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Handler',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Remove $name from ${widget.adminCity}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _red,
                foregroundColor: _white),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await FirebaseFirestore.instance
        .collection('admins')
        .doc('area_handler')
        .collection('members')
        .doc(uid)
        .delete();
  }

  void _showHandlerSheet(
      BuildContext context, DocumentSnapshot? doc) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _HandlerFormSheet(
        adminCity: widget.adminCity,
        adminData: widget.adminData,
        existing : doc,
      ),
    );
  }

  void _showAssignSheet(BuildContext context, String uid,
      Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AssignAreaSheet(
        uid        : uid,
        handlerData: data,
        adminCity  : widget.adminCity,
      ),
    );
  }
}


// =============================================================================
// REPLACE _HandlerFormSheet completely
// Now correctly pre-fills ALL fields from the existing handler document
// and always uses operationalCity from the handler doc when editing,
// falling back to widget.adminCity when adding
// =============================================================================

class _HandlerFormSheet extends StatefulWidget {
  final String adminCity;
  final Map<String, dynamic> adminData;
  final DocumentSnapshot? existing; // null = add mode

  const _HandlerFormSheet({
    required this.adminCity,
    required this.adminData,
    this.existing,
  });

  @override
  State<_HandlerFormSheet> createState() =>
      _HandlerFormSheetState();
}

class _HandlerFormSheetState extends State<_HandlerFormSheet> {
  final _formKey   = GlobalKey<FormState>();
  final _nameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _areaCtrl  = TextEditingController();
  // City is read-only — comes from regional admin's assigned city
  late String _resolvedCity;
  bool _loading = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();

    if (_isEdit) {
      // ✅ Pre-fill ALL fields from the existing handler document
      final d = widget.existing!.data() as Map<String, dynamic>;
      _nameCtrl.text  = d['name']          as String? ?? '';
      _emailCtrl.text = d['email']         as String? ?? '';
      _phoneCtrl.text = d['phone']         as String? ?? '';
      _areaCtrl.text  = d['assignedArea']  as String? ?? '';

      // ✅ Use city from the handler doc itself when editing
      // This ensures we don't accidentally change their city
      _resolvedCity   = d['operationalCity'] as String? ??
          widget.adminCity;
    } else {
      // When adding, use the regional admin's city
      _resolvedCity = widget.adminCity;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Guard: city must be set
    if (_resolvedCity.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'City is missing. Cannot save handler without a city.'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final db = FirebaseFirestore.instance;

    final data = <String, dynamic>{
      'name'           : _nameCtrl.text.trim(),
      'email'          : _emailCtrl.text.trim().toLowerCase(),
      'phone'          : _phoneCtrl.text.trim(),
      'assignedArea'   : _areaCtrl.text.trim(),
      // ✅ Always write the resolved city — never empty
      'operationalCity': _resolvedCity.trim(),
      'role'           : 'AreaHandler',
      'accountStatus'  : 'active',
    };

    try {
      if (_isEdit) {
        final docId = widget.existing!.id;
        if (docId.trim().isEmpty) {
          throw Exception('Invalid document ID');
        }
        await db
            .collection('admins')
            .doc('area_handler')
            .collection('members')
            .doc(docId)
            .update(data);
      } else {
        // Server timestamp + creator uid only on create
        data['createdAt'] = FieldValue.serverTimestamp();
        data['createdBy'] =
            (widget.adminData['uid'] as String? ?? '').trim();
        await db
            .collection('admins')
            .doc('area_handler')
            .collection('members')
            .add(data);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isEdit
            ? 'Handler updated successfully'
            : 'Handler added successfully'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ));
    } catch (e) {
      debugPrint('[HandlerForm] Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: _border,
                        borderRadius:
                            BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text(
                _isEdit
                    ? 'Edit Handler'
                    : 'Add Area Handler',
                style: const TextStyle(
                    color: _label,
                    fontSize: 20,
                    fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),

              // ✅ Shows the resolved city clearly so admin
              // knows which city this handler belongs to
              Row(
                children: [
                  const Icon(Icons.location_city_outlined,
                      size: 14, color: _sub),
                  const SizedBox(width: 4),
                  Text(
                    _resolvedCity.isNotEmpty
                        ? _resolvedCity
                        : 'City not set',
                    style: TextStyle(
                        color: _resolvedCity.isNotEmpty
                            ? _sub
                            : _red,
                        fontSize: 13,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Full name
              _SheetField(
                  ctrl     : _nameCtrl,
                  label    : 'Full Name',
                  hint     : 'e.g. Ahmed Khan',
                  icon     : Icons.person_outline,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty
                          ? 'Required'
                          : null),
              const SizedBox(height: 14),

              // Email — disabled when editing
              _SheetField(
                  ctrl        : _emailCtrl,
                  label       : 'Email',
                  hint        : 'handler@thekaydaar.pk',
                  icon        : Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  enabled     : !_isEdit,
                  validator   : (v) {
                    if ((v ?? '').trim().isEmpty) {
                      return 'Required';
                    }
                    if (!v!.contains('@')) {
                      return 'Invalid email';
                    }
                    return null;
                  }),
              const SizedBox(height: 14),

              // Phone
              _SheetField(
                  ctrl        : _phoneCtrl,
                  label       : 'Phone',
                  hint        : '03XX-XXXXXXX',
                  icon        : Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator   : (v) =>
                      (v ?? '').trim().isEmpty
                          ? 'Required'
                          : null),
              const SizedBox(height: 14),

              // Assigned area
              _SheetField(
                  ctrl     : _areaCtrl,
                  label    : 'Assigned Area',
                  hint     : 'e.g. Clifton / DHA',
                  icon     : Icons.map_outlined,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty
                          ? 'Required'
                          : null),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: _amber,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width : 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: _amber,
                              strokeWidth: 2))
                      : Text(
                          _isEdit
                              ? 'Save Changes'
                              : 'Add Handler',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


// =============================================================================
// REPLACE _AssignAreaSheet completely
// Now shows a read-only city banner so admin always knows
// which city's handler they are assigning an area to
// =============================================================================

class _AssignAreaSheet extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> handlerData;
  final String adminCity;

  const _AssignAreaSheet({
    required this.uid,
    required this.handlerData,
    required this.adminCity,
  });

  @override
  State<_AssignAreaSheet> createState() =>
      _AssignAreaSheetState();
}

class _AssignAreaSheetState extends State<_AssignAreaSheet> {
  final _areaCtrl = TextEditingController();
  bool _loading   = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill with the handler's current assigned area
    _areaCtrl.text =
        widget.handlerData['assignedArea'] as String? ?? '';
  }

  @override
  void dispose() {
    _areaCtrl.dispose();
    super.dispose();
  }

  Future<void> _assign() async {
    if (_areaCtrl.text.trim().isEmpty ||
        widget.uid.trim().isEmpty) {
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseFirestore.instance
          .collection('admins')
          .doc('area_handler')
          .collection('members')
          .doc(widget.uid)
          .update({
        'assignedArea'   : _areaCtrl.text.trim(),
        // ✅ Also ensure operationalCity is always kept in sync
        'operationalCity': widget.adminCity.trim(),
      });
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Area assigned successfully'),
        backgroundColor: _green,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.all(16),
      ));
    } catch (e) {
      debugPrint('[AssignArea] Error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final handlerName =
        widget.handlerData['name'] as String? ?? 'Handler';
    final currentArea =
        widget.handlerData['assignedArea'] as String? ?? '';

    return Container(
      decoration: const BoxDecoration(
        color: _white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _border,
                    borderRadius:
                        BorderRadius.circular(2))),
          ),
          const SizedBox(height: 16),
          const Text('Assign Area',
              style: TextStyle(
                  color: _label,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),

          // Handler info banner
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                // Handler name + city row
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: _blue.withValues(alpha:0.1),
                        borderRadius:
                            BorderRadius.circular(10),
                      ),
                      child: const Icon(
                          Icons.person_rounded,
                          color: _blue,
                          size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(handlerName,
                              style: const TextStyle(
                                  color: _label,
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w700)),
                          Row(
                            children: [
                              const Icon(
                                  Icons
                                      .location_city_outlined,
                                  size: 11,
                                  color: _sub),
                              const SizedBox(width: 3),
                              Text(widget.adminCity,
                                  style: const TextStyle(
                                      color: _sub,
                                      fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                // Current area badge (if already assigned)
                if (currentArea.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: _border),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.map_outlined,
                          size: 13, color: _sub),
                      const SizedBox(width: 6),
                      const Text('Current area: ',
                          style: TextStyle(
                              color: _sub, fontSize: 12)),
                      Text(currentArea,
                          style: const TextStyle(
                              color: _label,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // New area input
          _SheetField(
            ctrl : _areaCtrl,
            label: 'New Area / Sector',
            hint : 'e.g. Gulshan-e-Iqbal',
            icon : Icons.place_outlined,
          ),
          const SizedBox(height: 24),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _loading ? null : _assign,
              style: ElevatedButton.styleFrom(
                backgroundColor: _purple,
                foregroundColor: _white,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12)),
              ),
              child: _loading
                  ? const SizedBox(
                      width : 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: _white, strokeWidth: 2))
                  : const Text('Confirm Assignment',
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}// ── Handler card ──────────────────────────────────────────────────────────────
class _HandlerCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final String uid;
  final VoidCallback onEdit;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onAssign;
  final VoidCallback? onViewArea; // null when no area assigned yet

  const _HandlerCard({
    required this.data,
    required this.uid,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
    required this.onAssign,
    this.onViewArea,
  });

  @override
  Widget build(BuildContext context) {
    final status   = data['accountStatus'] ?? 'active';
    final area     = data['assignedArea']  ?? 'Unassigned';
    final name     = data['name']          ?? 'Unknown';
    final email    = data['email']         ?? '';
    final phone    = data['phone']         ?? '';
    final isActive = status == 'active';

    return Container(
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isActive ? _border : _red.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // ── Name / email / status ──────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isActive
                        ? _blue.withValues(alpha: 0.1)
                        : _red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.person_rounded,
                      color: isActive ? _blue : _red, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(name,
                                style: const TextStyle(
                                  color: _label,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                          _StatusBadge(status: status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(email,
                          style: const TextStyle(
                              color: _sub, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Action buttons ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(14)),
            ),
            child: Column(
              children: [
                // Info chips: area + phone
                Row(
                  children: [
                    _InfoChip(
                        icon: Icons.map_outlined, label: area),
                    const SizedBox(width: 8),
                    _InfoChip(
                        icon: Icons.phone_outlined,
                        label: phone),
                  ],
                ),
                const SizedBox(height: 10),

                // Action row: Edit | Assign Area | Suspend | Delete
                Row(
                  children: [
                    Expanded(
                      child: _ActionBtn(
                          label: 'Edit',
                          icon : Icons.edit_outlined,
                          color: _blue,
                          onTap: onEdit),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ActionBtn(
                          label: 'Assign Area',
                          icon : Icons.map_rounded,
                          color: _purple,
                          onTap: onAssign),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _ActionBtn(
                          label: isActive
                              ? 'Suspend'
                              : 'Activate',
                          icon : isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                          color: isActive ? _red : _green,
                          onTap: onToggle),
                    ),
                    const SizedBox(width: 6),
                    // Compact delete button (icon only)
                    _ActionBtn(
                        label  : '',
                        icon   : Icons.delete_outline,
                        color  : _red.withValues(alpha: 0.7),
                        onTap  : onDelete,
                        compact: true),
                  ],
                ),

                // View Area button — only shown when area is assigned
                // Navigates to _AreaDetailScreen showing
                // that area's clients and contractors
                if (onViewArea != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onViewArea,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 10),
                      decoration: BoxDecoration(
                        color: _navy.withValues(alpha: 0.05),
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                            color: _navy.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          const Icon(
                              Icons.remove_red_eye_outlined,
                              size: 14,
                              color: _navy),
                          const SizedBox(width: 6),
                          Text(
                            'View $area',
                            style: const TextStyle(
                                color: _navy,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Handler form sheet (Add / Edit) ───────────────────────────────────────────

// =============================================================================
// 3. CITY STATS SCREEN
// Reads a single document from city_stats/{city}
// =============================================================================
class CityStatsScreen extends StatelessWidget {
  final String adminCity;
  const CityStatsScreen({super.key, required this.adminCity});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: _appBar('City Stats', adminCity),
      body: adminCity.trim().isEmpty
          // ── Guard: show error if city is empty instead of crashing ──
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_off_outlined,
                        color: _sub, size: 48),
                    SizedBox(height: 16),
                    Text('City not set',
                        style: TextStyle(
                            color: _label,
                            fontSize: 16,
                            fontWeight: FontWeight.w700)),
                    SizedBox(height: 6),
                    Text(
                        'Admin city is missing. Please contact your Super Admin.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: _sub, fontSize: 13)),
                  ],
                ),
              ),
            )
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('city_stats')
                  .doc(adminCity.trim()) // ← always trim
                  .snapshots(),
              builder: (ctx, snap) {
                if (snap.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: _amber));
                }
                if (snap.hasError) {
                  return Center(
                    child: Text('Error: ${snap.error}',
                        style: const TextStyle(
                            color: _red, fontSize: 13)),
                  );
                }
                final stats =
                    (snap.data?.data() as Map<String, dynamic>?) ??
                        {};
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _StatSection(
                      title    : 'Revenue',
                      icon     : Icons.payments_outlined,
                      iconColor: _green,
                      children : [
                        _StatRow('Total Revenue',
                            'PKR ${_fmt(stats['totalRevenue'])}'),
                        _StatRow('This Month',
                            'PKR ${_fmt(stats['monthlyRevenue'])}'),
                        _StatRow('Pending Payouts',
                            'PKR ${_fmt(stats['pendingPayouts'])}'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatSection(
                      title    : 'User Growth',
                      icon     : Icons.group_outlined,
                      iconColor: _blue,
                      children : [
                        _StatRow('Total Users',
                            _fmt(stats['totalUsers'])),
                        _StatRow('New This Month',
                            _fmt(stats['newUsersThisMonth'])),
                        _StatRow('Active Users (30d)',
                            _fmt(stats['activeUsers'])),
                        _StatRow('Churned Users',
                            _fmt(stats['churnedUsers'])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatSection(
                      title    : 'Bookings',
                      icon     : Icons.calendar_month_outlined,
                      iconColor: _amber,
                      children : [
                        _StatRow('Total Bookings',
                            _fmt(stats['totalBookings'])),
                        _StatRow('Completed',
                            _fmt(stats['completedBookings'])),
                        _StatRow('Cancelled',
                            _fmt(stats['cancelledBookings'])),
                        _StatRow('Pending',
                            _fmt(stats['pendingBookings'])),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _StatSection(
                      title    : 'Contractors',
                      icon     : Icons.handyman_outlined,
                      iconColor: _purple,
                      children : [
                        _StatRow('Total Contractors',
                            _fmt(stats['totalContractors'])),
                        _StatRow('Active',
                            _fmt(stats['activeContractors'])),
                        _StatRow(
                            'Avg. Rating',
                            '${(stats['avgRating'] ?? 0.0).toStringAsFixed(1)} ★'),
                        _StatRow('Disputes Filed',
                            _fmt(stats['disputes'])),
                      ],
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
    );
  }

  String _fmt(dynamic v) {
    if (v == null) return '—';
    if (v is int) return v.toString();
    if (v is double) return v.toStringAsFixed(0);
    return v.toString();
  }
}// =============================================================================
// 4. ESCALATIONS SCREEN
// Cross-area escalations: cases raised by area handlers that either
// cross area boundaries OR need the regional admin to decide.
// Examples: contractor working across two areas, a handler conflict,
// a client dispute that spans multiple areas.
// =============================================================================
class EscalationsScreen extends StatefulWidget {
  final String adminCity;
  final Map<String, dynamic> adminData;

  const EscalationsScreen({
    super.key,
    required this.adminCity,
    required this.adminData,
  });

  @override
  State<EscalationsScreen> createState() =>
      _EscalationsScreenState();
}

class _EscalationsScreenState extends State<EscalationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  // Stream filtered by status for each tab
  Stream<QuerySnapshot> _stream(String status) =>
      FirebaseFirestore.instance
          .collection('escalations')
          .where('city', isEqualTo: widget.adminCity)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: _white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Cross-Area Escalations',
                style: TextStyle(
                    color: _white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text(widget.adminCity,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _amber,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _amber,
          tabs: const [
            Tab(text: 'Open'),
            Tab(text: 'In Progress'),
            Tab(text: 'Resolved'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _EscalationList(
              stream   : _stream('open'),
              adminData: widget.adminData,
              adminCity: widget.adminCity),
          _EscalationList(
              stream   : _stream('in_progress'),
              adminData: widget.adminData,
              adminCity: widget.adminCity),
          _EscalationList(
              stream   : _stream('resolved'),
              adminData: widget.adminData,
              adminCity: widget.adminCity),
        ],
      ),
    );
  }
}

class _EscalationList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final Map<String, dynamic> adminData;
  final String adminCity;

  const _EscalationList({
    required this.stream,
    required this.adminData,
    required this.adminCity,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _amber));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            icon    : Icons.check_circle_outline,
            title   : 'No escalations here',
            subtitle: 'This tab is all clear.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          // ✅ Fixed: (_, _) → (_, __)
          separatorBuilder: (_, _) =>
              const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final data =
                docs[i].data() as Map<String, dynamic>;
            return _EscalationCard(
              docId    : docs[i].id,
              data     : data,
              adminData: adminData,
              adminCity: adminCity,
            );
          },
        );
      },
    );
  }
}

class _EscalationCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> adminData;
  final String adminCity;

  const _EscalationCard({
    required this.docId,
    required this.data,
    required this.adminData,
    required this.adminCity,
  });

  @override
  Widget build(BuildContext context) {
    final status   = data['status']   ?? 'open';
    final title    = data['title']    ?? 'Escalation';
    final fromArea = data['fromArea'] ?? 'Unknown Area';
    final priority = data['priority'] ?? 'medium';

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EscalationDetailScreen(
            docId    : docId,
            data     : data,
            adminData: adminData,
            adminCity: adminCity,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PriorityDot(priority: priority),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(
                          color: _label,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                _EscalationStatusBadge(status: status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.place_outlined,
                    color: _sub, size: 14),
                const SizedBox(width: 4),
                Text(fromArea,
                    style: const TextStyle(
                        color: _sub, fontSize: 12)),
                const Spacer(),
                const Icon(Icons.arrow_forward_ios_rounded,
                    color: _sub, size: 12),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Escalation detail screen ──────────────────────────────────────────────────
class EscalationDetailScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> adminData;
  final String adminCity;

  const EscalationDetailScreen({
    super.key,
    required this.docId,
    required this.data,
    required this.adminData,
    required this.adminCity,
  });

  @override
  State<EscalationDetailScreen> createState() =>
      _EscalationDetailScreenState();
}

class _EscalationDetailScreenState
    extends State<EscalationDetailScreen> {
  final _noteCtrl = TextEditingController();
  bool _saving    = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  // Append a note to the notes array in Firestore
  Future<void> _addNote() async {
    if (_noteCtrl.text.trim().isEmpty ||
        widget.docId.trim().isEmpty) {
      return;
    }
    setState(() => _saving = true);
    final note = {
      'text'   : _noteCtrl.text.trim(),
      'addedBy': widget.adminData['name'] ?? 'Regional Admin',
      'addedAt': FieldValue.serverTimestamp(),
    };
    await FirebaseFirestore.instance
        .collection('escalations')
        .doc(widget.docId)
        .update({'notes': FieldValue.arrayUnion([note])});
    _noteCtrl.clear();
    if (mounted) setState(() => _saving = false);
  }

  // Update escalation status and navigate back
  Future<void> _updateStatus(String newStatus) async {
    if (widget.docId.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('escalations')
        .doc(widget.docId)
        .update({
      'status'   : newStatus,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy':
          widget.adminData['name'] ?? 'Regional Admin',
    });
    if (!mounted) return;
    Navigator.pop(context);
  }

  // Reassign the escalation to a different handler
  Future<void> _reassign() async {
    final ctrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Reassign Handler',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Handler name or area',
            border  : OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.pop(context, ctrl.text.trim()),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: _amber),
              child: const Text('Reassign')),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('escalations')
          .doc(widget.docId)
          .update({
        'assignedTo': result,
        'updatedAt' : FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Live-stream the document so notes update in real-time
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('escalations')
          .doc(widget.docId)
          .snapshots(),
      builder: (ctx, snap) {
        final live =
            (snap.data?.data() as Map<String, dynamic>?) ??
                widget.data;
        final status      = live['status']      ?? 'open';
        final title       = live['title']       ?? 'Escalation';
        final description = live['description'] ?? '';
        final fromArea    = live['fromArea']    ?? '';
        final priority    = live['priority']    ?? 'medium';
        final notes =
            (live['notes'] as List<dynamic>?) ?? [];
        final assignedTo = live['assignedTo'] ?? 'Unassigned';

        return Scaffold(
          backgroundColor: _surface,
          appBar: AppBar(
            backgroundColor: _navy,
            foregroundColor: _white,
            title: const Text('Case Detail',
                style: TextStyle(
                    color: _white,
                    fontWeight: FontWeight.w700)),
            actions: [
              if (status != 'resolved')
                TextButton(
                  onPressed: () =>
                      _updateStatus('resolved'),
                  child: const Text('Resolve',
                      style: TextStyle(
                          color: _amber,
                          fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Case summary card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _PriorityDot(priority: priority),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(title,
                              style: const TextStyle(
                                  color: _label,
                                  fontSize: 16,
                                  fontWeight:
                                      FontWeight.w800)),
                        ),
                        _EscalationStatusBadge(
                            status: status),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (description.isNotEmpty) ...[
                      Text(description,
                          style: const TextStyle(
                              color: _sub,
                              fontSize: 13.5,
                              height: 1.5)),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      children: [
                        _InfoChip(
                            icon: Icons.place_outlined,
                            label: fromArea),
                        const SizedBox(width: 8),
                        _InfoChip(
                            icon: Icons.person_outline,
                            label: assignedTo),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      label: 'In Progress',
                      icon : Icons.autorenew_rounded,
                      color: _amber,
                      onTap: () =>
                          _updateStatus('in_progress'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Reassign',
                      icon : Icons.swap_horiz_rounded,
                      color: _purple,
                      onTap: _reassign,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Notes section
              const Text('Case Notes',
                  style: TextStyle(
                      color: _label,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              if (notes.isEmpty)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: const Text('No notes yet.',
                      style: TextStyle(
                          color: _sub, fontSize: 13)),
                )
              else
                ...notes.map((n) {
                  final note = n as Map<String, dynamic>;
                  return Container(
                    margin:
                        const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius:
                          BorderRadius.circular(12),
                      border: Border.all(color: _border),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(note['addedBy'] ?? '',
                            style: const TextStyle(
                                color: _label,
                                fontSize: 12,
                                fontWeight:
                                    FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(note['text'] ?? '',
                            style: const TextStyle(
                                color: _sub,
                                fontSize: 13,
                                height: 1.4)),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 16),

              // Add note field
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _border),
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text('Add Note',
                        style: TextStyle(
                            color: _label,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _noteCtrl,
                      maxLines  : 3,
                      decoration: InputDecoration(
                        hintText : 'Write your note here...',
                        hintStyle: const TextStyle(
                            color: Color(0xFFA6B2AB),
                            fontSize: 13),
                        filled    : true,
                        fillColor : _surface,
                        border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: _border)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: _border)),
                        focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: _amber, width: 1.5)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _saving ? null : _addNote,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: _amber,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(
                                      10)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width : 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(
                                        color: _amber,
                                        strokeWidth: 2))
                            : const Text('Add Note',
                                style: TextStyle(
                                    fontWeight:
                                        FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
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
// 5. OVERRIDE SCREEN
// Shows escalations where requiresOverride == true.
// Regional admin approves or rejects the handler's decision.
// =============================================================================
class OverrideScreen extends StatefulWidget {
  final String adminCity;
  final Map<String, dynamic> adminData;

  const OverrideScreen({
    super.key,
    required this.adminCity,
    required this.adminData,
  });

  @override
  State<OverrideScreen> createState() => _OverrideScreenState();
}

class _OverrideScreenState extends State<OverrideScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Stream<QuerySnapshot> _stream(String status) =>
      FirebaseFirestore.instance
          .collection('escalations')
          .where('city', isEqualTo: widget.adminCity)
          .where('requiresOverride', isEqualTo: true)
          .where('overrideStatus', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: _white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Override Decisions',
                style: TextStyle(
                    color: _white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text(widget.adminCity,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _amber,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _amber,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Reviewed'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverrideList(
              stream   : _stream('pending'),
              adminData: widget.adminData),
          _OverrideList(
              stream   : _stream('reviewed'),
              adminData: widget.adminData),
        ],
      ),
    );
  }
}

class _OverrideList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final Map<String, dynamic> adminData;
  const _OverrideList(
      {required this.stream, required this.adminData});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _amber));
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const _EmptyState(
            icon    : Icons.gavel_rounded,
            title   : 'No override requests',
            subtitle: 'Nothing pending your review.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          // ✅ Fixed: (_, _) → (_, __)
          separatorBuilder: (_, _) =>
              const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final data =
                docs[i].data() as Map<String, dynamic>;
            return _OverrideCard(
              docId    : docs[i].id,
              data     : data,
              adminData: adminData,
            );
          },
        );
      },
    );
  }
}

class _OverrideCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> adminData;

  const _OverrideCard({
    required this.docId,
    required this.data,
    required this.adminData,
  });

  // Approve or reject the override request
  Future<void> _decide(
      BuildContext context, String decision) async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(
            decision == 'approved'
                ? 'Approve Override'
                : 'Reject Override',
            style:
                const TextStyle(fontWeight: FontWeight.w800)),
        content: TextField(
          controller: reasonCtrl,
          maxLines  : 3,
          decoration: const InputDecoration(
              hintText: 'Reason (optional)',
              border  : OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  decision == 'approved' ? _green : _red,
              foregroundColor: _white,
            ),
            child: Text(decision == 'approved'
                ? 'Approve'
                : 'Reject'),
          ),
        ],
      ),
    );

    if (confirmed != true || docId.trim().isEmpty) return;
    await FirebaseFirestore.instance
        .collection('escalations')
        .doc(docId)
        .update({
      'overrideStatus'  : 'reviewed',
      'overrideDecision': decision,
      'overrideReason'  : reasonCtrl.text.trim(),
      'reviewedBy'      : adminData['name'] ?? 'Regional Admin',
      'reviewedAt'      : FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final title          = data['title']           ?? 'Override Request';
    final handlerName    = data['handlerName']     ?? 'Unknown Handler';
    final area           = data['fromArea']        ?? '';
    final decision       = data['handlerDecision'] ?? '';
    final overrideStatus = data['overrideStatus']  ?? 'pending';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.gavel_rounded,
                    color: _purple, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: _label,
                            fontSize: 14,
                            fontWeight: FontWeight.w700)),
                    Text('$handlerName · $area',
                        style: const TextStyle(
                            color: _sub, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),

          // Handler's original decision
          if (decision.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text('Handler decision: ',
                      style: TextStyle(
                          color: _sub,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  Expanded(
                    child: Text(decision,
                        style: const TextStyle(
                            color: _label, fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],

          // Approve / Reject buttons (pending only)
          if (overrideStatus == 'pending') ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ActionBtn(
                    label: 'Approve',
                    icon : Icons.check_circle_outline,
                    color: _green,
                    onTap: () =>
                        _decide(context, 'approved'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionBtn(
                    label: 'Reject',
                    icon : Icons.cancel_outlined,
                    color: _red,
                    onTap: () =>
                        _decide(context, 'rejected'),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Reviewed state — show result
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  data['overrideDecision'] == 'approved'
                      ? Icons.check_circle
                      : Icons.cancel,
                  color:
                      data['overrideDecision'] == 'approved'
                          ? _green
                          : _red,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  '${data['overrideDecision'] ?? 'reviewed'} by '
                  '${data['reviewedBy'] ?? 'Admin'}',
                  style: const TextStyle(
                      color: _sub, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// 6. REGIONAL ADMIN PROFILE SCREEN
// =============================================================================
class RegionalAdminProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String adminCity;

  const RegionalAdminProfileScreen({
    super.key,
    required this.userData,
    required this.adminCity,
  });

  @override
  State<RegionalAdminProfileScreen> createState() =>
      _RegionalAdminProfileScreenState();
}

class _RegionalAdminProfileScreenState
    extends State<RegionalAdminProfileScreen> {
  final _formKey    = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;
  final _oldPassCtrl  = TextEditingController();
  final _newPassCtrl  = TextEditingController();
  final _confPassCtrl = TextEditingController();

  bool _showOld  = false;
  bool _showNew  = false;
  bool _showConf = false;
  bool _savingProfile  = false;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl  = TextEditingController(
        text: widget.userData['name']  ?? '');
    _phoneCtrl = TextEditingController(
        text: widget.userData['phone'] ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confPassCtrl.dispose();
    super.dispose();
  }

  // Resolve uid: prefer userData field, fallback to Auth current user
  String? get _uid {
    final uid = (widget.userData['uid'] as String? ??
            FirebaseAuth.instance.currentUser?.uid ??
            '')
        .trim();
    return uid.isEmpty ? null : uid;
  }

  String get _email =>
      widget.userData['email'] as String? ??
      FirebaseAuth.instance.currentUser?.email ??
      '';

  void _snack(String msg, {Color bg = _green}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
    ));
  }

  // Save name + phone to Firestore and Firebase Auth displayName
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = _uid;
    if (uid == null) {
      _snack('Cannot save: UID missing.', bg: _red);
      return;
    }
    setState(() => _savingProfile = true);
    try {
      await FirebaseAuth.instance.currentUser
          ?.updateDisplayName(_nameCtrl.text.trim());
      await FirebaseFirestore.instance
          .collection('admins')
          .doc('regional_admin')
          .collection('members')
          .doc(uid)
          .update({
        'name'     : _nameCtrl.text.trim(),
        'phone'    : _phoneCtrl.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _snack('Profile updated successfully');
    } catch (e) {
      debugPrint('[Profile] Save error: $e');
      _snack('Error: $e', bg: _red);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  // Re-authenticate then update password
  Future<void> _changePassword() async {
    final old  = _oldPassCtrl.text.trim();
    final next = _newPassCtrl.text.trim();
    final conf = _confPassCtrl.text.trim();

    if (old.isEmpty || next.isEmpty || conf.isEmpty) {
      _snack('Fill all password fields.', bg: _red);
      return;
    }
    if (next != conf) {
      _snack('New passwords do not match.', bg: _red);
      return;
    }
    if (next.length < 6) {
      _snack('Password must be at least 6 characters.',
          bg: _red);
      return;
    }

    setState(() => _savingPassword = true);
    try {
      final user = FirebaseAuth.instance.currentUser!;
      final cred = EmailAuthProvider.credential(
          email: user.email!, password: old);
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(next);
      _oldPassCtrl.clear();
      _newPassCtrl.clear();
      _confPassCtrl.clear();
      _snack('Password changed successfully');
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'wrong-password'
          ? 'Current password is incorrect.'
          : e.message ?? 'Password change failed.';
      _snack(msg, bg: _red);
    } catch (e) {
      _snack('Error: $e', bg: _red);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initials = _nameCtrl.text.trim().isNotEmpty
        ? _nameCtrl.text.trim()[0].toUpperCase()
        : 'A';

    return Scaffold(
      backgroundColor: _surface,
      body: CustomScrollView(
        slivers: [
          // ── Collapsible gradient header ──────────────────────────────────
          SliverAppBar(
            pinned        : true,
            expandedHeight: 210,
            backgroundColor: _navy,
            foregroundColor: _white,
            flexibleSpace : FlexibleSpaceBar(
              title: const Text('My Profile',
                  style: TextStyle(
                      color: _white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              centerTitle: false,
              background : Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_navy, _navy2],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      // Avatar circle with initial
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color:
                              _amber.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color:
                                  _amber.withValues(alpha: 0.5),
                              width: 2),
                        ),
                        child: Center(
                          child: Text(initials,
                              style: const TextStyle(
                                color: _amber,
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                              )),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _nameCtrl.text.isEmpty
                            ? 'Regional Admin'
                            : _nameCtrl.text,
                        style: const TextStyle(
                            color: _white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: _amber.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(20),
                          border: Border.all(
                              color:
                                  _amber.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                                Icons.shield_outlined,
                                color: _amber,
                                size: 11),
                            const SizedBox(width: 4),
                            Text(
                              'Regional Admin · ${widget.adminCity}',
                              style: const TextStyle(
                                  color: _amber,
                                  fontSize: 11,
                                  fontWeight:
                                      FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Profile body ─────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Personal information card
                _ProfileCard(
                  title: 'Personal Information',
                  icon : Icons.person_outline_rounded,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 4),
                        // Read-only email
                        _InfoRow(
                          icon : Icons.mail_outline,
                          label: 'Email',
                          value: _email,
                          note : 'Cannot be changed here.',
                        ),
                        const Divider(
                            height: 1, color: _border),
                        // Read-only city
                        _InfoRow(
                          icon : Icons.location_city_outlined,
                          label: 'Operational City',
                          value: widget.adminCity,
                          note : 'Assigned by Super Admin.',
                        ),
                        const Divider(
                            height: 1, color: _border),
                        const SizedBox(height: 14),
                        // Editable name
                        _SheetField(
                          ctrl     : _nameCtrl,
                          label    : 'Full Name',
                          hint     : 'Your full name',
                          icon     : Icons.badge_outlined,
                          validator: (v) =>
                              (v ?? '').trim().isEmpty
                                  ? 'Name is required'
                                  : null,
                        ),
                        const SizedBox(height: 14),
                        // Editable phone
                        _SheetField(
                          ctrl        : _phoneCtrl,
                          label       : 'Phone Number',
                          hint        : '03XX-XXXXXXX',
                          icon        : Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          validator: (v) =>
                              (v ?? '').trim().isEmpty
                                  ? 'Phone is required'
                                  : null,
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _savingProfile
                                ? null
                                : _saveProfile,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _navy,
                              foregroundColor: _amber,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                          12)),
                            ),
                            child: _savingProfile
                                ? const SizedBox(
                                    width : 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                            color: _amber,
                                            strokeWidth: 2))
                                : const Text('Save Changes',
                                    style: TextStyle(
                                        fontWeight:
                                            FontWeight.w700,
                                        fontSize: 15)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Change password card
                _ProfileCard(
                  title: 'Change Password',
                  icon : Icons.lock_outline_rounded,
                  child: Column(
                    children: [
                      const SizedBox(height: 4),
                      _PasswordField(
                        ctrl    : _oldPassCtrl,
                        label   : 'Current Password',
                        hint    : 'Enter current password',
                        obscure : !_showOld,
                        onToggle: () => setState(
                            () => _showOld = !_showOld),
                      ),
                      const SizedBox(height: 14),
                      _PasswordField(
                        ctrl    : _newPassCtrl,
                        label   : 'New Password',
                        hint    : 'At least 6 characters',
                        obscure : !_showNew,
                        onToggle: () => setState(
                            () => _showNew = !_showNew),
                      ),
                      const SizedBox(height: 14),
                      _PasswordField(
                        ctrl    : _confPassCtrl,
                        label   : 'Confirm New Password',
                        hint    : 'Repeat new password',
                        obscure : !_showConf,
                        onToggle: () => setState(
                            () => _showConf = !_showConf),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _savingPassword
                              ? null
                              : _changePassword,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _navy,
                            foregroundColor: _amber,
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                        12)),
                          ),
                          child: _savingPassword
                              ? const SizedBox(
                                  width : 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(
                                          color: _amber,
                                          strokeWidth: 2))
                              : const Text('Update Password',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w700,
                                      fontSize: 15)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Sign out card
                _ProfileCard(
                  title: 'Account',
                  icon : Icons.manage_accounts_outlined,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _red.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: const Icon(
                              Icons.logout_rounded,
                              color: _red,
                              size: 18),
                        ),
                        title: const Text('Sign Out',
                            style: TextStyle(
                                color: _red,
                                fontWeight: FontWeight.w700,
                                fontSize: 14)),
                        subtitle: const Text(
                            'You will be returned to login',
                            style: TextStyle(
                                color: _sub, fontSize: 12)),
                        trailing: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: _sub),
                        onTap: () async {
                          await FirebaseAuth.instance
                              .signOut();
                          if (!context.mounted) return;
                          Navigator.pushNamedAndRemoveUntil(
                              context, '/login', (_) => false);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 7. AREA DETAIL SCREEN
// Shows clients and contractors for one handler's assigned area.
// Opened by tapping "View [Area]" on a handler card.
// =============================================================================
class _AreaDetailScreen extends StatefulWidget {
  final String city;
  final String area;
  final String handlerName;

  const _AreaDetailScreen({
    required this.city,
    required this.area,
    required this.handlerName,
  });

  @override
  State<_AreaDetailScreen> createState() =>
      _AreaDetailScreenState();
}

class _AreaDetailScreenState extends State<_AreaDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: _white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.area,
                style: const TextStyle(
                    color: _white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
            Text('Handler: ${widget.handlerName}',
                style: const TextStyle(
                    color: Colors.white54, fontSize: 11)),
          ],
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: _amber,
          unselectedLabelColor: Colors.white54,
          indicatorColor: _amber,
          tabs: const [
            Tab(
                icon: Icon(Icons.people_outline, size: 18),
                text: 'Clients'),
            Tab(
                icon:
                    Icon(Icons.handyman_outlined, size: 18),
                text: 'Contractors'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [

          // ── Clients tab ──────────────────────────────────────
          // Queries 'clients' collection by city + area
          _AreaMemberList(
            stream: FirebaseFirestore.instance
                .collection('clients')
                .where('city', isEqualTo: widget.city)
                .where('area', isEqualTo: widget.area)
                .snapshots(),
            emptyTitle   : 'No clients yet',
            emptySubtitle:
                'No clients registered in ${widget.area}.',
            tileBuilder: (data) => _MemberTile(
              // Use fullName field matching Firestore document
              name     : data['fullName'] as String? ?? '—',
              sub      : data['phone']    as String? ?? '—',
              // Show NIC approval state
              tag      : data['nic_approved'] == true
                  ? 'NIC ✓'
                  : 'NIC Pending',
              tagColor : data['nic_approved'] == true
                  ? _green
                  : _amber,
              icon     : Icons.person_outline,
              iconColor: _blue,
            ),
          ),

          // ── Contractors tab ──────────────────────────────────
          // Queries 'thekaydaars' collection by city + area
          _AreaMemberList(
            stream: FirebaseFirestore.instance
                .collection('thekaydaars')
                .where('city', isEqualTo: widget.city)
                .where('area', isEqualTo: widget.area)
                .snapshots(),
            emptyTitle   : 'No contractors yet',
            emptySubtitle:
                'No contractors registered in ${widget.area}.',
            tileBuilder: (data) {
              // Derive NIC status from verified/rejected flags
              final verified =
                  data['nicVerified'] as bool? ?? false;
              final rejected =
                  data['nicRejected'] as bool? ?? false;
              final nicTag = rejected
                  ? 'Rejected'
                  : verified
                      ? 'Verified'
                      : 'Pending';
              final nicColor = rejected
                  ? _red
                  : verified
                      ? _green
                      : _amber;
              return _MemberTile(
                name     : data['fullName'] as String? ?? '—',
                sub      : data['phone']    as String? ?? '—',
                tag      : nicTag,
                tagColor : nicColor,
                icon     : Icons.handyman_outlined,
                iconColor: _amber,
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Reusable real-time member list ────────────────────────────────────────────
class _AreaMemberList extends StatelessWidget {
  final Stream<QuerySnapshot> stream;
  final String emptyTitle;
  final String emptySubtitle;
  // Builder so each tab can customise the tile appearance
  final Widget Function(Map<String, dynamic> data) tileBuilder;

  const _AreaMemberList({
    required this.stream,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.tileBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,
      builder: (_, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: _amber));
        }
        if (snap.hasError) {
          return _ErrorState(
              message: snap.error.toString());
        }
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon    : Icons.search_off_rounded,
            title   : emptyTitle,
            subtitle: emptySubtitle,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          separatorBuilder: (_, _) =>
              const SizedBox(height: 8),
          itemBuilder: (_, i) {
            final data =
                docs[i].data() as Map<String, dynamic>;
            return tileBuilder(data);
          },
        );
      },
    );
  }
}

// ── Single member tile (client or contractor) ─────────────────────────────────
class _MemberTile extends StatelessWidget {
  final String name;
  final String sub;       // phone or secondary info
  final String tag;       // NIC status label
  final Color tagColor;
  final IconData icon;
  final Color iconColor;

  const _MemberTile({
    required this.name,
    required this.sub,
    required this.tag,
    required this.tagColor,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          // Icon avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Name + secondary info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        color: _label,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(sub,
                    style: const TextStyle(
                        color: _sub, fontSize: 12)),
              ],
            ),
          ),
          // NIC status tag
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: tagColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: tagColor.withValues(alpha: 0.25)),
            ),
            child: Text(tag,
                style: TextStyle(
                    color: tagColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SHARED SMALL WIDGETS
// =============================================================================

// Quick stat item used in the dashboard header row
class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight; // amber highlight for attention

  const _QuickStat({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Icon(icon,
                color: highlight ? _amber : Colors.white54,
                size: 16),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                  color: highlight ? _amber : _white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                )),
            Text(label,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 10)),
          ],
        ),
      );
}

// Large tappable feature card on the dashboard
class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String stat;
  final Color statColor;
  final String? badge; // red notification dot
  final VoidCallback onTap;

  const _FeatureCard({
    required this.icon,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.stat,
    required this.statColor,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconBg.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(13),
                    ),
                    child:
                        Icon(icon, color: iconBg, size: 24),
                  ),
                  // Red badge dot for pending counts
                  if (badge != null)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                            color: _red,
                            shape: BoxShape.circle),
                        child: Text(badge!,
                            style: const TextStyle(
                                color: _white,
                                fontSize: 9,
                                fontWeight:
                                    FontWeight.w800)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          color: _label,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        )),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            color: _sub,
                            fontSize: 12.5,
                            height: 1.45)),
                    const SizedBox(height: 8),
                    Text(stat,
                        style: TextStyle(
                            color: statColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: Color(0xFFA9B5AE)),
            ],
          ),
        ),
      );
}

// Uppercase section label
class _SectionHeading extends StatelessWidget {
  final String text;
  const _SectionHeading(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: _sub,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );
}

// Grouped stat section with title row + children
class _StatSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final List<Widget> children;

  const _StatSection({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Row(
                children: [
                  Icon(icon, color: iconColor, size: 18),
                  const SizedBox(width: 8),
                  Text(title,
                      style: TextStyle(
                          color: iconColor,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            ...children,
          ],
        ),
      );
}

// Label-value row inside a stat section
class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  const _StatRow(this.label, this.value);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(
                    color: _sub, fontSize: 13.5)),
            Text(value,
                style: const TextStyle(
                    color: _label,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

// Green/red active/suspended badge
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isActive = status == 'active';
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? _green.withValues(alpha: 0.1)
            : _red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Active' : 'Suspended',
        style: TextStyle(
            color: isActive ? _green : _red,
            fontSize: 11,
            fontWeight: FontWeight.w700),
      ),
    );
  }
}

// Colored badge for escalation status
class _EscalationStatusBadge extends StatelessWidget {
  final String status;
  const _EscalationStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'open'        => (_red,   'Open'),
      'in_progress' => (_amber, 'In Progress'),
      'resolved'    => (_green, 'Resolved'),
      _             => (_sub,   status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700)),
    );
  }
}

// Small colored dot indicating priority level
class _PriorityDot extends StatelessWidget {
  final String priority;
  const _PriorityDot({required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = switch (priority) {
      'high'   => _red,
      'medium' => _amber,
      'low'    => _green,
      _        => _sub,
    };
    return Container(
      width: 8,
      height: 8,
      decoration:
          BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// Pill-style filter chip
class _Chip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: active ? _navy : _surface,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: active ? _navy : _border),
          ),
          child: Text(label,
              style: TextStyle(
                color: active ? _amber : _sub,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              )),
        ),
      );
}

// Icon + text inline chip for info display
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _sub, size: 13),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  color: _sub, fontSize: 12)),
        ],
      );
}

// Soft outlined action button with icon + optional label
class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool compact; // icon-only mode

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border:
                Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 14),
              if (!compact && label.isNotEmpty) ...[
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      );
}

// Reusable text input field for forms and sheets
class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType keyboardType;
  final bool enabled;
  final String? Function(String?)? validator;

  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType = TextInputType.text,
    this.enabled      = true,
    this.validator,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _label,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller  : ctrl,
            keyboardType: keyboardType,
            enabled     : enabled,
            validator   : validator,
            style: const TextStyle(
                color: _label, fontSize: 14),
            decoration: InputDecoration(
              hintText  : hint,
              hintStyle : const TextStyle(
                  color: Color(0xFFA6B2AB)),
              prefixIcon: Icon(icon,
                  color: const Color(0xFFA6B2AB),
                  size: 18),
              filled    : true,
              fillColor : enabled
                  ? _surface
                  : const Color(0xFFEFF2F5),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: _amber, width: 1.5)),
              disabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Color(0xFFE3E0D5))),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Colors.redAccent)),
              focusedErrorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Colors.red, width: 1.5)),
              errorStyle:
                  const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      );
}

// Empty state placeholder with icon + title + subtitle
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _border),
                ),
                child: Icon(icon, color: _sub, size: 28),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      color: _label,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _sub,
                      fontSize: 13,
                      height: 1.5)),
            ],
          ),
        ),
      );
}

// Error state with message
class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  color: _red, size: 40),
              const SizedBox(height: 12),
              const Text('Something went wrong',
                  style: TextStyle(
                      color: _label,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: _sub, fontSize: 12)),
            ],
          ),
        ),
      );
}

// Profile card container used in RegionalAdminProfileScreen
class _ProfileCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _ProfileCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Icon(icon, color: _amber, size: 18),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          color: _label,
                          fontSize: 14,
                          fontWeight: FontWeight.w800)),
                ],
              ),
            ),
            const Divider(height: 1, color: _border),
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: child,
            ),
          ],
        ),
      );
}

// Read-only info row used in the profile screen
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String note; // explanatory sub-text

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.note,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: _sub, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: _sub,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(value,
                      style: const TextStyle(
                          color: _label,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(note,
                      style: const TextStyle(
                          color: Color(0xFFA6B2AB),
                          fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.lock_outline,
                size: 14, color: Color(0xFFA9B5AE)),
          ],
        ),
      );
}

// Password input with show/hide toggle
class _PasswordField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  color: _label,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          TextFormField(
            controller : ctrl,
            obscureText: obscure,
            style: const TextStyle(
                color: _label, fontSize: 14),
            decoration: InputDecoration(
              hintText  : hint,
              hintStyle : const TextStyle(
                  color: Color(0xFFA6B2AB)),
              prefixIcon: const Icon(Icons.lock_outline,
                  color: Color(0xFFA6B2AB), size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: const Color(0xFFA6B2AB),
                  size: 18,
                ),
                onPressed: onToggle,
              ),
              filled    : true,
              fillColor : _surface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: _border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: _amber, width: 1.5)),
              errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: Colors.redAccent)),
            ),
          ),
        ],
      );
}

// Shared AppBar builder used across multiple screens
PreferredSizeWidget _appBar(
        String title, String subtitle) =>
    AppBar(
      backgroundColor: _navy,
      foregroundColor: _white,
      elevation: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: _white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          Text(subtitle,
              style: const TextStyle(
                  color: Colors.white54, fontSize: 11)),
        ],
      ),
    );
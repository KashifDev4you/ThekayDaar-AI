// =============================================================================
// create_project_wizard.dart — "Create Project" simplified flow
//
// SIMPLIFIED 4-step flow (user feedback: keep only the important details):
//
//   1. Project & Location   → name / type / optional budget + MANUALLY typed
//                             location name & city (map pin is optional)
//   2. Plot & Rooms         → one-tap Pakistani house presets (3 Marla,
//                             5 Marla / 120 Gaj, 10 Marla, 1 Kanal) or a
//                             custom plot size + simple room quantity list
//   3. AI House Planner     → GENERATE HOUSE PLAN (remote AI when configured,
//                             deterministic built-in planner otherwise — the
//                             app NEVER depends on a paid API, spec §8)
//   4. Review & Save        → edit the blueprint inline, then save the
//                             project + house plan to Firestore
//
// The car porch (garage space) is reserved automatically by the planner for
// every plan — users don't need to add it as a room.
//
// The wizard applies the same posting gates as PostProjectScreen (profile
// completeness, NIC approval, plan quota) because it creates a real project.
// =============================================================================

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import 'package:ali_app/house_planner/models/house_plan_models.dart';
import 'package:ali_app/house_planner/screens/blueprint_view_screen.dart';
import 'package:ali_app/house_planner/services/house_plan_service.dart';
import 'package:ali_app/house_planner/services/house_planning_provider.dart';
import 'package:ali_app/house_planner/utils/plot_units.dart';
import 'package:ali_app/house_planner/widgets/blueprint_painter.dart';
import 'package:ali_app/Client/client_project_detail.dart';

class CreateProjectWizard extends StatefulWidget {
  const CreateProjectWizard({super.key});

  @override
  State<CreateProjectWizard> createState() => _CreateProjectWizardState();
}

class _CreateProjectWizardState extends State<CreateProjectWizard> {
  int _step = 0;
  static const int _lastStep = 3;

  // ── posting gates (same rules as PostProjectScreen) ─────────
  bool _checkingPlan = true;
  bool _canCreate = false;
  String _blockReason = '';

  // ── step 1: project & location ──────────────────────────────
  final _nameCtrl = TextEditingController();
  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  String _kind = 'New House';

  // location — typed manually first, map pin optional
  final _locNameCtrl = TextEditingController();
  String _city = '';
  double? _lat;
  double? _lng;
  String _address = '';
  bool _showMap = false;

  // ── step 2: plot & rooms ────────────────────────────────────
  final _widthCtrl = TextEditingController(text: '25');
  final _lengthCtrl = TextEditingController(text: '45');
  final _areaCtrl = TextEditingController(text: '1125');
  String _areaUnit = 'sqft'; // 'marla' | 'kanal' | 'sqft' | 'sqyd' (gaz)
  String _unit = 'ft';
  final Set<int> _floors = {0};
  String _presetId = '5marla'; // default: the classic 5 Marla / 120 gaj home
  final List<RoomRequirement> _requirements = [];

  // ── plot photos (optional — uploaded to Cloudinary on save) ─
  final ImagePicker _imagePicker = ImagePicker();
  final List<File> _pickedImages = [];
  static const int _maxPhotos = 5;

  // ── step 3: generation ──────────────────────────────────────
  HousePlan? _plan;
  PlanGenerationResult? _genResult;
  bool _generating = false;
  int _genProgress = 0; // 0..3 ticks (spec §21)
  String? _genError;

  // ── step 4: save ────────────────────────────────────────────
  bool _saving = false;

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _amberD = Color(0xFFA8861D);
  static const _amberL = Color(0xFFFBF6E3);
  static const _surface = Color(0xFFF7F5EF);
  static const _white = Colors.white;
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _red = Color(0xFFDC2626);

  static const _kinds = [
    'New House',
    'Renovation',
    'Commercial',
    'Apartment',
    'Other',
  ];

  /// Wizard kind → existing project category so the contractors' browse feed
  /// filters keep working (spec §38: don't fork the project system).
  static const _kindToCategory = {
    'New House': 'New Construction',
    'Renovation': 'Renovation',
    'Commercial': 'Construction',
    'Apartment': 'New Construction',
    'Other': 'Construction',
  };

  static const _cities = [
    'Karachi',
    'Lahore',
    'Islamabad',
    'Rawalpindi',
    'Faisalabad',
    'Multan',
    'Peshawar',
    'Hyderabad',
    'Sialkot',
    'Gujranwala',
    'Quetta',
    'Bahawalpur',
    'Sargodha',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _checkClientPlan();
    // start from the most common Pakistani home package — user tweaks from
    // here or taps another preset
    _applyPreset(kHousePresets.firstWhere((p) => p.id == _presetId));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _locNameCtrl.dispose();
    _widthCtrl.dispose();
    _lengthCtrl.dispose();
    _areaCtrl.dispose();
    super.dispose();
  }

  // ── posting gates ───────────────────────────────────────────

  Future<void> _checkClientPlan() async {
    setState(() => _checkingPlan = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        setState(() {
          _canCreate = false;
          _blockReason = 'You must be logged in.';
          _checkingPlan = false;
        });
        return;
      }

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('clients')
          .doc(uid)
          .get();
      if (!doc.exists) {
        doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
      }
      if (!doc.exists) {
        setState(() {
          _canCreate = false;
          _blockReason =
              'Profile not found. Please complete your profile.';
          _checkingPlan = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;
      final fullName = (data['fullName'] as String? ?? '').trim();
      final phone = (data['phone'] as String? ?? '').trim();
      final profilePic = (data['profilePic'] as String? ?? '').trim();
      final nicFront = (data['nic_front_url'] as String? ?? '').trim();
      final nicBack = (data['nic_back_url'] as String? ?? '').trim();

      if (fullName.isEmpty ||
          phone.isEmpty ||
          profilePic.isEmpty ||
          nicFront.isEmpty ||
          nicBack.isEmpty) {
        setState(() {
          _canCreate = false;
          _blockReason =
              'Please complete your profile before creating a project.\n\n'
              'Required: Full Name, Phone, Profile Photo, and both NIC images.';
          _checkingPlan = false;
        });
        return;
      }

      final nicApproved = data['nic_approved'] as bool? ?? false;
      if (!nicApproved) {
        setState(() {
          _canCreate = false;
          _blockReason =
              'Your NIC is under review by our team.\n\nYou will be able to '
              'create projects once your identity is verified. This usually '
              'takes 2–24 hours.';
          _checkingPlan = false;
        });
        return;
      }

      final planName = data['planName'] as String? ?? 'Free';
      final projectsRemaining = data['projectsRemaining'] as int? ?? 0;
      if (planName == 'Free') {
        final existing = await FirebaseFirestore.instance
            .collection('projects')
            .where('clientId', isEqualTo: uid)
            .get();
        if (existing.docs.isNotEmpty) {
          setState(() {
            _canCreate = false;
            _blockReason =
                'Your Free plan allows only 1 project post.\n\nUpgrade to '
                'Standard (5 projects/month) or Premium (unlimited).';
            _checkingPlan = false;
          });
          return;
        }
      } else if (planName != 'Premium' && projectsRemaining <= 0) {
        setState(() {
          _canCreate = false;
          _blockReason =
              'You have used all your project posts for this month on your '
              '$planName plan.\n\nUpgrade to Premium for unlimited posts.';
          _checkingPlan = false;
        });
        return;
      }

      setState(() {
        _canCreate = true;
        _checkingPlan = false;
      });
    } catch (e) {
      setState(() {
        _canCreate = false;
        _blockReason = 'Something went wrong while checking your account. '
            'Please try again.';
        _checkingPlan = false;
      });
    }
  }

  // ── plot / preset helpers ───────────────────────────────────

  double? _parseNum(String s) => double.tryParse(s.trim());

  PlotDetails? _buildPlot() {
    final w = _parseNum(_widthCtrl.text);
    final l = _parseNum(_lengthCtrl.text);
    if (w == null || l == null) return null;
    return PlotDetails(
      width: w,
      length: l,
      unit: _unit,
      includedFloors: _floors.toList()..sort(),
      facing: 'North',
      cornerPlot: false,
      parkingRequired: true, // car porch / garage space always reserved
      gardenRequired: false,
      frontRoadWidth: null,
    );
  }

  void _applyPreset(_HousePreset p) {
    setState(() {
      _presetId = p.id;
      _unit = 'ft';
      _widthCtrl.text = p.width.toString();
      _lengthCtrl.text = p.length.toString();
      _areaUnit = 'sqft';
      _areaCtrl.text = '${p.width * p.length}';
      _floors
        ..clear()
        ..addAll(p.floors);
      _requirements
        ..clear()
        ..addAll(p.buildRooms());
    });
  }

  /// Converts the area field (Marla / Kanal / Sq Ft / Sq Yard gaz) into a
  /// plot W×L using the typical Pakistani frontage ratio of 1 : 1.8 — the
  /// blueprint is then generated from these dimensions.
  void _applyArea() {
    final v = _parseNum(_areaCtrl.text);
    if (v == null || v <= 0) return;
    final sqft = PlotUnits.toSqFt(v, _areaUnit);
    if (sqft < 100 || sqft > 160000) return; // 10×10 ft … ~1.6 lakh sq ft
    const ratio = 1.8;
    var w = math.sqrt(sqft / ratio);
    var l = sqft / w;
    w = (w * 2).round() / 2; // round to 0.5 ft
    l = (l * 2).round() / 2;
    setState(() {
      _presetId = ''; // custom size — no preset highlighted
      _unit = 'ft';
      _widthCtrl.text = _trimFt(w);
      _lengthCtrl.text = _trimFt(l);
    });
  }

  static String _trimFt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  // ── step validation ─────────────────────────────────────────

  String? _stepError() {
    switch (_step) {
      case 0:
        if (_nameCtrl.text.trim().isEmpty) return 'Please enter a project name';
        if (_nameCtrl.text.trim().length < 4) {
          return 'Project name should be at least 4 characters';
        }
        if (_city.isEmpty) return 'Please select your city';
        final min = _parseNum(_budgetMinCtrl.text);
        final max = _parseNum(_budgetMaxCtrl.text);
        if (min != null && min < 0) return 'Budget cannot be negative';
        if (min != null && max != null && max < min) {
          return 'Maximum budget should be above the minimum';
        }
      case 1:
        final plot = _buildPlot();
        if (plot == null) return 'Please enter valid plot width and length';
        if (plot.widthFt < 10 || plot.lengthFt < 10) {
          return 'Plot must be at least 10 × 10 ft';
        }
        if (plot.widthFt > 400 || plot.lengthFt > 400) {
          return 'Plot cannot be larger than 400 ft on either side';
        }
        if (_floors.isEmpty) return 'Select at least one floor';
        if (_requirements.isEmpty) {
          return 'Add at least one room (or pick a house preset)';
        }
      case 2:
        if (_plan == null && !_generating) return 'Generate your house plan first';
      case 3:
        return null;
    }
    return null;
  }

  void _next() {
    final err = _stepError();
    if (err != null) {
      _snack(err);
      return;
    }
    if (_step < _lastStep) {
      setState(() => _step++);
      if (_step == 2 && _plan == null) {
        // auto-start generation the first time the planner step opens
        _generate();
      }
    }
  }

  // ── generation (spec §8, §21, §29) ─────────────────────────

  Future<void> _generate() async {
    final plot = _buildPlot();
    if (plot == null) return;

    setState(() {
      _generating = true;
      _genProgress = 0;
      _genError = null;
      _genResult = null;
    });

    // progress ticks (spec §21 checklist)
    final ticker = Timer.periodic(const Duration(milliseconds: 450), (t) {
      if (!mounted || !_generating) {
        t.cancel();
        return;
      }
      if (_genProgress < 2) setState(() => _genProgress++);
    });

    try {
      final result = await HousePlannerService.generatePlan(
        plot: plot,
        requirements: _requirements,
      );
      ticker.cancel();
      if (!mounted) return;
      setState(() {
        _generating = false;
        _genProgress = 3;
        _plan = result.plan;
        _genResult = result;
      });
    } catch (e) {
      ticker.cancel();
      if (!mounted) return;
      setState(() {
        _generating = false;
        _genError = 'Plan generation failed. '
            'Check your connection and tap Retry — or go back and adjust '
            'your plot details.';
      });
    }
  }

  // ── save (spec §3 last step) ────────────────────────────────

  Future<void> _saveProject() async {
    if (_plan == null || _saving) return;
    setState(() => _saving = true);

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(uid).get();
      final clientName = (userDoc.data()?['fullName'] as String? ?? '').trim();

      final plot = _buildPlot()!;
      final budgetMin = _budgetMinCtrl.text.trim();
      final budgetMax = _budgetMaxCtrl.text.trim();
      final locName = _locNameCtrl.text.trim();

      // 1. project document (compatible with the existing browse feed)
      final projectRef = await db.collection('projects').add({
        'clientId': uid,
        'clientName': clientName,
        'title': _nameCtrl.text.trim(),
        'description': '',
        'projectType': _kindToCategory[_kind] ?? 'Construction',
        'housePlanKind': _kind,
        'city': _city.isNotEmpty ? _city : null,
        'area': locName.isNotEmpty
            ? locName
            : null,
        'plotSize': '${_widthCtrl.text.trim()} × ${_lengthCtrl.text.trim()} $_unit',
        // exact pin is optional now — only saved when the client dropped one
        'plotLocation':
            (_lat != null && _lng != null) ? GeoPoint(_lat!, _lng!) : null,
        'plotAddress': locName.isNotEmpty ? locName : _address,
        'hasHousePlan': true,
        'budgetMin': budgetMin.isNotEmpty ? budgetMin : null,
        'budgetMax': budgetMax.isNotEmpty ? budgetMax : null,
        'urgentRequired': false,
        'services': const <String>[],
        'status': 'open',
        'bids': [],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. house plan document + version 1 snapshot
      final planId = await HousePlanService.createDraft(
        projectId: projectRef.id,
        plot: plot,
        requirements: _requirements,
        plan: _plan!,
      );
      await projectRef.update({
        'housePlanId': planId,
        'plotDetails': plot.toJson(),
      });

      // 3. plan quota (same accounting as PostProjectScreen)
      final clientDoc = await db.collection('clients').doc(uid).get();
      if (clientDoc.exists) {
        final planName = clientDoc.data()?['planName'] as String? ?? 'Free';
        if (planName != 'Premium') {
          await db.collection('clients').doc(uid).update({
            'projectsRemaining': FieldValue.increment(-1),
          });
        }
      }

      if (!mounted) return;
      setState(() => _saving = false);

      final goDetail = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: _white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: const BoxDecoration(
                    color: _amberL, shape: BoxShape.circle),
                child:
                    const Icon(Icons.check_circle_rounded, color: _amberD, size: 42),
              ),
              const SizedBox(height: 14),
              const Text('Project Created!',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: _navy)),
              const SizedBox(height: 6),
              const Text(
                'Your house plan is saved and contractors can now find '
                'your project.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5, height: 1.5, color: _textSec),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Done', style: TextStyle(color: _textSec)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy,
                  foregroundColor: _white,
                  elevation: 0),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('View Project'),
            ),
          ],
        ),
      );

      if (!mounted) return;
      if (goDetail == true) {
        final fresh = await projectRef.get();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _openClientDetail(
              projectRef.id,
              fresh.data() ?? {},
            ),
          ),
        );
      } else {
        Navigator.pop(context, projectRef.id);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Could not save the project: $e');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
              Text(msg, style: const TextStyle(color: _white, fontSize: 13)),
          backgroundColor: _red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  Future<bool> _confirmDiscard() async {
    if (_nameCtrl.text.trim().isEmpty && _plan == null && _step == 0) {
      return true;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Discard this project?',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: const Text(
            'Your entered details and generated plan will be lost.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: _textSec)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep editing', style: TextStyle(color: _navy)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: _red, foregroundColor: _white, elevation: 0),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return discard == true;
  }

  // ── build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard()) {
          if (context.mounted) Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: _surface,
        appBar: _appBar(),
        body: _checkingPlan
            ? const Center(child: CircularProgressIndicator(color: _amber))
            : !_canCreate
                ? _blockedView()
                : Column(
                    children: [
                      _stepIndicator(),
                      Expanded(child: _stepBody()),
                    ],
                  ),
        bottomNavigationBar: (_checkingPlan || !_canCreate)
            ? null
            : _bottomBar(),
      ),
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
        backgroundColor: _navy,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: _white),
          onPressed: () async {
            if (await _confirmDiscard() && mounted) {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text('Create Project',
            style: TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w800)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: _aiBadge(),
            ),
          ),
        ],
      );

  Widget _aiBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: _amber,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'AI PLANNER',
          style: TextStyle(
              color: _navy, fontSize: 9, fontWeight: FontWeight.w900),
        ),
      );

  Widget _blockedView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 44, color: _navy),
              const SizedBox(height: 14),
              Text(
                _blockReason,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, height: 1.6, color: _textSec),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: _white,
                    elevation: 0),
                onPressed: _checkClientPlan,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );

  // ── step indicator ──────────────────────────────────────

  static const _stepTitles = [
    'Project',
    'Plot & Rooms',
    'AI Planner',
    'Review',
  ];

  Widget _stepIndicator() {
    return Container(
      color: _white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          for (var i = 0; i <= _lastStep; i++) ...[
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: i <= _step ? _amber : _border,
                ),
              ),
            _stepDot(i),
          ],
        ],
      ),
    );
  }

  Widget _stepDot(int i) {
    final done = i < _step;
    final active = i == _step;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: done
                ? _amber
                : active
                    ? _navy
                    : _border,
            shape: BoxShape.circle,
            border: active ? Border.all(color: _amber, width: 2) : null,
          ),
          child: Center(
            child: done
                ? const Icon(Icons.check_rounded, size: 15, color: _navy)
                : Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: active ? _white : _textSec,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          _stepTitles[i],
          style: TextStyle(
            fontSize: 8.5,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
            color: active ? _navy : _textSec,
          ),
        ),
      ],
    );
  }

  // ── bottom bar ──────────────────────────────────────────

  Widget _bottomBar() {
    final isLast = _step == _lastStep;
    return Container(
      color: _white,
      padding: EdgeInsets.fromLTRB(
          16, 10, 16, 12 + MediaQuery.of(context).padding.bottom),
      child: Row(
        children: [
          if (_step > 0)
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _border),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _generating ? null : () => setState(() => _step--),
                icon: const Icon(Icons.arrow_back_rounded, size: 17),
                label: const Text('Back',
                    style:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ),
            ),
          if (_step > 0) const SizedBox(width: 12),
          Expanded(
            flex: _step > 0 ? 2 : 1,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? _amber : _navy,
                foregroundColor: isLast ? _navy : _white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _buttonBusy ? null : (isLast ? _saveProject : _next),
              icon: _buttonBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(
                      isLast ? Icons.check_rounded : Icons.arrow_forward_rounded,
                      size: 17),
              label: Text(
                _buttonLabel,
                style: const TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _buttonBusy => _generating || (_step == _lastStep && _saving);

  String get _buttonLabel {
    if (_generating) return 'Generating…';
    if (_step == _lastStep) return _saving ? 'SAVING…' : 'SAVE PROJECT';
    return 'Continue';
  }

  // ── step bodies ─────────────────────────────────────────

  Widget _stepBody() {
    return switch (_step) {
      0 => _basicsStep(),
      1 => _plotStep(),
      2 => _plannerStep(),
      _ => _reviewStep(),
    };
  }

  // STEP 1 — project info + manual location (map optional) ────

  Widget _basicsStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _intro(
          Icons.home_work_rounded,
          'Tell us about your project',
          'Just the important details — name, type, budget and where your '
              'plot is.',
        ),
        const SizedBox(height: 16),
        _field(
          label: 'Project Name',
          controller: _nameCtrl,
          hint: 'e.g. My 5 Marla House',
        ),
        const SizedBox(height: 18),
        const Text('Project Type',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kinds.map((k) {
            final active = k == _kind;
            return GestureDetector(
              onTap: () => setState(() => _kind = k),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                  color: active ? _navy : _white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: active ? _navy : _border),
                ),
                child: Text(
                  k,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? _white : _navy,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _field(
                label: 'Budget Min (PKR, optional)',
                controller: _budgetMinCtrl,
                hint: 'e.g. 5000000',
                digits: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                label: 'Budget Max (PKR, optional)',
                controller: _budgetMaxCtrl,
                hint: 'e.g. 8000000',
                digits: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── location: manual name first ────────────────────────
        const Text('Location',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 8),
        _field(
          label: 'Location Name',
          controller: _locNameCtrl,
          hint: 'e.g. DHA Phase 5, Lahore',
        ),
        const SizedBox(height: 14),
        _cityDropdown(),
        const SizedBox(height: 14),

        // optional exact pin
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _navy,
            side: const BorderSide(color: _border),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => setState(() => _showMap = !_showMap),
          icon: Icon(
            _showMap ? Icons.expand_less_rounded : Icons.map_rounded,
            size: 17,
            color: _amberD,
          ),
          label: Text(
            _showMap
                ? 'Hide map'
                : 'Pin exact location on map (optional)',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
        if (_showMap) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 300,
              child: _PlotMapPicker(
                initialLat: _lat,
                initialLng: _lng,
                onChanged: (lat, lng, address, city, area) {
                  _lat = lat;
                  _lng = lng;
                  _address = address;
                  // auto-fill the manual fields only where still empty
                  if (_city.isEmpty && city.isNotEmpty) {
                    final match = _cities
                        .where((c) => c.toLowerCase() == city.toLowerCase())
                        .firstOrNull;
                    _city = match ?? 'Other';
                  }
                  if (_locNameCtrl.text.trim().isEmpty &&
                      area.isNotEmpty) {
                    _locNameCtrl.text = area;
                  }
                  if (mounted) setState(() {});
                },
              ),
            ),
          ),
          if (_lat != null) ...[
            const SizedBox(height: 8),
            Text(
              _address.isNotEmpty
                  ? _address
                  : 'Pinned at ${_lat!.toStringAsFixed(4)}, '
                      '${_lng!.toStringAsFixed(4)}',
              style: const TextStyle(
                  fontSize: 11, height: 1.4, color: _textSec),
            ),
          ],
        ],
      ],
    );
  }

  Widget _cityDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('City',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _textSec)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _city.isEmpty ? null : _city,
              isExpanded: true,
              hint: const Text('Select your city',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFFA6B2AB))),
              items: _cities
                  .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(c,
                          style: const TextStyle(
                              fontSize: 13.5, color: _navy))))
                  .toList(),
              onChanged: (v) => setState(() => _city = v ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  // STEP 2 — plot + rooms via presets ──────────────────────

  Widget _plotStep() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _intro(
          Icons.square_foot_rounded,
          'Pick your house type',
          'Choose a ready-made Pakistani house package, or type your own plot '
              'size below and adjust the rooms.',
        ),
        const SizedBox(height: 14),

        // ── presets ───────────────────────────────────────
        ...kHousePresets.map(_presetCard),
        const SizedBox(height: 6),
        Text(
          'Car porch (garage space) is added automatically to every plan.',
          style: const TextStyle(
              fontSize: 10.5, height: 1.4, color: _textSec),
        ),
        const SizedBox(height: 16),

        // ── plot size ─────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _field(
                label: 'Plot Width',
                controller: _widthCtrl,
                hint: '25',
                digits: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _field(
                label: 'Plot Length',
                controller: _lengthCtrl,
                hint: '45',
                digits: true,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unit',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _textSec)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: _white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _border),
                  ),
                  child: Row(
                    children: [
                      _unitBtn('ft'),
                      _unitBtn('m'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── floors ────────────────────────────────────────
        const Text('Floors',
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w800, color: _navy)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _floorChip(-1, 'Basement'),
            _floorChip(0, 'Ground'),
            _floorChip(1, 'First'),
            _floorChip(2, 'Second'),
          ],
        ),
        const SizedBox(height: 18),

        // ── rooms (simple quantity list) ──────────────────
        Row(
          children: [
            const Expanded(
              child: Text('Rooms',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: _navy)),
            ),
            Text('${_requirements.fold(0, (a, r) => a + r.quantity)} total',
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _textSec)),
          ],
        ),
        const SizedBox(height: 8),
        ..._requirements.map(_roomRow),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: _amberD,
            side: const BorderSide(color: _amber),
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _addRoomSheet,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add Room',
              style:
                  TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
        ),
      ],
    );
  }

  Widget _presetCard(_HousePreset p) {
    final active = _presetId == p.id;
    return GestureDetector(
      onTap: () => _applyPreset(p),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: active ? _amberL : _white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: active ? _amber : _border, width: active ? 2 : 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: active ? _amber : _surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                switch (p.id) {
                  '3marla' => Icons.cottage_rounded,
                  '5marla' => Icons.home_rounded,
                  '10marla' => Icons.villa_rounded,
                  _ => Icons.castle_rounded,
                },
                size: 19,
                color: _navy,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${p.title} — ${p.subtitle}',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                          color: _navy)),
                  const SizedBox(height: 3),
                  Text(
                    p.roomsSummary,
                    style: const TextStyle(
                        fontSize: 10.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                        color: _textSec),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              active
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: active ? _amberD : _border,
            ),
          ],
        ),
      ),
    );
  }

  Widget _unitBtn(String u) {
    final active = _unit == u;
    return GestureDetector(
      onTap: () => setState(() => _unit = u),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _navy : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          u,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: active ? _white : _textSec,
          ),
        ),
      ),
    );
  }

  Widget _floorChip(int f, String label) {
    final active = _floors.contains(f);
    return GestureDetector(
      onTap: () => setState(() {
        if (active) {
          if (_floors.length > 1) _floors.remove(f);
        } else {
          _floors.add(f);
        }
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? _navy : _white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? _navy : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 15,
              color: active ? _white : _textSec,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? _white : _navy,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// One compact room row: color dot, label, attached-bath chip (bedrooms
  /// only), quantity stepper and delete. No sizes / notes / floor prefs —
  /// the planner handles those details.
  Widget _roomRow(RoomRequirement req) {
    final spec = req.spec;
    final isBedroom = spec.group == RoomGroup.bedroom;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: spec.color,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(req.label,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _navy)),
                if (isBedroom) ...[
                  const SizedBox(height: 3),
                  GestureDetector(
                    onTap: () => setState(
                        () => req.attachedBathroom = !req.attachedBathroom),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: req.attachedBathroom
                            ? _amberL
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color:
                                req.attachedBathroom ? _amber : _border),
                      ),
                      child: Text(
                        req.attachedBathroom
                            ? 'bath attached'
                            : 'tap: attach bath',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color:
                                req.attachedBathroom ? _amberD : _textSec),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          _qtyBtn(Icons.remove_rounded,
              () => setState(() => req.quantity = (req.quantity - 1).clamp(1, 12))),
          Container(
            alignment: Alignment.center,
            width: 26,
            child: Text('${req.quantity}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: _navy)),
          ),
          _qtyBtn(Icons.add_rounded,
              () => setState(() => req.quantity = (req.quantity + 1).clamp(1, 12))),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 19, color: _red),
            onPressed: () => setState(() => _requirements.remove(req)),
          ),
        ],
      ),
    );
  }

  Widget _qtyBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, size: 14, color: _navy),
        ),
      );

  Future<void> _addRoomSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Add Room',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w800, color: _navy)),
          const SizedBox(height: 8),
          ...kSelectableRoomTypes.map(
            (s) => ListTile(
              dense: true,
              leading: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: s.color,
                  border: Border.all(color: _border),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              title: Text(s.label,
                  style:
                      const TextStyle(fontSize: 13.5, color: _navy)),
              trailing: _requirements.any((r) => r.type == s.type)
                  ? const Icon(Icons.add_circle_rounded,
                      size: 18, color: _amberD)
                  : const Icon(Icons.add_circle_outline_rounded,
                      size: 18, color: _textSec),
              onTap: () => Navigator.pop(context, s.type),
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() {
      final existing =
          _requirements.where((r) => r.type == picked).firstOrNull;
      if (existing != null) {
        existing.quantity = (existing.quantity + 1).clamp(1, 12);
      } else {
        _requirements.add(RoomRequirement(type: picked));
      }
    });
  }

  // STEP 3 — AI house planner (spec §7, §8, §21) ─────────────

  Widget _plannerStep() {
    final plot = _buildPlot();
    final roomCount = _requirements.fold(0, (a, r) => a + r.quantity);
    final sortedFloors = _floors.toList()..sort();
    final floorLabels = sortedFloors
        .map((f) => HousePlanFloor.floorLabel(f).split(' ').first)
        .join(', ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _intro(
          Icons.auto_awesome_rounded,
          'AI House Planner',
          'Your plan is generated from your plot and rooms — instantly, on '
              'your device.',
        ),
        const SizedBox(height: 16),

        // ── project summary (spec §7) ────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              _summaryRow(Icons.crop_square_rounded,
                  'Plot', plot?.sizeLabel ?? '—'),
              _summaryRow(Icons.layers_rounded, 'Floors',
                  '${_floors.length} ($floorLabels)'),
              _summaryRow(Icons.meeting_room_rounded, 'Rooms', '$roomCount'),
              _summaryRow(Icons.local_parking_rounded, 'Car Porch', 'Included'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── requirements preview ─────────────────────────
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _requirements
              .map((r) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _amberL,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${r.label}${r.quantity > 1 ? ' ×${r.quantity}' : ''}',
                      style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: _amberD),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 20),

        if (_plan == null && !_generating && _genError == null) ...[
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _amber,
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13)),
              ),
              onPressed: _generate,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: const Text('GENERATE HOUSE PLAN',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900)),
            ),
          ),
        ],

        if (_generating) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border),
            ),
            child: Column(
              children: [
                const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: _amber)),
                const SizedBox(height: 16),
                _genTick(0, 'Understanding requirements'),
                _genTick(1, 'Creating room layout'),
                _genTick(2, 'Generating blueprint'),
              ],
            ),
          ),
        ],

        if (_genError != null) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        size: 16, color: _red),
                    const SizedBox(width: 6),
                    const Text('Generation failed',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: _red)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(_genError!,
                    style: const TextStyle(
                        fontSize: 11.5, height: 1.5, color: _textSec)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: _white,
                        elevation: 0),
                    onPressed: _generate,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Retry'),
                  ),
                ),
              ],
            ),
          ),
        ],

        if (_plan != null) ...[
          // ── result card ─────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _amber),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.check_circle_rounded,
                        color: _amberD, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _genResult?.usedProvider == 'ai'
                            ? 'AI-generated plan ready'
                            : 'Built-in planner result ready',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: _navy),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_plan!.plotWidthFt.round()} × ${_plan!.plotLengthFt.round()} ft · '
                  '${_plan!.totalRooms} rooms · '
                  '${_plan!.coveredArea.round()} sq ft covered',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600, color: _navy),
                ),
                if (_genResult?.fallbackUsed == true &&
                    _genResult?.fallbackReason != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _amberL,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 14, color: _amberD),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            _genResult!.fallbackReason!,
                            style: const TextStyle(
                                fontSize: 10.5,
                                height: 1.5,
                                color: _textSec),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _navy,
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        onPressed: _generating
                            ? null
                            : () => setState(() => _plan = null),
                        icon: const Icon(Icons.refresh_rounded, size: 15),
                        label: const Text('Regenerate',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap Continue to review, edit in 2D, explore 3D and save.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10.5, color: _textSec),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _genTick(int index, String label) {
    final done = _genProgress > index;
    final active = _genProgress == index && _generating;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          if (done)
            const Icon(Icons.check_rounded, size: 16, color: _amberD)
          else if (active)
            const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: _amberD))
          else
            const Icon(Icons.circle_outlined, size: 16, color: _border),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: done || active ? FontWeight.w700 : FontWeight.w500,
              color: done || active ? _navy : _textSec,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: _amberD),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: _textSec)),
          const Spacer(),
          Text(value,
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                  color: _navy)),
        ],
      ),
    );
  }

  // STEP 4 — review & save (spec §3 last step, §34 disclaimer) ─

  Widget _reviewStep() {
    final plan = _plan!;
    final roomCount = _requirements.fold(0, (a, r) => a + r.quantity);
    final previewFloor = plan.floors.first.floor;
    final longSide = plan.plotWidthFt > plan.plotLengthFt
        ? plan.plotWidthFt
        : plan.plotLengthFt;
    final pxPerFt = 300 / longSide;
    final locName = _locNameCtrl.text.trim();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        _intro(
          Icons.fact_check_rounded,
          'Review & save',
          'Check your plan, edit the blueprint if needed, then save the '
              'project — contractors will see the construction details.',
        ),
        const SizedBox(height: 16),

        // ── blueprint preview (read-only thumbnail) ──────────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: FittedBox(
                  child: SizedBox(
                    width: plan.plotWidthFt * pxPerFt + 40,
                    height: plan.plotLengthFt * pxPerFt + 40,
                    child: CustomPaint(
                      painter: BlueprintPainter(
                        plan: plan,
                        floor: previewFloor,
                        scale: pxPerFt,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${plan.plotWidthFt.round()} × ${plan.plotLengthFt.round()} ft · '
                '${HousePlanFloor.floorLabel(previewFloor)} · '
                '${plan.totalRooms} rooms · '
                '${plan.coveredArea.round()} sq ft covered',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: _navy),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── final details summary ───────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              _summaryRow(Icons.home_work_rounded, 'Project',
                  _nameCtrl.text.trim()),
              _summaryRow(Icons.category_rounded, 'Type', _kind),
              _summaryRow(Icons.location_on_rounded, 'Location',
                  locName.isNotEmpty
                      ? '$_city · $locName'
                      : _city),
              _summaryRow(Icons.meeting_room_rounded, 'Rooms requested',
                  '$roomCount'),
              if (_budgetMinCtrl.text.trim().isNotEmpty)
                _summaryRow(Icons.payments_rounded, 'Budget',
                    'Rs ${_budgetMinCtrl.text.trim()} – ${_budgetMaxCtrl.text.trim()}'),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // ── open the full viewer (EDIT / 3D / 360) ──────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: _navy,
              side: const BorderSide(color: _amber),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _openBlueprintViewer,
            icon: const Icon(Icons.architecture_rounded, size: 18),
            label: const Text('REVIEW, EDIT & EXPLORE THE BLUEPRINT',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 12),

        // ── architectural safety disclaimer (spec §34) ─────
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _amberL,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: _amberD),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'AI-generated house plans are conceptual. Final construction '
                  'drawings must be prepared by a qualified architect/engineer.',
                  style: TextStyle(
                      fontSize: 10, height: 1.4, color: _textSec),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Opens the full blueprint viewer (EDIT / 3D / 360 — client mode).
  /// Edits made there flow back through [onPlanEdited] and are saved with
  /// the project.
  void _openBlueprintViewer() {
    if (_plan == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlueprintViewScreen(
          plan: _plan!.copy(),
          projectTitle: _nameCtrl.text.trim().isNotEmpty
              ? _nameCtrl.text.trim()
              : 'AI House Plan',
          onPlanEdited: (p) => setState(() => _plan = p),
        ),
      ),
    );
  }

  // ── shared widgets ──────────────────────────────────────

  Widget _intro(IconData icon, String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration:
                const BoxDecoration(color: _amberL, shape: BoxShape.circle),
            child: Icon(icon, size: 19, color: _amberD),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: _navy)),
                const SizedBox(height: 3),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11.5, height: 1.5, color: _textSec)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    bool digits = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: _textSec)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: digits
              ? const TextInputType.numberWithOptions(decimal: true)
              : null,
          style: const TextStyle(fontSize: 13.5, color: _navy),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFA6B2AB)),
            filled: true,
            fillColor: _white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _border),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// PAKISTANI HOUSE PRESETS — one-tap "standard home" packages
// ─────────────────────────────────────────────────────────────

class _HousePreset {
  const _HousePreset({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.width,
    required this.length,
    required this.floors,
    required this.roomsSummary,
    required this.buildRooms,
  });

  final String id;
  final String title;
  final String subtitle;
  final int width; // ft
  final int length; // ft
  final List<int> floors;
  final String roomsSummary;
  final List<RoomRequirement> Function() buildRooms;
}

const kHousePresets = [
  _HousePreset(
    id: '3marla',
    title: '3 Marla House',
    subtitle: '20 × 40 ft (900 sq ft)',
    width: 20,
    length: 40,
    floors: [0],
    roomsSummary:
        '2 bedrooms (1 master) · 1 drawing room · 1 attached bath · '
        '1 washroom · kitchen · lounge · car porch',
    buildRooms: _rooms3Marla,
  ),
  _HousePreset(
    id: '5marla',
    title: '5 Marla House',
    subtitle: '25 × 45 ft — 120 gaj (1125 sq ft)',
    width: 25,
    length: 45,
    floors: [0],
    roomsSummary:
        '2 bedrooms (1 master) · 1 drawing room · 2 attached baths · '
        '1 extra washroom · kitchen · TV lounge · car porch (garage)',
    buildRooms: _rooms5Marla,
  ),
  _HousePreset(
    id: '10marla',
    title: '10 Marla House',
    subtitle: '35 × 65 ft (2275 sq ft)',
    width: 35,
    length: 65,
    floors: [0, 1],
    roomsSummary:
        'Ground: drawing room · 1 bed + attached bath · kitchen · lounge · '
        'car porch — First: 2 beds + attached baths · terrace',
    buildRooms: _rooms10Marla,
  ),
  _HousePreset(
    id: '1kanal',
    title: '1 Kanal House',
    subtitle: '50 × 90 ft (4500 sq ft)',
    width: 50,
    length: 90,
    floors: [0, 1],
    roomsSummary:
        'Ground: drawing + dining · 2 beds with baths · kitchen · lounge · '
        'lawn · car porch — First: 3 beds with baths · terrace',
    buildRooms: _rooms1Kanal,
  ),
];

List<RoomRequirement> _rooms3Marla() => [
      RoomRequirement(type: 'master_bedroom', attachedBathroom: true),
      RoomRequirement(type: 'bedroom'),
      RoomRequirement(type: 'drawing_room'),
      RoomRequirement(type: 'bathroom'),
      RoomRequirement(type: 'kitchen'),
      RoomRequirement(type: 'tv_lounge'),
    ];

List<RoomRequirement> _rooms5Marla() => [
      RoomRequirement(type: 'master_bedroom', attachedBathroom: true),
      RoomRequirement(type: 'bedroom', attachedBathroom: true),
      RoomRequirement(type: 'drawing_room'),
      RoomRequirement(type: 'bathroom'),
      RoomRequirement(type: 'kitchen'),
      RoomRequirement(type: 'tv_lounge'),
    ];

List<RoomRequirement> _rooms10Marla() => [
      RoomRequirement(type: 'master_bedroom', attachedBathroom: true),
      RoomRequirement(type: 'bedroom', attachedBathroom: true),
      RoomRequirement(type: 'drawing_room'),
      RoomRequirement(type: 'bathroom'),
      RoomRequirement(type: 'kitchen'),
      RoomRequirement(type: 'tv_lounge'),
      RoomRequirement(type: 'bedroom', quantity: 2, preferredFloor: 1),
      RoomRequirement(type: 'terrace', preferredFloor: 1),
    ];

List<RoomRequirement> _rooms1Kanal() => [
      RoomRequirement(type: 'master_bedroom', attachedBathroom: true),
      RoomRequirement(type: 'bedroom', attachedBathroom: true),
      RoomRequirement(type: 'drawing_room'),
      RoomRequirement(type: 'dining_room'),
      RoomRequirement(type: 'bathroom'),
      RoomRequirement(type: 'kitchen'),
      RoomRequirement(type: 'tv_lounge'),
      RoomRequirement(type: 'garden'),
      RoomRequirement(type: 'bedroom', quantity: 3, preferredFloor: 1),
      RoomRequirement(type: 'terrace', preferredFloor: 1),
    ];

// ─────────────────────────────────────────────────────────────
// MAP PICKER — compact version of the existing plot picker
// (google_maps_flutter + geocoding, already used by the app)
// ─────────────────────────────────────────────────────────────

class _PlotMapPicker extends StatefulWidget {
  const _PlotMapPicker({
    this.initialLat,
    this.initialLng,
    required this.onChanged,
  });

  final double? initialLat;
  final double? initialLng;
  final void Function(
      double lat, double lng, String address, String city, String area)
      onChanged;

  @override
  State<_PlotMapPicker> createState() => _PlotMapPickerState();
}

class _PlotMapPickerState extends State<_PlotMapPicker> {
  GoogleMapController? _controller;
  late LatLng _center;
  String _address = '';
  String _city = '';
  String _area = '';
  bool _loadingAddress = false;

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _white = Colors.white;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
    } else {
      _center = const LatLng(24.8607, 67.0011); // Karachi default
      _useCurrentLocation();
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final pos = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      _center = LatLng(pos.latitude, pos.longitude);
      _controller
          ?.animateCamera(CameraUpdate.newLatLngZoom(_center, 16));
      _reverseGeocode(_center);
    } catch (_) {
      // keep default center
    }
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loadingAddress = true);
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
          pos.latitude, pos.longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final city = <String?>[
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ].where((e) => e != null && e.isNotEmpty).firstOrNull ?? '';

        var area = <String?>[p.subLocality, p.locality, p.street]
            .where((e) => e != null && e.isNotEmpty)
            .firstOrNull ?? '';
        for (final candidate in [p.subLocality, p.locality, p.street]) {
          if (candidate != null &&
              candidate.isNotEmpty &&
              candidate.toLowerCase() != city.toLowerCase()) {
            area = candidate;
            break;
          }
        }

        final address = [
          p.street,
          p.subLocality,
          p.locality,
          p.subAdministrativeArea,
        ].where((e) => e != null && e.isNotEmpty).join(', ');

        if (!mounted) return;
        setState(() {
          _address = address;
          _city = city;
          _area = area;
        });
        widget.onChanged(pos.latitude, pos.longitude, _address, _city, _area);
      }
    } catch (_) {
      if (!mounted) return;
      widget.onChanged(pos.latitude, pos.longitude, '', '', '');
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(target: _center, zoom: 15),
          onMapCreated: (c) => _controller = c,
          onCameraMove: (pos) => _center = pos.target,
          onCameraIdle: () => _reverseGeocode(_center),
          myLocationEnabled: true,
          myLocationButtonEnabled: false,
          zoomControlsEnabled: false,
        ),
        const IgnorePointer(
          child: Center(
            child: Padding(
              padding: EdgeInsets.only(bottom: 30),
              child: Icon(Icons.location_pin,
                  size: 44, color: Color(0xFFDC2626)),
            ),
          ),
        ),
        Positioned(
          right: 10,
          bottom: 14,
          child: FloatingActionButton.small(
            heroTag: 'wizardMyLocation',
            backgroundColor: _white,
            onPressed: _useCurrentLocation,
            child: const Icon(Icons.my_location_rounded,
                size: 18, color: _navy),
          ),
        ),
        if (_loadingAddress)
          const Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: _amber),
              ),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Launcher — opens the existing client project detail after save
// ─────────────────────────────────────────────────────────────

Widget _openClientDetail(String projectId, Map<String, dynamic> data) =>
    ClientProjectDetailScreen(projectId: projectId, data: data);

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:image_picker/image_picker.dart';
import 'package:ali_app/Payment&Requests/billing_screen.dart';
// TODO: adjust this import path to wherever CloudinaryService actually
// lives in your project (same service used for NIC/profile photo uploads).
// This screen assumes: `Future<String?> CloudinaryService.uploadImage(File file)`
// — verify the real signature and update `_uploadProjectImages()` below if
// it differs (e.g. if it needs a folder name or BuildContext).
import 'package:ali_app/MessageAndNotification/cloudinary_service.dart';
import 'package:ali_app/services/gemini_service.dart';

import 'package:ali_app/Client/client_profile.dart';

class PostProjectScreen extends StatefulWidget {
  const PostProjectScreen({super.key});

  @override
  State<PostProjectScreen> createState() => _PostProjectScreenState();
}

class _PostProjectScreenState extends State<PostProjectScreen> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _budgetMinCtrl = TextEditingController();
  final _budgetMaxCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _startDateCtrl = TextEditingController();
  final _plotSizeCtrl = TextEditingController();

  String? _projectType;
  String? _selectedCity;
  String? _selectedArea;
  String _plotSizeUnit = 'Marla';
  bool _isUrgent = false;
  bool _isLoading = false;
  bool _checkingPlan = true;
  bool _canPost = false;
  String _blockReason = '';

  // ── AI features state ────────────────────────────────────
  bool _aiDescLoading = false;
  List<String> _aiSuggestions = [];
  bool _aiEstimateLoading = false;
  AiCostEstimate? _aiEstimate;

  // ── start date + plot location state ─────────────────────
  DateTime? _selectedStartDate;
  double? _plotLat;
  double? _plotLng;
  String _plotAddress = '';
  bool _cityAreaAutoDetected =
      false; // true once city/area came from the map pin
  bool _showManualCityArea = false; // lets the user override auto-detection

  final List<String> _selectedServices = [];

  // ── Project photos ─────────────────────────────────────────
  // Client picks photos of the plot/house; one is marked as the
  // "cover"/main photo shown first on the project card in the browse feed.
  // The exact min/max required depends on the project type (see
  // `_typePhotoRange` below) — bigger jobs (New Construction, Renovation)
  // need more photos than small utility jobs (Plumbing, Waterproofing).
  final List<File> _pickedImages = [];
  int _coverImageIndex = 0;
  bool _uploadingImages = false;
  final ImagePicker _imagePicker = ImagePicker();

  // min/max required photo count per project type
  static const Map<String, Map<String, int>> _typePhotoRange = {
    'New Construction': {'min': 6, 'max': 8},
    'Renovation': {'min': 5, 'max': 8},
    'Plumbing': {'min': 4, 'max': 5},
    'Electrical': {'min': 4, 'max': 6},
    'Painting': {'min': 4, 'max': 6},
    'Carpentry': {'min': 4, 'max': 6},
    'Tiling': {'min': 4, 'max': 6},
    'Waterproofing': {'min': 4, 'max': 5},
    'Other': {'min': 4, 'max': 5},
  };

  // falls back to a sensible default (4–8) before a project type is picked
  int get _minPhotos => _typePhotoRange[_projectType]?['min'] ?? 4;
  int get _maxPhotos => _typePhotoRange[_projectType]?['max'] ?? 8;

  // ── project types that need a plot / property size ────────
  // (utility-only jobs like plumbing/electrical repairs on an
  // existing structure don't need a size field)
  static const Set<String> _typesNeedingSize = {
    'New Construction',
    'Renovation',
    'Tiling',
    'Waterproofing',
    'Painting',
    'Carpentry',
  };

  static const List<String> _plotSizeUnits = [
    'Marla',
    'Kanal',
    'Sq. Yards',
    'Sq. Ft',
  ];

  // ── Dynamic description suggestions per project type ──────
  // Uses the client's actual entered plot size + unit (e.g. "8 Marla",
  // "120 Sq. Yards") wherever the suggestion mentions a size, instead of
  // a hardcoded "5 marla" that may not match what they picked above.
  List<String> _descSuggestionsFor(String type) {
    final rawSize = _plotSizeCtrl.text.trim();
    final sizeStr = rawSize.isNotEmpty ? '$rawSize $_plotSizeUnit' : null;

    switch (type) {
      case 'New Construction':
        return [
          'Need to construct a new ${sizeStr ?? '5 Marla'} house including grey structure, plaster, and finishing.',
          'Looking for a contractor to build a boundary wall and gate for a ${sizeStr ?? '10 Marla'} plot.',
          'Require full construction of a 2-storey commercial building with basement parking.',
          'Need to build a 3-bedroom house on a${sizeStr != null ? ' $sizeStr' : ' corner'} plot with modern finishing.',
          'Looking for construction of a farmhouse including rooms, kitchen, and lawn area.',
        ];
      case 'Renovation':
        return [
          'Need complete renovation of a${sizeStr != null ? ' $sizeStr' : ''} 3-bedroom apartment including tiles, paint, and woodwork.',
          'Looking to renovate my kitchen and bathrooms with modern fittings and tiles.',
          'Require renovation of an old${sizeStr != null ? ' $sizeStr' : ''} house — remove old plaster, redo flooring and paint.',
          'Need to convert a room into a modern office space with false ceiling and lighting.',
          'Looking for renovation of a shop front with new signage, flooring, and lighting.',
        ];
      case 'Plumbing':
        return [
          'Need to fix water leakage from bathroom pipes and replace old fittings.',
          'Looking for installation of a new underground water tank and motor pump.',
          'Require complete plumbing work for a newly constructed${sizeStr != null ? ' $sizeStr' : ''} house.',
          'Need to replace old rusted pipes throughout the house with new CPVC pipes.',
          'Looking for installation of roof water tank with new supply lines.',
        ];
      case 'Electrical':
        return [
          'Need complete wiring of a new${sizeStr != null ? ' $sizeStr' : ''} house including DB board, points, and fixtures.',
          'Looking to install solar panels with net metering on a residential property.',
          'Require replacement of old electrical wiring with new concealed wiring.',
          'Need installation of CCTV cameras and security system in my home.',
          'Looking for installation of a 3-phase industrial connection and panel.',
        ];
      case 'Painting':
        return [
          'Need interior and exterior painting of a ${sizeStr ?? '5 Marla'} house with quality paint.',
          'Looking for texture paint work on the drawing room walls and ceiling.',
          'Require painting of a commercial office — walls, ceiling, and woodwork.',
          'Need to repaint the exterior of a${sizeStr != null ? ' $sizeStr' : ''} house with weather-resistant paint.',
          'Looking for decorative paint work including stencil and 3D wall design.',
        ];
      case 'Carpentry':
        return [
          'Need custom wooden kitchen cabinets with granite countertop.',
          'Looking for installation of wooden flooring in 3 bedrooms.',
          'Require complete door and window frames for a newly built${sizeStr != null ? ' $sizeStr' : ''} house.',
          'Need to build a wooden staircase with railing for a 2-storey house.',
          'Looking for custom wardrobe and TV unit for master bedroom.',
        ];
      case 'Tiling':
        return [
          'Need tiling work for 3 bathrooms and a kitchen using imported tiles.',
          'Looking for floor tiling of an${sizeStr != null ? ' $sizeStr' : ' entire'} house including all rooms and lounge.',
          'Require outdoor porch and driveway tiling with anti-slip tiles.',
          'Need to remove old tiles and install new porcelain tiles in bathrooms.',
          'Looking for feature wall tiling in drawing room with marble finish.',
        ];
      case 'Waterproofing':
        return [
          'Need waterproofing treatment for the roof to fix leakage issues.',
          'Looking for bathroom waterproofing before tiling work starts.',
          'Require basement waterproofing with injection grouting method.',
          'Need waterproofing of underground water tank and swimming pool.',
          'Looking for complete exterior waterproofing of a${sizeStr != null ? ' $sizeStr' : ' 3-storey'} building.',
        ];
      case 'Other':
      default:
        return [
          'Need general maintenance work including minor repairs and touch-ups.',
          'Looking for a skilled handyman for various small repair jobs at home.',
          'Require landscaping and garden design work for a residential property.',
          'Need demolition of an old structure before new construction begins.',
          'Looking for glass work and aluminium partition installation in office.',
        ];
    }
  }

  static const List<String> _projectTypes = [
    'New Construction',
    'Renovation',
    'Plumbing',
    'Electrical',
    'Painting',
    'Carpentry',
    'Tiling',
    'Waterproofing',
    'Other',
  ];

  // ── per-type budget / duration / start-date defaults ────
  // durationDays: typical time this kind of job takes.
  // startOffsetDays: how many days from TODAY the job would realistically start.
  static const Map<String, Map<String, int>> _typeDefaults = {
    'New Construction': {
      'budgetMin': 500000,
      'budgetMax': 2000000,
      'durationDays': 90,
      'startOffsetDays': 7,
    },
    'Renovation': {
      'budgetMin': 150000,
      'budgetMax': 600000,
      'durationDays': 30,
      'startOffsetDays': 3,
    },
    'Plumbing': {
      'budgetMin': 5000,
      'budgetMax': 30000,
      'durationDays': 2,
      'startOffsetDays': 1,
    },
    'Electrical': {
      'budgetMin': 10000,
      'budgetMax': 80000,
      'durationDays': 5,
      'startOffsetDays': 1,
    },
    'Painting': {
      'budgetMin': 20000,
      'budgetMax': 100000,
      'durationDays': 7,
      'startOffsetDays': 2,
    },
    'Carpentry': {
      'budgetMin': 30000,
      'budgetMax': 200000,
      'durationDays': 14,
      'startOffsetDays': 3,
    },
    'Tiling': {
      'budgetMin': 40000,
      'budgetMax': 150000,
      'durationDays': 10,
      'startOffsetDays': 2,
    },
    'Waterproofing': {
      'budgetMin': 15000,
      'budgetMax': 70000,
      'durationDays': 4,
      'startOffsetDays': 1,
    },
    'Other': {
      'budgetMin': 10000,
      'budgetMax': 50000,
      'durationDays': 5,
      'startOffsetDays': 1,
    },
  };

  static const List<String> _serviceOptions = [
    'Labour only',
    'Labour + Material',
    'Consultation',
    'Design',
    'Supervision',
    'Full turnkey',
  ];

  static const Map<String, List<String>> _cityAreas = {
    'Karachi': [
      'Clifton / DHA',
      'Gulshan-e-Iqbal',
      'Nazimabad / North Nazimabad',
      'Johar / Malir',
      'Saddar / Lyari',
      'FB Area / Liaquatabad',
      'Bahria Town / DHA City',
      'Korangi / Landhi',
      'Orangi Town / SITE',
    ],
    'Lahore': [
      'Gulberg',
      'DHA Lahore',
      'Model Town',
      'Johar Town',
      'Bahria Town Lahore',
      'Cantt',
      'Iqbal Town',
      'Township',
    ],
    'Islamabad': [
      'F-6 / F-7',
      'F-8 / F-10',
      'G-9 / G-10',
      'G-11 / G-12',
      'I-8 / I-9',
      'Bahria Town Islamabad',
    ],
    'Rawalpindi': [
      'Saddar',
      'Chaklala',
      'Bahria Town Rawalpindi',
      'Satellite Town',
      'Gulraiz',
      'Westridge',
    ],
    'Peshawar': [
      'University Town',
      'Hayatabad',
      'Saddar / Cantonment',
      'Gulbahar',
      'Tehkal',
    ],
    'Multan': [
      'Cantt',
      'Shah Rukn-e-Alam',
      'Gulgasht Colony',
      'Wapda Town',
      'New Multan',
    ],
    'Faisalabad': [
      'Peoples Colony',
      'Gulberg Faisalabad',
      'D Ground',
      'Samanabad',
      'Canal Road',
    ],
  };

  static const List<String> _monthNames = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  // ── DESIGN SYSTEM colors (Navy/Amber) ─────────────────────────
  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _amberLight = Color(0xFFFBF6E3);
  static const _white = Color(0xFFFFFFFF);
  static const _label = Color(0xFF0E3B2E);
  static const _sub = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _fill = Color(0xFFF7F5EF);
  static const _bg = Color(0xFFF7F5EF);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFDC2626);

  @override
  void initState() {
    super.initState();
    _checkClientPlan();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _budgetMinCtrl.dispose();
    _budgetMaxCtrl.dispose();
    _durationCtrl.dispose();
    _startDateCtrl.dispose();
    _plotSizeCtrl.dispose();
    super.dispose();
  }

  // ── Plan gate check ──────────────────────────────────────────
  Future<void> _checkClientPlan() async {
    setState(() => _checkingPlan = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      if (uid.isEmpty) {
        setState(() {
          _canPost = false;
          _blockReason = 'You must be logged in.';
          _checkingPlan = false;
        });
        return;
      }

      // Check clients collection first, fallback to users
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
          _canPost = false;
          _blockReason = 'Profile not found. Please complete your profile.';
          _checkingPlan = false;
        });
        return;
      }

      final data = doc.data() as Map<String, dynamic>;

      // ── Gate 1: Profile completeness ─────────────────────
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
          _canPost = false;
          _blockReason =
              'Please complete your profile before posting a project.\n\n'
              'Required: Full Name, Phone, Profile Photo, and both NIC images.';
          _checkingPlan = false;
        });
        return;
      }

      // ── Gate 2: NIC must be approved by admin ─────────────
      final nicApproved = data['nic_approved'] as bool? ?? false;
      if (!nicApproved) {
        final nicUploaded = nicFront.isNotEmpty && nicBack.isNotEmpty;
        setState(() {
          _canPost = false;
          _blockReason = nicUploaded
              ? 'Your NIC is under review by our team.\n\n'
                    'You will be able to post projects once your identity is verified. '
                    'This usually takes 2–24 hours.'
              : 'Your identity has not been verified.\n\n'
                    'Please upload both sides of your CNIC from your profile page '
                    'and wait for admin approval before posting a project.';
          _checkingPlan = false;
        });
        return;
      }

      // ── Gate 3: Plan check ────────────────────────────────
      final planName = data['planName'] as String? ?? 'Free';
      final projectsRemaining = data['projectsRemaining'] as int? ?? 0;

      if (planName == 'Free') {
        final existing = await FirebaseFirestore.instance
            .collection('projects')
            .where('clientId', isEqualTo: uid)
            .get();
        if (existing.docs.isNotEmpty) {
          setState(() {
            _canPost = false;
            _blockReason =
                'Your Free plan allows only 1 project post.\n\n'
                'Upgrade to Standard (5 projects/month) or '
                'Premium (unlimited) to post more.';
            _checkingPlan = false;
          });
          return;
        }
      } else if (planName != 'Premium' && projectsRemaining <= 0) {
        setState(() {
          _canPost = false;
          _blockReason =
              'You have used all your project posts for this month '
              'on your $planName plan.\n\n'
              'Upgrade to Premium for unlimited posts.';
          _checkingPlan = false;
        });
        return;
      }

      setState(() {
        _canPost = true;
        _checkingPlan = false;
      });
    } catch (e) {
      setState(() {
        _canPost = false;
        _blockReason = 'Error checking your profile: $e';
        _checkingPlan = false;
      });
    }
  }

  // ── Budget formatter ─────────────────────────────────────────
  String _formatBudgetLabel(String raw) {
    final num = int.tryParse(raw.replaceAll(',', '').trim());
    if (num == null || num == 0) return '';
    if (num >= 10000000) return '${(num / 10000000).toStringAsFixed(1)} Crore';
    if (num >= 100000) return '${(num / 100000).toStringAsFixed(1)} Lakh';
    if (num >= 1000) return '${(num / 1000).toStringAsFixed(1)} Hazar';
    return 'Rs $num';
  }

  // ── apply type-based budget/duration/start-date defaults ─
  void _applyTypeDefaults(String type) {
    final d = _typeDefaults[type];
    if (d == null) return;
    _budgetMinCtrl.text = '${d['budgetMin']}';
    _budgetMaxCtrl.text = '${d['budgetMax']}';
    _durationCtrl.text = _formatDuration(d['durationDays']!);
    final start = DateTime.now().add(Duration(days: d['startOffsetDays']!));
    _selectedStartDate = start;
    _startDateCtrl.text = _formatDate(start);
  }

  // ── AI: generate description suggestions ─────────────────
  Future<void> _generateAiSuggestions() async {
    if (_aiDescLoading) return;
    setState(() => _aiDescLoading = true);
    try {
      final suggestions = await GeminiService.generateDescriptionSuggestions(
        projectType: _projectType ?? 'Other',
        city: _selectedCity,
        plotSize: _plotSizeCtrl.text.trim(),
        plotSizeUnit: _plotSizeUnit,
        services: _selectedServices,
      );
      if (!mounted) return;
      setState(() => _aiSuggestions = suggestions);
    } catch (e) {
      if (!mounted) return;
      setState(() => _aiSuggestions = []);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI failed: $e')));
    } finally {
      if (mounted) setState(() => _aiDescLoading = false);
    }
  }

  // ── AI: estimate project cost ─────────────────────────────
  Future<void> _getAiEstimate() async {
    if (_aiEstimateLoading) return;
    setState(() => _aiEstimateLoading = true);
    try {
      final estimate = await GeminiService.estimateProjectCost(
        projectType: _projectType ?? 'Other',
        city: _selectedCity ?? 'Pakistan',
        plotSize: _plotSizeCtrl.text.trim(),
        plotSizeUnit: _plotSizeUnit,
        description: _descCtrl.text.trim(),
        services: _selectedServices,
      );
      if (!mounted) return;
      setState(() => _aiEstimate = estimate);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI failed: $e')));
    } finally {
      if (mounted) setState(() => _aiEstimateLoading = false);
    }
  }

  String _formatDuration(int days) {
    if (days >= 30) {
      final months = (days / 30).round();
      return months == 1 ? '1 month' : '$months months';
    }
    if (days >= 7) {
      final weeks = (days / 7).round();
      return weeks == 1 ? '1 week' : '$weeks weeks';
    }
    return days == 1 ? '1 day' : '$days days';
  }

  String _formatDate(DateTime d) =>
      '${d.day} ${_monthNames[d.month - 1]} ${d.year}';

  // ── start date picker — never allows a date before today ──
  Future<void> _pickStartDate() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final initial =
        (_selectedStartDate != null && !_selectedStartDate!.isBefore(today))
        ? _selectedStartDate!
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today, // ✅ start date can only be today or later
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _amber,
            onPrimary: _navy,
            onSurface: _navy,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedStartDate = picked;
        _startDateCtrl.text = _formatDate(picked);
      });
    }
  }

  // ── open the plot-location map picker ────────────────────
  Future<void> _openMapPicker() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _PlotMapPickerScreen(initialLat: _plotLat, initialLng: _plotLng),
      ),
    );
    if (result != null) {
      final detectedCity = (result['city'] as String? ?? '').trim();
      final detectedArea = (result['area'] as String? ?? '').trim();
      final matchedCity = _matchCity(detectedCity);
      final matchedArea = matchedCity != null
          ? _matchArea(matchedCity, detectedArea)
          : null;

      setState(() {
        _plotLat = result['lat'] as double;
        _plotLng = result['lng'] as double;
        _plotAddress = result['address'] as String? ?? '';

        if (matchedCity != null && matchedArea != null) {
          // Confident city + known-area match — show the auto-detected card.
          _selectedCity = matchedCity;
          _selectedArea = matchedArea;
          _cityAreaAutoDetected = true;
          _showManualCityArea = false;
        } else if (matchedCity != null && detectedArea.isNotEmpty) {
          // City matched and the map returned an area name, but it doesn't
          // exactly match any entry in our list. Use the raw geocoded area
          // so the user doesn't have to open the dropdown — they can still
          // edit it if they want a different known area.
          _selectedCity = matchedCity;
          _selectedArea = detectedArea;
          _cityAreaAutoDetected = true;
          _showManualCityArea = false;
        } else if (matchedCity != null) {
          // City matched but geocoding returned no area at all.
          // Pre-fill the city dropdown and let the user pick an area manually.
          _selectedCity = matchedCity;
          _selectedArea = null;
          _cityAreaAutoDetected = false;
          _showManualCityArea = true;
        } else if (detectedCity.isNotEmpty) {
          // We got a city name from the map but it doesn't match our
          // hardcoded list. Pre-fill the dropdowns so the user can
          // easily correct them instead of starting from scratch.
          _selectedCity = null;
          _selectedArea = null;
          _cityAreaAutoDetected = false;
          _showManualCityArea = true;
        } else {
          // Geocoding returned nothing — fall back to manual selection.
          _cityAreaAutoDetected = false;
          _showManualCityArea = true;
        }
      });
    }
  }

  // ── best-effort match of a geocoded locality to a known city ────
  String? _matchCity(String detectedCity) {
    if (detectedCity.isEmpty) return null;
    final needle = _normalizeForMatch(detectedCity);

    // 1) Exact / substring match.
    for (final city in _cityAreas.keys) {
      final hay = _normalizeForMatch(city);
      if (hay == needle || hay.contains(needle) || needle.contains(hay)) {
        return city;
      }
    }

    // 2) Token match (e.g. "karachi central" → "karachi").
    final needleTokens = _tokenize(needle);
    for (final city in _cityAreas.keys) {
      final hayTokens = _tokenize(_normalizeForMatch(city));
      for (final t in needleTokens) {
        if (t.length < 3) continue; // ignore tiny tokens
        if (hayTokens.contains(t)) return city;
      }
    }
    return null;
  }

  // ── best-effort match of a geocoded sub-locality to a known area ─
  String? _matchArea(String city, String detectedArea) {
    final areas = _cityAreas[city] ?? [];
    if (areas.isEmpty) return null;
    if (detectedArea.isEmpty) return null;

    final needle = _normalizeForMatch(detectedArea);
    final needleTokens = _significantTokens(needle);

    // 1) Full substring match.
    for (final area in areas) {
      final hay = _normalizeForMatch(area);
      if (hay.contains(needle) || needle.contains(hay)) return area;
    }

    // 2) Shared significant token match (handles "Gulshan-e-Iqbal" vs
    //    "Gulshan e Iqbal", "Clifton" vs "Clifton / DHA", etc.).
    for (final area in areas) {
      final hayTokens = _significantTokens(_normalizeForMatch(area));
      for (final t in needleTokens) {
        if (hayTokens.contains(t)) return area;
      }
    }

    // 3) Any significant token of the known area appears in the detected string.
    //    E.g. detected "DHA Karachi" matches known "Clifton / DHA".
    for (final area in areas) {
      final hayTokens = _significantTokens(_normalizeForMatch(area));
      for (final t in hayTokens) {
        if (needle.contains(t)) return area;
      }
    }

    // No confident match against the known list.
    return null;
  }

  /// Normalizes a string for fuzzy matching.
  String _normalizeForMatch(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s\-]'), '')
        .trim();
  }

  /// Splits a normalized string into tokens.
  List<String> _tokenize(String s) => s.split(RegExp(r'[\s\-]+'));

  /// Returns meaningful tokens, filtering out generic words and short noise.
  List<String> _significantTokens(String s) {
    final generic = <String>{
      'block', 'sector', 'phase', 'town', 'colony', 'garden', 'society',
      'road', 'street', 'avenue', 'lane', 'bungalows', 'cooperative',
      'housing', 'scheme', 'project', 'nagar', 'abad', 'market', 'chowk',
    };
    return _tokenize(s)
        .where((t) => t.length >= 3 && !generic.contains(t))
        .toList();
  }

  List<String> get _areasForCity {
    final known = _cityAreas[_selectedCity] ?? [];
    if (_selectedArea == null || _selectedArea!.isEmpty) return known;
    final alreadyListed = known.any(
      (a) => a.toLowerCase() == _selectedArea!.toLowerCase(),
    );
    if (alreadyListed) return known;
    // The current selection came from the map but isn't in our hardcoded
    // list. Include it as the first dropdown item so the UI stays valid.
    return [_selectedArea!, ...known];
  }

  bool get _needsPlotSize =>
      _projectType != null && _typesNeedingSize.contains(_projectType);

  // ── Photo picking ────────────────────────────────────────
  Future<void> _pickImages() async {
    final remaining = _maxPhotos - _pickedImages.length;
    if (remaining <= 0) {
      _snack('You can add up to $_maxPhotos photos for this project type.', _amber);
      return;
    }
    try {
      final picked = await _imagePicker.pickMultiImage(imageQuality: 80);
      if (picked.isEmpty) return;
      final toAdd = picked.take(remaining).map((x) => File(x.path)).toList();
      setState(() => _pickedImages.addAll(toAdd));
      if (picked.length > remaining) {
        _snack(
          'Only added $remaining more — max $_maxPhotos photos allowed.',
          _amber,
        );
      }
    } catch (e) {
      _snack('Could not open gallery: $e', _red);
    }
  }

  Future<void> _pickSinglePhotoFromCamera() async {
    final remaining = _maxPhotos - _pickedImages.length;
    if (remaining <= 0) {
      _snack('You can add up to $_maxPhotos photos for this project type.', _amber);
      return;
    }
    try {
      final shot = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );
      if (shot == null) return;
      setState(() => _pickedImages.add(File(shot.path)));
    } catch (e) {
      _snack('Could not open camera: $e', _red);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _pickedImages.removeAt(index);
      if (_pickedImages.isEmpty) {
        _coverImageIndex = 0;
      } else if (_coverImageIndex >= _pickedImages.length) {
        _coverImageIndex = _pickedImages.length - 1;
      } else if (_coverImageIndex > index) {
        _coverImageIndex -= 1;
      }
    });
  }

  void _setCoverImage(int index) => setState(() => _coverImageIndex = index);

  // ── Upload all picked photos to Cloudinary, cover photo first ──
  // Returns the uploaded URLs in the SAME order as _pickedImages so the
  // cover index lines up; throws if any single upload fails so the whole
  // post can be aborted rather than silently posting with missing photos.
  Future<List<String>> _uploadProjectImages() async {
    final urls = <String>[];
    for (final file in _pickedImages) {
      final url = await CloudinaryService(cloudName: 'doblp5gf6', uploadPreset: 'Thekaydaar').uploadImage(file);
      if (url.isEmpty) {
        throw Exception('One of the photos failed to upload. Please retry.');
      }
      urls.add(url);
    }
    return urls;
  }

  Future<void> _submitProject() async {
    if (!_formKey.currentState!.validate()) return;
    if (_projectType == null) {
      _snack('Please select a project type', _red);
      return;
    }
    if (_selectedCity == null) {
      _snack('Please select a city', _red);
      return;
    }
    if (_selectedArea == null) {
      _snack('Please select an area', _red);
      return;
    }
    if (_plotLat == null || _plotLng == null) {
      _snack('Please pin your plot location on the map', _red);
      return;
    }
    if (_plotAddress.trim().isEmpty) {
      _snack(
        'Address not detected from the map. Please change the pin and try again.',
        _red,
      );
      return;
    }
    if (_needsPlotSize && _plotSizeCtrl.text.trim().isEmpty) {
      _snack('Please enter the plot/property size', _red);
      return;
    }
    if (_pickedImages.length < _minPhotos) {
      _snack(
        'Please add at least $_minPhotos photos ($_maxPhotos max) for this project type.',
        _red,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      setState(() => _uploadingImages = true);
      final imageUrls = await _uploadProjectImages();
      setState(() => _uploadingImages = false);
      final coverUrl = imageUrls[_coverImageIndex];

      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final db = FirebaseFirestore.instance;
      final userDoc = await db.collection('users').doc(uid).get();
      final clientName = (userDoc.data()?['fullName'] as String? ?? '').trim();

      await db.collection('projects').add({
        'clientId': uid,
        'clientName': clientName,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'projectType': _projectType,
        'city': _selectedCity,
        'area': _selectedArea,
        'plotSize': _plotSizeCtrl.text.trim().isNotEmpty
            ? _plotSizeCtrl.text.trim()
            : null,
        'plotSizeUnit': _plotSizeCtrl.text.trim().isNotEmpty
            ? _plotSizeUnit
            : null,
        'budgetMin': _budgetMinCtrl.text.trim(),
        'budgetMax': _budgetMaxCtrl.text.trim(),
        'duration': _durationCtrl.text.trim(),
        'startDate': _startDateCtrl.text.trim(),
        'startDateTimestamp': _selectedStartDate != null
            ? Timestamp.fromDate(_selectedStartDate!)
            : null,
        'plotLocation': GeoPoint(_plotLat!, _plotLng!),
        'plotAddress': _plotAddress,
        'urgentRequired': _isUrgent,
        'services': _selectedServices,
        // ── Photos ── 'images' keeps every uploaded photo; 'coverImage'
        // is the one the client marked as the main/main photo, used by
        // project cards and the browse feed as the thumbnail.
        'images': imageUrls,
        'coverImage': coverUrl,
        'status': 'open',
        'bids': [],
        // 'createdAt' is a server-generated timestamp — always use this
        // (not a locally-generated DateTime.now()) for any "posted X ago"
        // display, since client clocks can be wrong/out of sync.
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Decrement projectsRemaining for non-Premium plans
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
      _snack('Project posted successfully!', _green);
      Navigator.pop(context);
    } catch (e) {
      _snack('Error: $e', _red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(color: _white, fontSize: 13),
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    if (_checkingPlan) {
      return Scaffold(
        backgroundColor: _bg,
        appBar: _appBar(),
        body: const Center(child: CircularProgressIndicator(color: _amber)),
      );
    }

    if (!_canPost) return _buildBlockedScreen();

    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _sectionCard(
              step: 1,
              title: 'Project Details',
              icon: Icons.description_outlined,
              children: [
                _fieldLabel('Project Title *'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _titleCtrl,
                  hint: 'e.g. Renovate my kitchen in DHA',
                  icon: Icons.title_rounded,
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),

                _fieldLabel('Project Type *'),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: _projectType,
                  onChanged: (v) => setState(() {
                    _projectType = v;
                    _descCtrl.clear();
                    if (v != null) _applyTypeDefaults(v);
                    // ── trim photos if the new type's max is smaller
                    // than what's already picked (e.g. switching from
                    // Renovation [max 8] down to Plumbing [max 5]) ──
                    if (_pickedImages.length > _maxPhotos) {
                      _pickedImages.removeRange(
                        _maxPhotos,
                        _pickedImages.length,
                      );
                      if (_coverImageIndex >= _pickedImages.length) {
                        _coverImageIndex = _pickedImages.isEmpty
                            ? 0
                            : _pickedImages.length - 1;
                      }
                    }
                  }),
                  validator: (v) => v == null ? 'Select a project type' : null,
                  style: const TextStyle(color: _label, fontSize: 14),
                  decoration: _inputDeco(
                    'Select type',
                    Icons.category_outlined,
                  ),
                  items: _projectTypes
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                ),
                if (_projectType != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 13,
                        color: _amber,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Budget, duration & start date suggested below — feel free to edit.',
                          style: const TextStyle(fontSize: 11, color: _sub),
                        ),
                      ),
                    ],
                  ),
                ],
                if (_needsPlotSize) ...[
                  const SizedBox(height: 16),
                  _fieldLabel('Plot / Property Size *'),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          controller: _plotSizeCtrl,
                          hint: 'e.g. 120',
                          icon: Icons.straighten_rounded,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (v) => _needsPlotSize &&
                                  (v ?? '').trim().isEmpty
                              ? 'Required'
                              : null,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 3,
                        child: DropdownButtonFormField<String>(
                          initialValue: _plotSizeUnit,
                          isExpanded: true,
                          onChanged: (v) =>
                              setState(() => _plotSizeUnit = v ?? 'Marla'),
                          style: const TextStyle(color: _label, fontSize: 14),
                          decoration: _inputDeco('Unit', Icons.straighten_rounded)
                              .copyWith(
                                prefixIcon: null,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 14,
                                ),
                              ),
                          items: _plotSizeUnits
                              .map(
                                (u) => DropdownMenuItem(
                                  value: u,
                                  child: Text(
                                    u,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'e.g. 120 Sq. Yards, 5 Marla, 1 Kanal — helps contractors estimate material and labour.',
                    style: TextStyle(fontSize: 11.5, color: _sub),
                  ),
                ],
                const SizedBox(height: 16),

                _fieldLabel('Description *'),
                const SizedBox(height: 8),
                if (_projectType != null) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ..._descSuggestionsFor(_projectType!).map(
                        (s) => _suggestionChip(s),
                      ),
                      ..._aiSuggestions.map((s) => _suggestionChip(s)),
                      GestureDetector(
                        onTap: _aiDescLoading ? null : _generateAiSuggestions,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _amberLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _amber.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_aiDescLoading)
                                const SizedBox(
                                  width: 11,
                                  height: 11,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 12,
                                  color: _amber,
                                ),
                              const SizedBox(width: 5),
                              Text(
                                _aiDescLoading ? 'AI writing…' : '✨ AI Ideas',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: _amber,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _descCtrl.clear()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _fill,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _border),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.edit_rounded, size: 11, color: _sub),
                              SizedBox(width: 5),
                              Text(
                                'Custom…',
                                style: TextStyle(fontSize: 11.5, color: _sub),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: _label, fontSize: 14),
                  decoration: _inputDeco(
                    'Describe the work in detail or tap a suggestion above…',
                    Icons.notes_rounded,
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Description is required'
                      : null,
                ),
              ],
            ),

            _sectionCard(
              step: 2,
              title: 'Location',
              icon: Icons.location_on_outlined,
              children: [
                _fieldLabel('Exact Plot Location *'),
                const SizedBox(height: 8),
                if (_plotLat == null)
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _openMapPicker,
                      icon: const Icon(Icons.map_rounded, size: 18),
                      label: const Text(
                        'Pin Your Plot on Map',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: _amber, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _fill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: _amber,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _plotAddress.isNotEmpty
                                    ? _plotAddress
                                    : 'Pinned Location',
                                style: const TextStyle(
                                  color: _label,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_plotLat!.toStringAsFixed(5)}, ${_plotLng!.toStringAsFixed(5)}',
                                style: const TextStyle(
                                  color: _sub,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: _openMapPicker,
                          child: const Text(
                            'Change',
                            style: TextStyle(
                              color: Color(0xFFA8861D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 6),
                const Text(
                  'Pin the exact plot so nearby contractors can find it easily — just like sharing a live location.',
                  style: TextStyle(fontSize: 11.5, color: _sub),
                ),

                // ── City/Area — auto-detected from the pinned plot
                // location once available, otherwise falls back to manual
                // dropdowns so the form still works if geocoding fails.
                if (_cityAreaAutoDetected && !_showManualCityArea) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _amberLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFFA8861D),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$_selectedCity · ${_selectedArea ?? ''}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _label,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Detected automatically from your pinned location',
                                style: TextStyle(fontSize: 11, color: _sub),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _showManualCityArea = true),
                          child: const Text(
                            'Edit',
                            style: TextStyle(
                              color: Color(0xFFA8861D),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (_plotLat == null || _showManualCityArea) ...[
                  const SizedBox(height: 16),
                  _fieldLabel('City *'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCity,
                    onChanged: (v) => setState(() {
                      _selectedCity = v;
                      _selectedArea = null;
                    }),
                    validator: (v) => v == null ? 'Select a city' : null,
                    style: const TextStyle(color: _label, fontSize: 14),
                    decoration: _inputDeco(
                      'Select city',
                      Icons.location_city_outlined,
                    ),
                    items: _cityAreas.keys
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                  ),
                  if (_selectedCity != null) ...[
                    const SizedBox(height: 16),
                    _fieldLabel('Area *'),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedArea,
                      onChanged: (v) => setState(() => _selectedArea = v),
                      validator: (v) => v == null ? 'Select an area' : null,
                      style: const TextStyle(color: _label, fontSize: 14),
                      decoration: _inputDeco('Select area', Icons.map_outlined),
                      items: _areasForCity
                          .map(
                            (a) => DropdownMenuItem(value: a, child: Text(a)),
                          )
                          .toList(),
                    ),
                  ],
                  if (_cityAreaAutoDetected) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _showManualCityArea = false),
                      child: const Text(
                        'Use auto-detected location instead',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFA8861D),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),

            _sectionCard(
              step: 3,
              title: 'Budget & Timeline',
              icon: Icons.payments_outlined,
              children: [
                // Budget mini-card — highlighted amber tint so pricing
                // stands out visually from the rest of the form.
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _amberLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Min Budget (Rs) *'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _budgetMinCtrl,
                              hint: 'e.g. 50000',
                              icon: Icons.money_outlined,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) =>
                                  (v ?? '').trim().isEmpty ? 'Required' : null,
                              onChanged: (_) => setState(() {}),
                              fillColor: _white,
                            ),
                            if (_budgetMinCtrl.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 5, left: 4),
                                child: Text(
                                  _formatBudgetLabel(_budgetMinCtrl.text),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFA8861D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 1, height: 60, color: _border),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Max Budget (Rs) *'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _budgetMaxCtrl,
                              hint: 'e.g. 100000',
                              icon: Icons.money_rounded,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (v) =>
                                  (v ?? '').trim().isEmpty ? 'Required' : null,
                              onChanged: (_) => setState(() {}),
                              fillColor: _white,
                            ),
                            if (_budgetMaxCtrl.text.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 5, left: 4),
                                child: Text(
                                  _formatBudgetLabel(_budgetMaxCtrl.text),
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFA8861D),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // ── AI Cost Estimator ─────────────────────────
                if (_aiEstimate == null)
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: OutlinedButton.icon(
                      onPressed: _aiEstimateLoading ? null : _getAiEstimate,
                      icon: _aiEstimateLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        _aiEstimateLoading
                            ? 'AI estimating…'
                            : '✨ Get AI Cost Estimate',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _navy,
                        side: const BorderSide(color: _amber, width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _amberLight,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome_rounded,
                              size: 16,
                              color: _amber,
                            ),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                '✨ AI Cost Estimate',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: _label,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _aiEstimate = null),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: _sub,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Rs ${_formatBudgetLabel('${_aiEstimate!.budgetMin}')} — Rs ${_formatBudgetLabel('${_aiEstimate!.budgetMax}')}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _label,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '≈ ${_aiEstimate!.durationDays} days',
                          style: const TextStyle(fontSize: 12, color: _sub),
                        ),
                        if (_aiEstimate!.materials.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ..._aiEstimate!.materials.map(
                            (m) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      m.item,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _label,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    'Rs ${_formatBudgetLabel('${m.cost}')}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _label,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_aiEstimate!.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            _aiEstimate!.notes,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontStyle: FontStyle.italic,
                              color: _sub,
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 40,
                          child: ElevatedButton.icon(
                            onPressed: () => setState(() {
                              _budgetMinCtrl.text = '${_aiEstimate!.budgetMin}';
                              _budgetMaxCtrl.text = '${_aiEstimate!.budgetMax}';
                            }),
                            icon: const Icon(Icons.check_rounded, size: 16),
                            label: const Text(
                              'Apply to My Budget',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _amber,
                              foregroundColor: _navy,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),

                _fieldLabel('Expected Duration'),
                const SizedBox(height: 6),
                _buildTextField(
                  controller: _durationCtrl,
                  hint: 'e.g. 2 weeks, 1 month',
                  icon: Icons.schedule_outlined,
                ),
                const SizedBox(height: 16),

                _fieldLabel('Preferred Start Date *'),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickStartDate,
                  child: AbsorbPointer(
                    child: _buildTextField(
                      controller: _startDateCtrl,
                      hint: 'Tap to select date',
                      icon: Icons.calendar_today_outlined,
                      validator: (v) => (v ?? '').trim().isEmpty
                          ? 'Select a start date'
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => setState(() {
                    final today = DateTime.now();
                    _selectedStartDate = today;
                    _startDateCtrl.text = 'ASAP (${_formatDate(today)})';
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: _fill,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _border),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 13, color: _amber),
                        SizedBox(width: 5),
                        Text(
                          'ASAP — Start Today',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _sub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            _sectionCard(
              step: 4,
              title: 'Services & Extras',
              icon: Icons.build_outlined,
              children: [
                _fieldLabel('Services Needed'),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _serviceOptions.map((s) {
                    final selected = _selectedServices.contains(s);
                    return GestureDetector(
                      onTap: () => setState(() {
                        if (selected) {
                          _selectedServices.remove(s);
                        } else {
                          _selectedServices.add(s);
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? _amber.withValues(alpha: 0.12)
                              : _fill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: selected ? _amber : _border,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (selected)
                              const Padding(
                                padding: EdgeInsets.only(right: 5),
                                child: Icon(
                                  Icons.check_circle_rounded,
                                  size: 13,
                                  color: _amber,
                                ),
                              ),
                            Text(
                              s,
                              style: TextStyle(
                                color: selected ? _navy : _sub,
                                fontSize: 12.5,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),

                // Urgent toggle — refined with rounded icon chip
                GestureDetector(
                  onTap: () => setState(() => _isUrgent = !_isUrgent),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _isUrgent ? _amberLight : _fill,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _isUrgent
                            ? _amber.withValues(alpha: 0.5)
                            : _border,
                        width: _isUrgent ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: _isUrgent ? _amber : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.flash_on_rounded,
                            color: _isUrgent ? _navy : _sub,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Mark as Urgent',
                                style: TextStyle(
                                  color: _isUrgent ? _navy : _label,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Gets highlighted and shown first to contractors',
                                style: TextStyle(color: _sub, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isUrgent,
                          onChanged: (v) => setState(() => _isUrgent = v),
                          activeThumbColor: _amber,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Step 5: Project Photos ──────────────────────────
            // Min/max required depends on the selected project type
            // (see `_typePhotoRange`). Tap the star on any photo to make
            // it the "Main Photo" — that's the one shown on the project
            // card in the client/contractor browse feed.
            _sectionCard(
              step: 5,
              title: 'Project Photos',
              icon: Icons.photo_library_outlined,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        _projectType == null
                            ? 'Select a project type above to see how many photos are required.'
                            : 'Add $_minPhotos–$_maxPhotos clear photos of the plot/site. Tap the star on a photo to set it as the Main Photo — shown on your project card.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _sub,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: _pickedImages.length >= _minPhotos
                            ? _green.withValues(alpha: 0.12)
                            : _fill,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _pickedImages.length >= _minPhotos
                              ? _green
                              : _border,
                        ),
                      ),
                      child: Text(
                        '${_pickedImages.length}/$_maxPhotos',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: _pickedImages.length >= _minPhotos
                              ? _green
                              : _sub,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_uploadingImages) ...[
                  const ClipRRect(
                    borderRadius: BorderRadius.all(Radius.circular(6)),
                    child: LinearProgressIndicator(
                      color: _amber,
                      backgroundColor: _fill,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Uploading photos…',
                    style: TextStyle(fontSize: 11, color: _sub),
                  ),
                  const SizedBox(height: 14),
                ],

                if (_pickedImages.isNotEmpty)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _pickedImages.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 0.78,
                        ),
                    itemBuilder: (context, index) {
                      final isCover = index == _coverImageIndex;
                      return Stack(
                        children: [
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isCover ? _amber : _border,
                                  width: isCover ? 2.5 : 1,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  _pickedImages[index],
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                            ),
                          ),
                          // remove (x) button
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.55),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: _white,
                                  size: 14,
                                ),
                              ),
                            ),
                          ),
                          // ── "Set as Main" / "Main Photo" button ──
                          Positioned(
                            bottom: 4,
                            left: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _setCoverImage(index),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isCover
                                      ? _amber
                                      : Colors.black.withValues(alpha: 0.55),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isCover
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      color: isCover ? _navy : _white,
                                      size: 12,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        isCover ? 'Main Photo' : 'Set as Main',
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: isCover ? _navy : _white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                if (_pickedImages.isNotEmpty) const SizedBox(height: 14),

                if (_pickedImages.length < _maxPhotos)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickImages,
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 17,
                          ),
                          label: const Text('Gallery'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _navy,
                            side: const BorderSide(color: _border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickSinglePhotoFromCamera,
                          icon: const Icon(
                            Icons.camera_alt_outlined,
                            size: 17,
                          ),
                          label: const Text('Camera'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _navy,
                            side: const BorderSide(color: _border),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Center(
                    child: Text(
                      'Max photos reached ($_maxPhotos). Remove one to add another.',
                      style: const TextStyle(fontSize: 11.5, color: _sub),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // ── Submit button ────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _submitProject,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: _navy,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(
                  _isLoading ? 'Posting…' : 'Post Project',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _amber,
                  foregroundColor: _navy,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Contractors near you will be notified once posted.',
                style: TextStyle(fontSize: 11.5, color: _sub),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Shared app bar ─────────────────────────────────────────
  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: _navy,
    elevation: 0,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_rounded, color: _white),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'Post a Project',
      style: TextStyle(
        color: _white,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    centerTitle: true,
  );

  // ── Blocked screen (profile/NIC/plan gate) ──────────────────
  Widget _buildBlockedScreen() {
    return Scaffold(
      backgroundColor: _bg,
      appBar: _appBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: _white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _blockReason.contains('NIC') ||
                            _blockReason.contains('identity')
                        ? Icons.verified_user_outlined
                        : _blockReason.contains('profile')
                        ? Icons.person_outline_rounded
                        : Icons.lock_rounded,
                    color: _red,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  _blockReason.contains('NIC under review')
                      ? 'NIC Under Review'
                      : _blockReason.contains('identity')
                      ? 'Identity Not Verified'
                      : _blockReason.contains('complete your profile')
                      ? 'Profile Incomplete'
                      : 'Plan Limit Reached',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _label,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _blockReason,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: _sub,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (_blockReason.contains('plan') ||
                          _blockReason.contains('Plan')) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BillingScreen(role: 'client'),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClientProfileScreen(),
                          ),
                        );
                      }
                    },
                    icon: Icon(
                      _blockReason.contains('plan') ||
                              _blockReason.contains('Plan')
                          ? Icons.workspace_premium_rounded
                          : Icons.person_rounded,
                      size: 17,
                    ),
                    label: Text(
                      _blockReason.contains('plan') ||
                              _blockReason.contains('Plan')
                          ? 'Upgrade Plan'
                          : 'Go to Profile',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: _navy,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Section card wrapper — each form section now sits in its
  // own elevated card with a numbered step badge, instead of a
  // flat list. This is what gives the form visual structure and
  // hierarchy instead of feeling like one long scroll.
  Widget _sectionCard({
    required int step,
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  color: _navy,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '$step',
                    style: const TextStyle(
                      color: _amber,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: _navy, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _suggestionChip(String s) {
    final active = _descCtrl.text == s;
    return GestureDetector(
      onTap: () => setState(() => _descCtrl.text = s),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? _amber.withValues(alpha: 0.12) : _fill,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _amber : _border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 11,
              color: active ? _amber : _sub,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                s.length > 45 ? '${s.substring(0, 45)}…' : s,
                style: TextStyle(
                  fontSize: 11.5,
                  color: active ? _navy : _sub,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
    text,
    style: const TextStyle(
      color: _label,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  );

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    Color? fillColor,
  }) => TextFormField(
    controller: controller,
    maxLines: maxLines,
    keyboardType: keyboardType,
    inputFormatters: inputFormatters,
    validator: validator,
    onChanged: onChanged,
    style: const TextStyle(color: _label, fontSize: 14),
    decoration: _inputDeco(hint, icon, fillColor: fillColor),
  );

  InputDecoration _inputDeco(String hint, IconData icon, {Color? fillColor}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFA6B2AB), fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFA6B2AB), size: 18),
        filled: true,
        fillColor: fillColor ?? _fill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _amber, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _red, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 11.5),
      );
}

// ============================================================================
// Google-Maps-style plot location picker
// A full-screen map with a fixed center pin — user pans the map to move the
// pin (like sharing a live location), or taps "my location" to jump to GPS.
// Confirms and returns {lat, lng, address, city, area} back to
// PostProjectScreen so it can auto-fill the City/Area fields.
// ============================================================================
class _PlotMapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;

  const _PlotMapPickerScreen({this.initialLat, this.initialLng});

  @override
  State<_PlotMapPickerScreen> createState() => _PlotMapPickerScreenState();
}

class _PlotMapPickerScreenState extends State<_PlotMapPickerScreen> {
  GoogleMapController? _controller;
  LatLng _center = const LatLng(24.8607, 67.0011); // Karachi fallback
  bool _loadingAddress = false;
  bool _searching = false;
  String _address = '';
  String _detectedCity = '';
  String _detectedArea = '';
  bool _geocodeFailed = false;
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _white = Color(0xFFFFFFFF);

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _center = LatLng(widget.initialLat!, widget.initialLng!);
      _reverseGeocode(_center);
    } else {
      _useCurrentLocation();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Forward-geocode a typed address/place name and jump the map there ──
  Future<void> _searchLocation(String query) async {
    final q = query.trim();
    if (q.isEmpty) return;
    setState(() => _searching = true);
    FocusScope.of(context).unfocus();
    try {
      final locations = await geocoding.locationFromAddress(q);
      if (locations.isNotEmpty) {
        final loc = LatLng(locations.first.latitude, locations.first.longitude);
        setState(() => _center = loc);
        _controller?.animateCamera(CameraUpdate.newLatLngZoom(loc, 16));
        await _reverseGeocode(loc);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No matching location found. Try a different search.',
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not search that location. Check your connection and try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _useCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() => _center = loc);
      _controller?.animateCamera(CameraUpdate.newLatLng(loc));
      _reverseGeocode(loc);
    } catch (_) {
      // GPS unavailable/denied — user can still pan the map manually.
    }
  }

  // ── Move the pin to a tapped point and re-geocode it ─────────
  Future<void> _movePin(LatLng pos) async {
    setState(() => _center = pos);
    await _controller?.animateCamera(CameraUpdate.newLatLng(pos));
    await _reverseGeocode(pos);
  }

  Future<void> _reverseGeocode(LatLng pos) async {
    setState(() => _loadingAddress = true);
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // ── Pick the most useful address pieces ────────────────────────
        // Google's geocoding can be inconsistent for Pakistani addresses:
        // city is sometimes in locality, sometimes in subAdministrativeArea
        // or administrativeArea. Area is usually subLocality, but may also
        // come from locality or street when subLocality is missing.
        final cityCandidates = <String?>[
          p.locality,
          p.subAdministrativeArea,
          p.administrativeArea,
        ].where((e) => e != null && e.isNotEmpty).toList();

        final areaCandidates = <String?>[
          p.subLocality,
          p.locality,
          p.street,
        ].where((e) => e != null && e.isNotEmpty).toList();

        final detectedCity = cityCandidates.isNotEmpty ? cityCandidates.first! : '';
        // Prefer an area that is not identical to the city.
        var detectedArea = areaCandidates.isNotEmpty ? areaCandidates.first! : '';
        for (final candidate in areaCandidates) {
          if (candidate != null &&
              candidate.isNotEmpty &&
              candidate.toLowerCase() != detectedCity.toLowerCase()) {
            detectedArea = candidate;
            break;
          }
        }

        final addressParts = [
          p.street,
          p.subLocality,
          p.locality,
          p.subAdministrativeArea,
        ].where((e) => e != null && e.isNotEmpty).toList();

        if (mounted) {
          setState(() {
            _address = addressParts.join(', ');
            _detectedCity = detectedCity;
            _detectedArea = detectedArea;
            _geocodeFailed = false;
          });
        }
      } else if (mounted) {
        setState(() => _geocodeFailed = true);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _address = '';
          _geocodeFailed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _loadingAddress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        iconTheme: const IconThemeData(color: _white),
        title: const Text(
          'Pin Plot Location',
          style: TextStyle(
            color: _white,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _center, zoom: 16),
            onMapCreated: (c) => _controller = c,
            onCameraMove: (pos) => _center = pos.target,
            onCameraIdle: () => _reverseGeocode(_center),
            onTap: _movePin,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
          ),
          // Fixed center pin — moves the map underneath it, like Google Maps.
          const IgnorePointer(
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: 40),
                child: Icon(
                  Icons.location_pin,
                  size: 48,
                  color: Color(0xFFDC2626),
                ),
              ),
            ),
          ),
          // ── NEW: search bar — type an address/area and jump the map there.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(14),
                  shadowColor: Colors.black.withValues(alpha: 0.2),
                  child: TextField(
                    controller: _searchCtrl,
                    focusNode: _searchFocus,
                    textInputAction: TextInputAction.search,
                    onSubmitted: _searchLocation,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14, color: _navy),
                    decoration: InputDecoration(
                      hintText: 'Search for an area, street, or landmark…',
                      hintStyle: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFFA6B2AB),
                      ),
                      filled: true,
                      fillColor: _white,
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _navy,
                        size: 20,
                      ),
                      suffixIcon: _searching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _amber,
                                ),
                              ),
                            )
                          : (_searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 18,
                                      color: Color(0xFFA6B2AB),
                                    ),
                                    onPressed: () =>
                                        setState(() => _searchCtrl.clear()),
                                  )
                                : null),
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 150,
            child: FloatingActionButton(
              heroTag: 'myLocationBtn',
              backgroundColor: _white,
              onPressed: _useCurrentLocation,
              child: const Icon(Icons.my_location_rounded, color: _navy),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: Column(
              children: [
                if (_address.isNotEmpty || _loadingAddress || _geocodeFailed)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: _geocodeFailed
                          ? const Color(0xFFFFEBEE)
                          : _white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Text(
                      _loadingAddress
                          ? 'Locating address…'
                          : _geocodeFailed
                              ? "Couldn't automatically detect the address. You can still confirm these coordinates and edit the city/area on the next screen."
                              : _address,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: _geocodeFailed
                            ? const Color(0xFFB71C1C)
                            : _navy,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _loadingAddress
                        ? null
                        : () async {
                            // force one last geocode with the exact final pin position
                            await _reverseGeocode(_center);
                            if (!context.mounted) return;
                            Navigator.pop(context, {
                              'lat': _center.latitude,
                              'lng': _center.longitude,
                              'address': _address,
                              'city': _detectedCity,
                              'area': _detectedArea,
                            });
                          },
                    icon: _loadingAddress
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _navy,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded, size: 18),
                    label: Text(
                      _loadingAddress ? 'Locating…' : 'Confirm This Location',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _amber,
                      foregroundColor: _navy,
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
    );
  }
}
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ali_app/services/gemini_service.dart';
import 'package:ali_app/utils/app_theme.dart';
import 'package:ali_app/utils/price_formatter.dart';

/// AI-powered material estimator — calculates quantities for bricks, cement,
/// steel, sand, etc. based on plot area, stories, wall material, and finishing
/// level. Recommends top Pakistani brands and gives strength tips.
class MaterialEstimatorScreen extends StatefulWidget {
  const MaterialEstimatorScreen({super.key});

  @override
  State<MaterialEstimatorScreen> createState() =>
      _MaterialEstimatorScreenState();
}

class _MaterialEstimatorScreenState extends State<MaterialEstimatorScreen> {
  final _plotSizeCtrl = TextEditingController();

  String _plotSizeUnit = 'Marla';
  int _stories = 1;
  String _wallMaterial = 'Brick + Cement Mortar';
  String _finishingLevel = 'Standard';
  String _tileType = 'Ceramic';
  String _paintPreference = 'Standard Colors';
  String _selectedCity = 'Lahore';

  bool _isLoading = false;
  MaterialEstimate? _result;
  String? _errorMsg;

  // ── Options ──────────────────────────────────────────────────
  static const _plotUnits = ['Marla', 'Kanal', 'Sq Ft', 'Sq Yards'];

  static const _storyOptions = [
    {'label': 'Single', 'sub': 'Ground Floor', 'value': 1, 'icon': Icons.looks_one_rounded},
    {'label': 'Double', 'sub': 'Ground + 1st', 'value': 2, 'icon': Icons.looks_two_rounded},
    {'label': 'Triple', 'sub': 'Ground + 2', 'value': 3, 'icon': Icons.looks_3_rounded},
  ];

  /// Real Pakistani construction wall-material combinations.
  static const _wallMaterials = [
    {
      'label': 'Brick + Cement Mortar',
      'icon': Icons.grid_view_rounded,
      'desc': 'Most common — strong & durable',
    },
    {
      'label': 'Brick + Sand/Lime Mortar',
      'icon': Icons.terrain_rounded,
      'desc': 'Traditional — good for plastering',
    },
    {
      'label': 'Concrete Block + Cement',
      'icon': Icons.view_module_rounded,
      'desc': 'Faster construction, load-bearing',
    },
    {
      'label': 'AAC Block + Adhesive',
      'icon': Icons.layers_rounded,
      'desc': 'Lightweight, thermal insulated',
    },
    {
      'label': 'RCC Frame + Brick Infill',
      'icon': Icons.precision_manufacturing_rounded,
      'desc': 'Earthquake resistant, multi-story',
    },
  ];

  static const _finishingLevels = [
    {
      'label': 'Economy',
      'icon': Icons.savings_outlined,
      'desc': 'Basic tiles, simple paint, standard fixtures',
    },
    {
      'label': 'Standard',
      'icon': Icons.home_rounded,
      'desc': 'Good tiles, branded paint, quality fittings',
    },
    {
      'label': 'Premium',
      'icon': Icons.diamond_outlined,
      'desc': 'Imported finishes, premium paint, luxury fittings',
    },
  ];

  static const _tileTypes = [
    {'label': 'Ceramic', 'desc': 'Affordable, many designs', 'img': 'assets/images/materials/floor_tiles.png'},
    {'label': 'Porcelain', 'desc': 'Durable, water resistant', 'img': 'assets/images/materials/floor_tiles.png'},
    {'label': 'Marble', 'desc': 'Premium, natural beauty', 'img': 'assets/images/materials/floor_tiles.png'},
    {'label': 'Granite', 'desc': 'Hardest, scratch-proof', 'img': 'assets/images/materials/floor_tiles.png'},
    {'label': 'Vitrified', 'desc': 'Low porosity, glossy', 'img': 'assets/images/materials/floor_tiles.png'},
  ];

  static const _paintOptions = [
    {'label': 'Standard Colors', 'color': 0xFFE8E0D0},
    {'label': 'Warm White', 'color': 0xFFFAF5EB},
    {'label': 'Cream Ivory', 'color': 0xFFF5E6CA},
    {'label': 'Sage Green', 'color': 0xFFB4C7B0},
    {'label': 'Sky Blue', 'color': 0xFFB8D4E3},
    {'label': 'Dusty Rose', 'color': 0xFFD4A5A5},
    {'label': 'Charcoal Grey', 'color': 0xFF6B7280},
    {'label': 'Terracotta', 'color': 0xFFC87941},
  ];

  /// Maps material name keywords to asset image paths.
  static const _materialImageMap = {
    'brick': 'assets/images/materials/bricks.png',
    'block': 'assets/images/materials/bricks.png',
    'cement': 'assets/images/materials/cement.png',
    'steel': 'assets/images/materials/steel_rebar.png',
    'rebar': 'assets/images/materials/steel_rebar.png',
    'sand': 'assets/images/materials/sand_crush.png',
    'crush': 'assets/images/materials/sand_crush.png',
    'aggregate': 'assets/images/materials/sand_crush.png',
    'tile': 'assets/images/materials/floor_tiles.png',
    'paint': 'assets/images/materials/paint.png',
    'plaster': 'assets/images/materials/cement.png',
  };

  static const _cities = [
    'Lahore', 'Karachi', 'Islamabad', 'Rawalpindi',
    'Peshawar', 'Quetta', 'Multan', 'Faisalabad',
  ];

  @override
  void dispose() {
    _plotSizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _estimate() async {
    final plotSize = _plotSizeCtrl.text.trim();
    if (plotSize.isEmpty) {
      _showError('Please enter the plot area size');
      return;
    }
    if (double.tryParse(plotSize) == null) {
      _showError('Please enter a valid number for plot size');
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
      _errorMsg = null;
    });

    try {
      final estimate = await GeminiService.estimateMaterials(
        plotSize: plotSize,
        plotSizeUnit: _plotSizeUnit,
        stories: _stories,
        wallMaterial: _wallMaterial,
        finishingLevel: _finishingLevel,
        tileType: _tileType,
        paintPreference: _paintPreference,
        city: _selectedCity,
      );
      if (!mounted) return;
      setState(() => _result = estimate);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = '$e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      appBar: AppBar(
        title: const Text('Material Estimator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded, size: 20),
            tooltip: 'How it works',
            onPressed: _showInfoDialog,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroBanner(),
            const SizedBox(height: 16),
            _buildStepCard(1, 'Plot Size', Icons.square_foot_rounded,
                _buildPlotSizeSection()),
            const SizedBox(height: 12),
            _buildStepCard(2, 'Number of Stories', Icons.layers_rounded,
                _buildStoriesSection()),
            const SizedBox(height: 12),
            _buildStepCard(3, 'Wall Material', Icons.foundation_rounded,
                _buildWallMaterialSection()),
            const SizedBox(height: 12),
            _buildStepCard(4, 'Finishing Level', Icons.format_paint_rounded,
                _buildFinishingSection()),
            const SizedBox(height: 12),
            _buildStepCard(5, 'Floor Tiles', Icons.grid_on_rounded,
                _buildTileSection()),
            const SizedBox(height: 12),
            _buildStepCard(6, 'Paint Colors', Icons.format_paint_rounded,
                _buildPaintSection()),
            const SizedBox(height: 12),
            _buildStepCard(7, 'City', Icons.location_city_rounded,
                _buildCitySection()),
            const SizedBox(height: 20),
            _buildCalculateButton(),
            const SizedBox(height: 20),

            // ── Error banner with retry ─────────────────────
            if (_errorMsg != null && !_isLoading) _buildErrorBanner(),

            // ── Loading state ───────────────────────────────
            if (_isLoading) _buildLoading(),

            // ── Results ─────────────────────────────────────
            if (_result != null && !_isLoading) ...[
              _buildSummaryCard(),
              const SizedBox(height: 16),
              _buildMaterialsList(),
              const SizedBox(height: 16),
              _buildStrengthTips(),
              const SizedBox(height: 16),
              _buildDisclaimer(),
            ],
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HERO
  // ═══════════════════════════════════════════════════════════════
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.emerald, AppTheme.emeraldMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppTheme.gold, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI Material Calculator',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Powered by Gemini AI',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text(
              'Enter your plot details to get exact material quantities, '
              'top Pakistani brand recommendations, and expert tips for '
              'building a stronger house.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP CARD WRAPPER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStepCard(int step, String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.emeraldSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$step',
                  style: const TextStyle(
                    color: AppTheme.emerald,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 18, color: AppTheme.emeraldMid),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textBody,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          content,
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SECTIONS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildPlotSizeSection() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: TextField(
            controller: _plotSizeCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
            ],
            style: const TextStyle(
                color: AppTheme.textBody,
                fontSize: 15,
                fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'e.g. 5 or 120',
              prefixIcon: Icon(Icons.crop_square_rounded,
                  color: AppTheme.textFaint, size: 20),
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: AppTheme.bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _plotSizeUnit,
                isExpanded: true,
                icon: const Icon(Icons.arrow_drop_down,
                    color: AppTheme.textMuted),
                style: const TextStyle(
                    color: AppTheme.textBody,
                    fontSize: 13,
                    fontWeight: FontWeight.w500),
                items: _plotUnits
                    .map((u) =>
                        DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: (v) =>
                    setState(() => _plotSizeUnit = v ?? 'Marla'),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStoriesSection() {
    return Row(
      children: _storyOptions.map((opt) {
        final val = opt['value'] as int;
        final selected = _stories == val;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _stories = val),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected ? AppTheme.emerald : AppTheme.bg,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: selected ? AppTheme.emerald : AppTheme.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(opt['icon'] as IconData,
                      size: 24,
                      color:
                          selected ? AppTheme.gold : AppTheme.textMuted),
                  const SizedBox(height: 4),
                  Text(
                    opt['label'] as String,
                    style: TextStyle(
                      color:
                          selected ? Colors.white : AppTheme.textBody,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    opt['sub'] as String,
                    style: TextStyle(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.6)
                          : AppTheme.textFaint,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWallMaterialSection() {
    return Column(
      children: _wallMaterials.map((mat) {
        final selected = _wallMaterial == mat['label'];
        return GestureDetector(
          onTap: () => setState(() => _wallMaterial = mat['label'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? AppTheme.emeraldSoft : AppTheme.bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: selected ? AppTheme.emeraldMid : AppTheme.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.emeraldMid.withValues(alpha: 0.15)
                        : AppTheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    mat['icon'] as IconData,
                    size: 20,
                    color: selected
                        ? AppTheme.emerald
                        : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        mat['label'] as String,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.emerald
                              : AppTheme.textBody,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mat['desc'] as String,
                        style: TextStyle(
                          color: selected
                              ? AppTheme.emeraldMid
                              : AppTheme.textFaint,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 20, color: AppTheme.emerald),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFinishingSection() {
    return Row(
      children: _finishingLevels.map((f) {
        final selected = _finishingLevel == f['label'];
        return Expanded(
          child: GestureDetector(
            onTap: () =>
                setState(() => _finishingLevel = f['label'] as String),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: selected
                    ? (f['label'] == 'Premium'
                        ? AppTheme.goldSoft
                        : f['label'] == 'Standard'
                            ? AppTheme.emeraldSoft
                            : AppTheme.bg)
                    : AppTheme.bg,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                border: Border.all(
                  color: selected
                      ? (f['label'] == 'Premium'
                          ? AppTheme.gold
                          : f['label'] == 'Standard'
                              ? AppTheme.emeraldMid
                              : AppTheme.textFaint)
                      : AppTheme.border,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(f['icon'] as IconData,
                      size: 22,
                      color: selected
                          ? (f['label'] == 'Premium'
                              ? AppTheme.goldDark
                              : AppTheme.emerald)
                          : AppTheme.textMuted),
                  const SizedBox(height: 6),
                  Text(
                    f['label'] as String,
                    style: TextStyle(
                      color: selected
                          ? AppTheme.textBody
                          : AppTheme.textBody,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      f['desc'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textFaint,
                        fontSize: 9,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Tile type selector with images ────────────────────────
  Widget _buildTileSection() {
    return Column(
      children: _tileTypes.map((tile) {
        final selected = _tileType == tile['label'];
        return GestureDetector(
          onTap: () => setState(() => _tileType = tile['label'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: selected ? AppTheme.emeraldSoft : AppTheme.bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: selected ? AppTheme.emeraldMid : AppTheme.border,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd - 1),
              child: Row(
                children: [
                  // Tile image thumbnail
                  SizedBox(
                    width: 70,
                    height: 60,
                    child: Image.asset(
                      tile['img'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppTheme.surface,
                        child: const Icon(Icons.grid_on_rounded,
                            color: AppTheme.textFaint, size: 28),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tile['label'] as String,
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.emerald
                                  : AppTheme.textBody,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tile['desc'] as String,
                            style: TextStyle(
                              color: selected
                                  ? AppTheme.emeraldMid
                                  : AppTheme.textFaint,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (selected)
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.check_circle_rounded,
                          size: 20, color: AppTheme.emerald),
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Paint color palette selector ─────────────────────────
  Widget _buildPaintSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select your preferred paint color family:',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _paintOptions.map((opt) {
            final selected = _paintPreference == opt['label'];
            final colorVal = opt['color'] as int;
            return GestureDetector(
              onTap: () =>
                  setState(() => _paintPreference = opt['label'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppTheme.emeraldSoft : AppTheme.bg,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: selected ? AppTheme.emeraldMid : AppTheme.border,
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Color(colorVal),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.black.withValues(alpha: 0.1)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      opt['label'] as String,
                      style: TextStyle(
                        color: selected
                            ? AppTheme.emerald
                            : AppTheme.textBody,
                        fontSize: 12,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCitySection() {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppTheme.bg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedCity,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppTheme.textMuted),
          style: const TextStyle(
              color: AppTheme.textBody,
              fontSize: 14,
              fontWeight: FontWeight.w500),
          items: _cities
              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
              .toList(),
          onChanged: (v) =>
              setState(() => _selectedCity = v ?? 'Lahore'),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // CALCULATE BUTTON
  // ═══════════════════════════════════════════════════════════════
  Widget _buildCalculateButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : _estimate,
        icon: const Icon(Icons.auto_awesome_rounded, size: 20),
        label: Text(
          _isLoading ? 'Calculating…' : 'Calculate Materials with AI',
          style: const TextStyle(fontSize: 15),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ERROR BANNER (inline, with retry)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.errorSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 20, color: AppTheme.error),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'AI Estimation Failed',
                  style: TextStyle(
                    color: AppTheme.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _errorMsg ?? 'Unknown error',
            style: const TextStyle(
              color: AppTheme.textBody,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _estimate,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 42),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // LOADING
  // ═══════════════════════════════════════════════════════════════
  Widget _buildLoading() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
                strokeWidth: 3, color: AppTheme.emerald),
          ),
          const SizedBox(height: 18),
          const Text(
            'AI is calculating materials…',
            style: TextStyle(
              color: AppTheme.textBody,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.emeraldSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_plotSizeCtrl.text} $_plotSizeUnit · $_stories story · $_wallMaterial · $_finishingLevel',
              style: const TextStyle(
                color: AppTheme.emerald,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'This may take 10-15 seconds',
            style: TextStyle(color: AppTheme.textFaint, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SUMMARY
  // ═══════════════════════════════════════════════════════════════
  Widget _buildSummaryCard() {
    final r = _result!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.emerald, AppTheme.emeraldMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.summarize_rounded, color: AppTheme.gold, size: 22),
              SizedBox(width: 8),
              Text(
                'Estimated Total Cost',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _costBox('Minimum', r.totalCostMin)),
              const SizedBox(width: 12),
              Expanded(child: _costBox('Maximum', r.totalCostMax)),
            ],
          ),
          if (r.summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                r.summary,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _costBox(String label, int amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 10,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(
            'Rs ${formatPriceShort(amount)}',
            style: const TextStyle(
              color: AppTheme.gold,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MATERIALS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMaterialsList() {
    final materials = _result!.materials;
    final totalCost = materials.fold<int>(
        0, (sum, m) => sum + m.estimatedCost);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.emeraldSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.inventory_2_rounded,
                  size: 18, color: AppTheme.emerald),
            ),
            const SizedBox(width: 8),
            Text(
              'Material Breakdown (${materials.length} items)',
              style: const TextStyle(
                color: AppTheme.textBody,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...materials.map((m) => _materialCard(m, totalCost)),
      ],
    );
  }

  Widget _materialCard(MaterialQuantity m, int totalCost) {
    final name = m.name.toLowerCase();
    IconData icon;
    Color iconBg;
    if (name.contains('brick') || name.contains('block')) {
      icon = Icons.grid_view_rounded;
      iconBg = const Color(0xFFFEF3C7);
    } else if (name.contains('cement')) {
      icon = Icons.layers_outlined;
      iconBg = const Color(0xFFD1FAE5);
    } else if (name.contains('steel') ||
        name.contains('rebar') ||
        name.contains('iron')) {
      icon = Icons.construction_rounded;
      iconBg = const Color(0xFFDBEAFE);
    } else if (name.contains('sand')) {
      icon = Icons.terrain_rounded;
      iconBg = const Color(0xFFFEF9C3);
    } else if (name.contains('crush') || name.contains('aggregate')) {
      icon = Icons.grain_rounded;
      iconBg = const Color(0xFFF3E8FF);
    } else if (name.contains('paint') || name.contains('finish')) {
      icon = Icons.format_paint_rounded;
      iconBg = const Color(0xFFFCE7F3);
    } else if (name.contains('tile')) {
      icon = Icons.grid_on_rounded;
      iconBg = const Color(0xFFCFFAFE);
    } else if (name.contains('plumb') || name.contains('pipe')) {
      icon = Icons.plumbing_rounded;
      iconBg = const Color(0xFFE0E7FF);
    } else if (name.contains('electric') ||
        name.contains('wire') ||
        name.contains('conduit')) {
      icon = Icons.electrical_services_rounded;
      iconBg = const Color(0xFFFEF3C7);
    } else if (name.contains('water')) {
      icon = Icons.water_drop_rounded;
      iconBg = const Color(0xFFDBEAFE);
    } else {
      icon = Icons.handyman_rounded;
      iconBg = AppTheme.emeraldSoft;
    }

    final pct =
        totalCost > 0 ? (m.estimatedCost / totalCost * 100).round() : 0;

    // Find matching image for this material
    String? materialImage;
    for (final entry in _materialImageMap.entries) {
      if (name.contains(entry.key)) {
        materialImage = entry.value;
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Material image banner
            if (materialImage != null)
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppTheme.radiusMd - 1),
                  topRight: Radius.circular(AppTheme.radiusMd - 1),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 120,
                  child: Image.asset(
                    materialImage,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: AppTheme.textBody),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(m.name,
                          style: const TextStyle(
                              color: AppTheme.textBody,
                              fontSize: 14,
                              fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('${m.quantity} ${m.unit}',
                          style: const TextStyle(
                              color: AppTheme.textMuted, fontSize: 12)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Rs ${formatPriceShort(m.estimatedCost)}',
                      style: const TextStyle(
                          color: AppTheme.goldDark,
                          fontSize: 13,
                          fontWeight: FontWeight.w700),
                    ),
                    Text('$pct%',
                        style: const TextStyle(
                            color: AppTheme.textFaint, fontSize: 11)),
                  ],
                ),
              ],
            ),

            // Cost proportion bar
            if (pct > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 5,
                  backgroundColor: AppTheme.bg,
                  valueColor:
                      const AlwaysStoppedAnimation(AppTheme.emeraldMid),
                ),
              ),
            ],

            // Brands
            if (m.topBrands.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.verified_rounded,
                      size: 14, color: AppTheme.gold),
                  const SizedBox(width: 4),
                  const Text('Recommended Brands',
                      style: TextStyle(
                          color: AppTheme.textFaint,
                          fontSize: 10,
                          fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: m.topBrands.map((brand) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppTheme.emeraldSoft,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              AppTheme.emeraldMid.withValues(alpha: 0.2)),
                    ),
                    child: Text(brand,
                        style: const TextStyle(
                            color: AppTheme.emerald,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  );
                }).toList(),
              ),
            ],

            // Tip
            if (m.tip.isNotEmpty && m.tip != 'null') ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.goldSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        size: 15, color: AppTheme.goldDark),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(m.tip,
                          style: const TextStyle(
                              color: AppTheme.textBody,
                              fontSize: 11,
                              height: 1.4)),
                    ),
                  ],
                ),
              ),
            ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STRENGTH TIPS
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStrengthTips() {
    final tips = _result!.strengthTips;
    if (tips.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.goldSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_rounded, size: 22, color: AppTheme.goldDark),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Make Your House Stronger',
                  style: TextStyle(
                    color: AppTheme.textBody,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...tips.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: const BoxDecoration(
                      color: AppTheme.gold,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${entry.key + 1}',
                      style: const TextStyle(
                        color: AppTheme.emerald,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: AppTheme.textBody,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // DISCLAIMER
  // ═══════════════════════════════════════════════════════════════
  Widget _buildDisclaimer() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppTheme.textFaint),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Estimates are AI-generated based on average Pakistani market '
              'rates. Actual costs may vary by location, vendor, and seasonal '
              'price changes. Always consult a local contractor for final pricing.',
              style: TextStyle(
                color: AppTheme.textFaint,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // INFO DIALOG
  // ═══════════════════════════════════════════════════════════════
  void _showInfoDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome_rounded,
                color: AppTheme.gold, size: 22),
            SizedBox(width: 8),
            Text('How it works',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoRow(Icons.square_foot_rounded,
                  'Enter your plot size in Marla, Kanal, Sq Ft, or Sq Yards'),
              const SizedBox(height: 10),
              _infoRow(Icons.layers_rounded,
                  'Select number of stories (Single, Double, or Triple)'),
              const SizedBox(height: 10),
              _infoRow(Icons.foundation_rounded,
                  'Choose your wall material — e.g. Brick + Cement Mortar is the most common in Pakistan'),
              const SizedBox(height: 10),
              _infoRow(Icons.format_paint_rounded,
                  'Pick your finishing level: Economy, Standard, or Premium'),
              const SizedBox(height: 10),
              _infoRow(Icons.auto_awesome_rounded,
                  'AI calculates exact quantities, costs, and recommends top Pakistani brands like Lucky Cement, DG Cement, Amreli Steel'),
              const SizedBox(height: 16),
              const Text(
                'Powered by Google Gemini AI with real Pakistani construction market data.',
                style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppTheme.emeraldMid),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textBody,
                  height: 1.4)),
        ),
      ],
    );
  }
}

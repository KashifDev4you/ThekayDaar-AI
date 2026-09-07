// lib/Client/client_projects_list_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ali_app/Client/client_project_detail.dart';
import 'package:ali_app/utils/price_formatter.dart';
import 'package:ali_app/utils/time_ago.dart';
import 'package:ali_app/Widgets/language_toggle_widget.dart';

// =============================================================================
// STATIC CITY -> AREAS MAP
// =============================================================================
// =============================================================================
// STATIC CITY -> AREAS MAP
// Expanded, alphabetically-sorted (A-Z) list of real major localities per city.
// =============================================================================
const Map<String, List<String>> kPakistanCityAreas = {
  'Abbottabad': [
    'Cantt', 'Jinnahabad', 'Kakul Road', 'Mandian', 'Mansehra Road',
    'Nawanshehr', 'Supply Bazaar',
  ],
  'Bahawalpur': [
    'Ahmedpur East Road', 'Baghdad-ul-Jadeed', 'Circular Road',
    'Dubai Chowk', 'Model Town A', 'Model Town B', 'Satellite Town',
    'Shadra', 'Yazman Road',
  ],
  'Bahawalnagar': ['City Area', 'Fort Abbas Road', 'Satellite Town'],
  'Chiniot': ['City Area', 'Kot Molvi Road', 'Rustam'],
  'Dera Ghazi Khan': [
    'Jampur Road', 'Model Town', 'Muzaffargarh Road', 'Sakhi Sarwar Road',
  ],
  'Dera Ismail Khan': ['Circular Road', 'Kotla', 'Ghazi Road'],
  'Faisalabad': [
    'Abdullahpur', 'Batala Colony', 'Canal Road', 'D Ground',
    'Gulberg', 'Gulistan Colony', 'Jaranwala Road', 'Jinnah Colony',
    'Kohinoor City', 'Madina Town', 'Mansoorabad', 'Millat Town',
    'Peoples Colony', 'Samanabad', 'Susan Road', 'Warispura',
  ],
  'Gojra': ['City Area', 'Railway Road'],
  'Gujranwala': [
    'Civil Lines', 'GT Road Area', 'Model Town', 'Peoples Colony',
    'Rahwali Cantt', 'Satellite Town', 'Wapda Town',
  ],
  'Gujrat': [
    'Allama Iqbal Road', 'City Center', 'Fawara Chowk', 'GT Road Area',
    'Satellite Town',
  ],
  'Hafizabad': ['City Area', 'Sukheke Road'],
  'Hyderabad': [
    'Auto Bhan Road', 'Gulistan-e-Sajjad', 'Hussainabad', 'Latifabad',
    'Landhi Road', 'Qasimabad', 'Saddar', 'Tilak Charhi',
  ],
  'Islamabad': [
    'Bahria Town Islamabad', 'Bani Gala', 'Blue Area', 'D-12', 'DHA Islamabad',
    'E-7', 'E-11', 'F-6', 'F-7', 'F-8', 'F-10', 'F-11', 'G-6', 'G-7', 'G-8',
    'G-9', 'G-10', 'G-11', 'G-13', 'G-14', 'H-8', 'I-8', 'I-9', 'I-10',
    'Margalla Town', 'Pakistan Town', 'Park Road Area', 'PWD Housing Society',
    'Sector E-11', 'Soan Garden',
  ],
  'Jhang': ['City Area', 'Kacha Road', 'Satellite Town'],
  'Jhelum': ['Cantt', 'City Area', 'GT Road Area'],
  'Kamoke': ['G.T. Road', 'Model Town'],
  'Kasur': ['Kot Radha Kishan Road', 'Model Town', 'Station Road'],
  'Karachi': [
    'Ancholi', 'Bahadurabad', 'Baldia Town', 'Bath Island',
    'Clifton', 'Defence (DHA)', 'F.B. Area', 'Federal B Area',
    'Garden East', 'Gulberg', 'Gulistan-e-Johar', 'Gulshan-e-Iqbal',
    'Gulshan-e-Maymar', 'Gulzar-e-Hijri', 'II Chundrigar Road Area',
    'Jamshed Town', 'Kemari', 'Korangi', 'Landhi', 'Lyari',
    'Malir', 'Model Colony', 'Nazimabad', 'North Karachi',
    'North Nazimabad', 'Orangi Town', 'PECHS', 'Saddar',
    'Shah Faisal Colony', 'Shahra-e-Faisal Area', 'Sharfabad',
    'Soldier Bazaar', 'Surjani Town', 'Tariq Road Area',
    'University Road Area',
  ],
  'Khanewal': ['City Area', 'Kacha Khoo Road'],
  'Kotri': ['Bhitai Colony', 'Kotri Industrial Area'],
  'Lahore': [
    'Allama Iqbal Town', 'Bahria Town Lahore', 'Barki Road', 'Cantt',
    'DHA Lahore', 'Faisal Town', 'Gaddafi Stadium Area', 'Garden Town',
    'Gulberg', 'Ichhra', 'Iqbal Town', 'Johar Town', 'Liberty Market Area',
    'Model Town', 'Mughalpura', 'Muslim Town', 'New Garden Town',
    'Samanabad', 'Sanda', 'Shadman', 'Shahdara', 'Township', 'Valencia Town',
    'Wapda Town',
  ],
  'Larkana': ['City Area', 'Model Colony', 'Naz Chowk'],
  'Mandi Bahauddin': ['City Area', 'Phalia Road'],
  'Mardan': ['Bank Road', 'Bar Road', 'Katlang Road', 'Sheikh Maltoon Town'],
  'Mingora': ['Green Chowk', 'Kanju', 'Saidu Sharif'],
  'Mirpur Khas': ['City Area', 'Housing Society'],
  'Multan': [
    'Bosan Road', 'Cantt', 'Gulgasht Colony', 'Model Town',
    'New Multan', 'Nishtar Road Area', 'Shah Rukn-e-Alam Colony',
    'Vehari Road',
  ],
  'Muridke': ['City Area', 'GT Road Area'],
  'Muzaffargarh': ['City Area', 'Ghazi Ghat Road'],
  'Narowal': ['City Area', 'Sialkot Road'],
  'Nawabshah': ['City Area', 'Housing Society'],
  'Okara': ['City Area', 'Model Town', 'Railway Road'],
  'Pakpattan': ['City Area', 'Sahiwal Road'],
  'Peshawar': [
    'Board Bazaar', 'Cantt', 'Faqirabad', 'Gulbahar', 'Hayatabad',
    'Karkhano Market Area', 'Ring Road Area', 'Regi Model Town',
    'Saddar', 'University Town',
  ],
  'Quetta': [
    'Cantt', 'Jinnah Town', 'Marriabad', 'Sariab Road', 'Satellite Town',
    'Zarghoon Road',
  ],
  'Rahim Yar Khan': ['City Area', 'Model Town', 'Sheikh Zayed Colony'],
  'Rawalpindi': [
    'Adiala Road', 'Bahria Town Rawalpindi', 'Chaklala', 'Chandni Chowk',
    'Cantt', 'Committee Chowk', 'DHA Rawalpindi', 'Dhoke Kashmirian',
    'Ghouri Town', 'Gulraiz Housing Scheme', 'Murree Road Area',
    'Peshawar Road', 'PWD Housing Scheme', 'Satellite Town', 'Waris Khan',
    'Westridge',
  ],
  'Sadiqabad': ['City Area', 'Railway Road'],
  'Sahiwal': ['City Area', 'Farid Town', 'High Street Area'],
  'Sargodha': ['City Area', 'Satellite Town', 'University Road Area'],
  'Sheikhupura': ['City Area', 'Farooq Ganj', 'GT Road Area'],
  'Sialkot': [
    'Cantt', 'City Area', 'Kashmir Road Area', 'Model Town', 'Paris Road',
    'Rangpura',
  ],
  'Sukkur': ['Barrage Colony', 'City Area', 'Military Road', 'Shikarpur Road'],
  'Swabi': ['City Area', 'GT Road Area'],
  'Taxila': ['City Area', 'Wah Road'],
  'Toba Tek Singh': ['City Area', 'Gojra Road'],
  'Turbat': ['City Area', 'Kech'],
  'Vehari': ['City Area', 'Mailsi Road'],
  'Wah Cantt': ['Lala Rukh', 'Wah Cantt Area'],
};
class ClientProjectsListScreen extends StatefulWidget {
  const ClientProjectsListScreen({super.key});

  @override
  State<ClientProjectsListScreen> createState() =>
      _ClientProjectsListScreenState();
}

class _LocationOption {
  final String label;
  final bool isArea;
  final String? parentCity;

  const _LocationOption(this.label, {this.isArea = false, this.parentCity});

  @override
  bool operator ==(Object other) =>
      other is _LocationOption &&
      other.label == label &&
      other.isArea == isArea &&
      other.parentCity == parentCity;

  @override
  int get hashCode => Object.hash(label, isArea, parentCity);
}

class _ClientProjectsListScreenState extends State<ClientProjectsListScreen> {
  // ── THEME TOKENS ──────────────────────────────────────────────────────────
  static const _bg = Color(0xFFF7F5EF);
  static const _surface = Colors.white;
  static const _amber = Color(0xFFC9A227);
  static const _navy = Color(0xFF0E3B2E);
  static const _navyLight = Color(0xFF1F2A26);
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);

  String _selectedCity = 'All';
  String _selectedArea = 'All';
  String _selectedStatus = 'All';

  final Stream<QuerySnapshot> _projectsStream = FirebaseFirestore.instance
      .collection('projects')
      .where('clientId', isEqualTo: FirebaseAuth.instance.currentUser?.uid ?? '')
      .snapshots();

  void _clearLocationFilter() {
    setState(() {
      _selectedCity = 'All';
      _selectedArea = 'All';
    });
  }

  void _onLocationSelected(_LocationOption option) {
    setState(() {
      if (option.isArea) {
        _selectedArea = option.label;
        _selectedCity = option.parentCity ?? 'All';
      } else {
        _selectedCity = option.label;
        _selectedArea = 'All';
      }
    });
  }

  List<_LocationOption> _buildLocationOptions(List<QueryDocumentSnapshot> docs) {
    final optionSet = <_LocationOption>{};

    kPakistanCityAreas.forEach((city, areas) {
      optionSet.add(_LocationOption(city));
      for (final area in areas) {
        optionSet.add(_LocationOption(area, isArea: true, parentCity: city));
      }
    });

    for (final doc in docs) {
      final d = doc.data() as Map<String, dynamic>;
      final city = (d['city'] as String? ?? '').trim();
      final area = (d['area'] as String? ?? '').trim();
      if (city.isNotEmpty) optionSet.add(_LocationOption(city));
      if (area.isNotEmpty) {
        optionSet.add(_LocationOption(area, isArea: true, parentCity: city.isNotEmpty ? city : null));
      }
    }

    final list = optionSet.toList()
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: StreamBuilder<QuerySnapshot>(
        stream: _projectsStream,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final allDocs = snapshot.data?.docs ?? [];
          final locationOptions = _buildLocationOptions(allDocs);

          // Apply filters to the actual project list.
          var docs = allDocs.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final city = (d['city'] as String? ?? '').trim();
            final area = (d['area'] as String? ?? '').trim();
            final status = (d['status'] as String? ?? 'open').trim();

            final cityMatch = _selectedCity == 'All' || city == _selectedCity;
            final areaMatch = _selectedArea == 'All' || area == _selectedArea;
            final statusMatch = _selectedStatus == 'All' ||
                status.toLowerCase() == _selectedStatus.toLowerCase();

            return cityMatch && areaMatch && statusMatch;
          }).toList();

          docs.sort((a, b) {
            final aT = (a.data() as Map<String, dynamic>)['createdAt'];
            final bT = (b.data() as Map<String, dynamic>)['createdAt'];
            if (aT == null && bT == null) return 0;
            if (aT == null) return 1;
            if (bT == null) return -1;
            return (bT as Timestamp).compareTo(aT as Timestamp);
          });

          // Quick counts for the header stat chips.
          final openCount = allDocs.where((doc) {
            final status = ((doc.data() as Map<String, dynamic>)['status']
                        as String? ??
                    'open')
                .toLowerCase();
            return status == 'open';
          }).length;
          final totalCount = allDocs.length;

          return LanguageBuilder(
            builder: (context, t) {
              return CustomScrollView(
                slivers: [
                  // ── NEW: Gradient header replacing the flat AppBar ─────────
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    expandedHeight: 128,
                    backgroundColor: _navy,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                      title: Text(
                        t.t('My Projects'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_navy, _navyLight],
                      ),
                    ),
                    child: SafeArea(
                      child: Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20, bottom: 14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _HeaderStatChip(
                                icon: Icons.grid_view_rounded,
                                label: '$totalCount total',
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              _HeaderStatChip(
                                icon: Icons.bolt_rounded,
                                label: '$openCount open',
                                color: _amber,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Filters + results-found dash bar ───────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: _LocationAutocompleteField(
                    options: locationOptions,
                    selectedCity: _selectedCity,
                    selectedArea: _selectedArea,
                    onLocationSelected: _onLocationSelected,
                    onClear: _clearLocationFilter,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: ['All', 'Open', 'In Progress', 'Completed']
                          .map((status) {
                        final active = status == _selectedStatus;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedStatus = status),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: active ? _navy : _surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: active ? _navy : _border),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: active
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: active ? Colors.white : _textSec,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),

              // ── NEW: "X Projects Found" dash bar ────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: _ProjectsFoundDash(
                    count: docs.length,
                    isFiltered: _selectedCity != 'All' ||
                        _selectedArea != 'All' ||
                        _selectedStatus != 'All',
                    isLoading: isLoading,
                  ),
                ),
              ),

              // ── Project list / empty / loading states ──────────────────
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _amber),
                  ),
                )
              else if (snapshot.hasError)
                SliverFillRemaining(
                  child: Center(child: Text('Error: ${snapshot.error}')),
                )
              else if (docs.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('No projects match this filter.')),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) {
                        final doc = docs[i];
                        final d = doc.data() as Map<String, dynamic>;
                        return _ProjectTile(
                          projectId: doc.id,
                          data: d,
                        );
                      },
                      childCount: docs.length,
                    ),
                  ),
                ),
            ],
          );
            },
          );
        },
      ),
    );
  }
}

// =============================================================================
// HEADER STAT CHIP — small pill shown in the gradient header
// =============================================================================
class _HeaderStatChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _HeaderStatChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color == Colors.white ? Colors.white70 : color,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// PROJECTS FOUND DASH — the "X Projects Found" summary bar under filters
// =============================================================================
class _ProjectsFoundDash extends StatelessWidget {
  final int count;
  final bool isFiltered;
  final bool isLoading;

  static const _navy = Color(0xFF0E3B2E);
  static const _amber = Color(0xFFC9A227);
  static const _amberLight = Color(0xFFFBF6E3);
  static const _border = Color(0xFFE3E0D5);
  static const _textSec = Color(0xFF5D6B64);

  const _ProjectsFoundDash({
    required this.count,
    required this.isFiltered,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _amberLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: _amber.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.search_rounded, size: 16, color: _amber),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: isLoading
                ? const Text(
                    'Searching projects...',
                    style: TextStyle(
                        fontSize: 13, color: _textSec, fontWeight: FontWeight.w500),
                  )
                : Text.rich(
                    TextSpan(
                      style: const TextStyle(fontSize: 13, color: _navy),
                      children: [
                        TextSpan(
                          text: '$count ',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        TextSpan(
                          text: count == 1 ? 'project found' : 'projects found',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (isFiltered)
                          const TextSpan(
                            text: '  ·  filters applied',
                            style: TextStyle(
                                color: _textSec, fontWeight: FontWeight.normal),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// LOCATION AUTOCOMPLETE FIELD (city + area)
// =============================================================================
// =============================================================================
// LOCATION AUTOCOMPLETE FIELD (city + area)
// FIX: previously used an OverlayEntry anchored via CompositedTransformFollower.
// Since this field lives inside a CustomScrollView (SliverToBoxAdapter),
// overlay rebuilds could collide with the viewport's layout pass, causing
// "!_doingMountOrUpdate is not true" crashes during scroll.
// This version renders the dropdown IN-FLOW (a normal widget in the tree,
// expanding the Column height) instead of a separate Overlay — no Overlay,
// no CompositedTransformFollower, so it can never race with sliver layout.
// =============================================================================
class _LocationAutocompleteField extends StatefulWidget {
  final List<_LocationOption> options;
  final String selectedCity;
  final String selectedArea;
  final ValueChanged<_LocationOption> onLocationSelected;
  final VoidCallback onClear;

  static const _amber = Color(0xFFC9A227);
  static const _amberLight = Color(0xFFFBF6E3);
  static const _amberDark = Color(0xFFA8861D);
  static const _surface = Colors.white;
  static const _border = Color(0xFFE3E0D5);
  static const _textSec = Color(0xFF5D6B64);

  const _LocationAutocompleteField({
    required this.options,
    required this.selectedCity,
    required this.selectedArea,
    required this.onLocationSelected,
    required this.onClear,
  });

  @override
  State<_LocationAutocompleteField> createState() =>
      _LocationAutocompleteFieldState();
}

class _LocationAutocompleteFieldState
    extends State<_LocationAutocompleteField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<_LocationOption> _filteredOptions = [];
  bool _isOpen = false;

  bool get _hasSelection =>
      widget.selectedCity != 'All' || widget.selectedArea != 'All';

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleTextChange);
  }

  @override
  void didUpdateWidget(covariant _LocationAutocompleteField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) {
      // Safe here: this just updates local state and calls setState,
      // no Overlay/viewport interaction involved anymore.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _filterOptions(_controller.text));
        }
      });
    }
  }

  void _handleFocusChange() {
    setState(() {
      _isOpen = _focusNode.hasFocus;
      if (_isOpen) _filterOptions(_controller.text);
    });
  }

  void _handleTextChange() {
    setState(() => _filterOptions(_controller.text));
  }

  void _filterOptions(String text) {
    final query = text.trim().toLowerCase();
    _filteredOptions = query.isEmpty
        ? widget.options
        : widget.options
            .where((o) => o.label.toLowerCase().contains(query))
            .toList();
  }

  void _selectOption(_LocationOption option) {
    _controller.text = option.label;
    widget.onLocationSelected(option);
    _focusNode.unfocus();
  }

  void _clear() {
    _controller.clear();
    widget.onClear();
    setState(() => _filterOptions(''));
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleTextChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: 'location_search_field',
      onTapOutside: (_) => _focusNode.unfocus(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            decoration: InputDecoration(
              hintText: 'Search by city or area...',
              prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: _clear,
                    )
                  : null,
              filled: true,
              fillColor: _LocationAutocompleteField._surface,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: _LocationAutocompleteField._border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    BorderSide(color: _LocationAutocompleteField._border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: _LocationAutocompleteField._amber),
              ),
            ),
          ),

          // ── IN-FLOW dropdown (replaces the old Overlay) ─────────────────
          if (_isOpen) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 280),
              decoration: BoxDecoration(
                color: _LocationAutocompleteField._surface,
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: _LocationAutocompleteField._border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _filteredOptions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No matching city or area',
                        style: TextStyle(
                            fontSize: 13,
                            color: _LocationAutocompleteField._textSec),
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      // Own scroll physics so this internal list scrolls
                      // independently instead of fighting the outer
                      // CustomScrollView's scroll gestures.
                      physics: const ClampingScrollPhysics(),
                      itemCount: _filteredOptions.length,
                      separatorBuilder: (_, _) => Container(
                          height: 1,
                          color: _LocationAutocompleteField._border),
                      itemBuilder: (context, index) {
                        final opt = _filteredOptions[index];
                        return InkWell(
                          onTap: () => _selectOption(opt),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Icon(
                                  opt.isArea
                                      ? Icons.place_outlined
                                      : Icons.location_city_rounded,
                                  size: 16,
                                  color: _LocationAutocompleteField._textSec,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    opt.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: opt.isArea
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (opt.isArea && opt.parentCity != null)
                                  Text(
                                    opt.parentCity!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],

          if (_hasSelection) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _LocationAutocompleteField._amberLight,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: _LocationAutocompleteField._amber),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.selectedArea != 'All'
                            ? 'Filtering: ${widget.selectedArea}'
                            : 'Filtering: ${widget.selectedCity}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _LocationAutocompleteField._amberDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: _clear,
                        child: Icon(Icons.close_rounded,
                            size: 14,
                            color: _LocationAutocompleteField._amberDark),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
class _ProjectTile extends StatelessWidget {
  final String projectId;
  final Map<String, dynamic> data;

  const _ProjectTile({required this.projectId, required this.data});

  static const _statusOpenBg = Color(0xFFD1FAE5);
  static const _statusOpenText = Color(0xFF10B981);
  static const _amber50 = Color(0xFFFBF6E3);
  static const _amber700 = Color(0xFFA8861D);
  static const _amberAccent = Color(0xFFC9A227);
  static const _textPri = Color(0xFF0E3B2E);
  static const _textSec = Color(0xFF5D6B64);
  static const _border = Color(0xFFE3E0D5);
  static const _navy = Color(0xFF0E3B2E);

  @override
  Widget build(BuildContext context) {
    final title = data['title'] as String? ?? '';
    final city = data['city'] as String? ?? '';
    final area = data['area'] as String? ?? '';
    final status = data['status'] as String? ?? 'open';
    final isOpen = status.toLowerCase() == 'open';
    final budgetMin = data['budgetMin'] as String? ?? '0';
    final budgetMax = data['budgetMax'] as String? ?? '0';
    final bidsCount = (data['bids'] as List?)?.length ?? 0;
    final postedLabel = timeAgo(data['createdAt']);

    final coverImage = data['coverImage'] as String?;
    final images =
        (data['images'] as List?)?.map((e) => e.toString()).toList();
    final imageUrl = (coverImage != null && coverImage.trim().isNotEmpty)
        ? coverImage
        : ((images != null && images.isNotEmpty) ? images.first : null);
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ClientProjectDetailScreen(projectId: projectId, data: data),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage)
              SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      color: const Color(0xFFF7F5EF),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _amberAccent,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 140,
                    color: const Color(0xFFF7F5EF),
                    child: const Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: _textSec,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 100,
                width: double.infinity,
                color: const Color(0xFFF7F5EF),
                child: const Center(
                  child: Icon(
                    Icons.construction_outlined,
                    color: _textSec,
                    size: 28,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _textPri,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isOpen ? _statusOpenBg : _amber50,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          isOpen ? 'Open' : status,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isOpen ? _statusOpenText : _amber700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.location_on_outlined,
                          size: 13, color: Colors.grey.shade400),
                      const SizedBox(width: 4),
                      Text(
                        '$area, $city',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                  if (postedLabel.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 13, color: Colors.grey.shade400),
                        const SizedBox(width: 4),
                        Text(
                          'Posted $postedLabel',
                          style: TextStyle(
                              fontSize: 11, color: Colors.grey.shade400),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rs ${formatPriceShort(budgetMin)} – ${formatPriceShort(budgetMax)}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _navy,
                        ),
                      ),
                      Text(
                        '$bidsCount bid${bidsCount == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, color: _textSec),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
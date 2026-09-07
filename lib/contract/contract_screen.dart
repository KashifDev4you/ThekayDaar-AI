// create_contract_screen.dart
//
// Screen where the CLIENT reviews/finalizes payment terms, scope of work,
// and legal terms BEFORE work starts.
//
// CHANGED (this version):
//   1. Client + Contractor identity (CNIC, phone, area/city) is now
//      auto-fetched from Firestore (`clients/{id}` and `thekaydaars/{id}`)
//      instead of being typed in manually. If a profile is missing its
//      area/city or CNIC, the user is told to go complete their profile —
//      we do NOT let them type it in here, since that info must come from
//      the verified profile.
//   2. Scope of work is auto-generated from the project's `services` list
//      (falls back to a template by `projectType` if `services` is empty).
//      Tasks no longer carry a per-task cost — the contract is about WHAT
//      work will be done and whether it's DONE, not itemized pricing.
//      Payment only happens at the milestone level (Advance/Mid/Final).
//   3. Total project amount is now FIXED — pulled from the project's
//      already-accepted bid (`acceptedBid.amount`), not summed from tasks.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ali_app/model/contract_model.dart';
import 'package:ali_app/services/contract_services.dart';
import 'package:ali_app/contract/contract_detail_screen.dart';
import 'package:ali_app/contract/scope_of_work/scope_templates.dart';
import 'package:ali_app/Widgets/language_toggle_widget.dart';

const Color kNavy = Color(0xFF0E3B2E);
const Color kNavyLight = Color(0xFF1A5C46);
const Color kAmber = Color(0xFFC9A227);
const Color kDanger = Color(0xFFDC2626);

class CreateContractScreen extends StatefulWidget {
  final String projectId;
  final String clientId;
  final String clientName;
  final String contractorId;
  final String contractorName;

  const CreateContractScreen({
    super.key,
    required this.projectId,
    required this.clientId,
    required this.clientName,
    required this.contractorId,
    required this.contractorName,
  });

  @override
  State<CreateContractScreen> createState() => _CreateContractScreenState();
}

class _CreateContractScreenState extends State<CreateContractScreen> {
  final ContractService _service = ContractService();

  // ── Loading / fetch state ────────────────────────────────────────────
  bool _isLoadingDetails = true;
  String? _loadError;
  bool _isSaving = false;

  // ── Fetched CLIENT identity (read-only, from clients/{id}) ────────────
  String _clientCnic = '';
  String _clientPhone = '';
  String _clientArea = '';
  String _clientCity = '';
  bool get _clientLocationMissing =>
      _clientArea.trim().isEmpty && _clientCity.trim().isEmpty;
  bool get _clientCnicMissing => _clientCnic.trim().isEmpty;

  // ── Fetched CONTRACTOR identity (read-only, from thekaydaars/{id}) ────
  String _contractorCnic = '';
  String _contractorPhone = '';
  String _contractorCity = '';
  bool get _contractorCnicMissing => _contractorCnic.trim().isEmpty;

  // ── Fetched PROJECT info ───────────────────────────────────────────────
  String _projectType = '';
  double _totalAmount = 0; // fixed, from acceptedBid.amount

  // ── Payment terms ──────────────────────────────────────────────────────
  double _advancePercent = 10;

  // ── Scope of work (auto-generated, editable) ───────────────────────────
  final List<ScopeItem> _scopeItems = [];
  final TextEditingController _taskCtrl = TextEditingController();
  final TextEditingController _daysCtrl = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  // ── Legal terms: only the SITE/WORK address stays manual — kaam kahan
  //    ho raha hai, yeh contractor ke registered address se alag ho sakta
  //    hai, isliye har baar client ko yeh confirm karna hota hai. ─────────
  final TextEditingController _siteAddressCtrl = TextEditingController();

  // ── Project brief description (optional) ────────────────────────────
  final TextEditingController _projectBriefCtrl = TextEditingController();

  String _materialsResponsibility =
      'contractor'; // 'client' | 'contractor' | 'shared'
  double _delayPenaltyPercent = 0;
  int _warrantyDays = 7;

  // Fallback task templates — used only when the project has no `services`
  // array saved on it (older projects / edge cases).
  static const Map<String, List<String>> _taskTemplatesByProjectType = {
    'New Construction': [
      'Site preparation & excavation',
      'Foundation work',
      'Structure / grey work',
      'Electrical wiring',
      'Plumbing work',
      'Plastering',
      'Flooring',
      'Paint & finishing',
    ],
    'Renovation': [
      'Demolition of old structure',
      'Repair & structural fixes',
      'Electrical rework',
      'Plumbing rework',
      'Paint & finishing',
    ],
    'Interior Design': [
      'Design consultation & planning',
      'Material selection',
      'Execution / installation',
      'Final touch-up',
    ],
  };
  static const List<String> _genericFallbackTasks = [
    'Site inspection & planning',
    'Execution of work',
    'Final inspection & handover',
  ];

  @override
  void initState() {
    super.initState();
    _fetchAllDetails();
  }

  @override
  void dispose() {
    _taskCtrl.dispose();
    _daysCtrl.dispose();
    _siteAddressCtrl.dispose();
    _projectBriefCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // Pulls client, contractor, and project docs in parallel and populates
  // everything above. This is the core of "auto-fetch instead of type it".
  // ---------------------------------------------------------------------
  Future<void> _fetchAllDetails() async {
    setState(() {
      _isLoadingDetails = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        FirebaseFirestore.instance
            .collection('clients')
            .doc(widget.clientId)
            .get(),
        FirebaseFirestore.instance
            .collection('thekaydaars')
            .doc(widget.contractorId)
            .get(),
        FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.projectId)
            .get(),
      ]);

      final clientSnap = results[0];
      final contractorSnap = results[1];
      final projectSnap = results[2];

      if (clientSnap.exists) {
        final c = clientSnap.data() as Map<String, dynamic>;
        _clientCnic = (c['nicNumber'] ?? '').toString();
        _clientPhone = (c['phone'] ?? '').toString();
        _clientArea = (c['area'] ?? '').toString();
        _clientCity = (c['city'] ?? '').toString();
      }

      if (contractorSnap.exists) {
        final t = contractorSnap.data() as Map<String, dynamic>;
        _contractorCnic = (t['nicNumber'] ?? '').toString();
        _contractorPhone = (t['phone'] ?? '').toString();
        _contractorCity = (t['city'] ?? '').toString();
      }

      if (projectSnap.exists) {
        final p = projectSnap.data() as Map<String, dynamic>;
        _projectType = (p['projectType'] ?? '').toString();

        // acceptedBid.amount is stored as a STRING in Firestore — parse safely.
        final acceptedBid = p['acceptedBid'] as Map<String, dynamic>?;
        final rawAmount =
            acceptedBid?['amount']?.toString() ??
            p['acceptedAmount']?.toString() ??
            '0';
        _totalAmount = double.tryParse(rawAmount) ?? 0;

        // Pre-fill site address with project's area/city as a starting
        // point — client can still edit it since work site may differ.
        final pArea = (p['area'] ?? '').toString();
        final pCity = (p['city'] ?? '').toString();
        if (pArea.isNotEmpty || pCity.isNotEmpty) {
          _siteAddressCtrl.text = [
            pArea,
            pCity,
          ].where((e) => e.isNotEmpty).join(', ');
        }

        // Auto-generate scope of work from `services`, falling back to a
        // template keyed by projectType, falling back to generic tasks.
        final services = ((p['services'] ?? []) as List)
            .map((e) => e.toString())
            .toList();
        final taskNames = services.isNotEmpty
            ? services
            : (_taskTemplatesByProjectType[_projectType] ??
                  _genericFallbackTasks);

        _scopeItems.clear();
        for (final name in taskNames) {
          _scopeItems.add(ScopeItem(task: name, timelineDays: 0));
        }
      }
    } catch (e) {
      _loadError = 'Details load nahi ho sakay: $e';
    } finally {
      if (mounted) setState(() => _isLoadingDetails = false);
    }
  }

  void _addCustomScopeItem() {
    if (_taskCtrl.text.trim().isEmpty) return;
    setState(() {
      _scopeItems.add(
        ScopeItem(
          task: _taskCtrl.text.trim(),
          timelineDays: int.tryParse(_daysCtrl.text.trim()) ?? 0,
          decision: ScopeDecision.included,
        ),
      );
      _taskCtrl.clear();
      _daysCtrl.clear();
    });
  }

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  List<Milestone> _buildMilestones() {
    final advanceAmount = _totalAmount * (_advancePercent / 100);
    final remaining = _totalAmount - advanceAmount;
    final midAmount = remaining / 2;
    final finalAmount = remaining - midAmount;

    return [
      Milestone(
        title: 'Advance Payment',
        percent: _advancePercent,
        amount: advanceAmount,
      ),
      Milestone(
        title: 'Mid-Project Payment',
        percent: _totalAmount == 0 ? 0 : (midAmount / _totalAmount * 100),
        amount: midAmount,
      ),
      Milestone(
        title: 'Final Payment on Completion',
        percent: _totalAmount == 0 ? 0 : (finalAmount / _totalAmount * 100),
        amount: finalAmount,
      ),
    ];
  }

  // Validation — profile-sourced fields are checked for completeness
  // (not editable here), site address + start date are checked as before.
  bool _validateBeforeSubmit() {
    if (_clientCnicMissing) {
      _snack(
        'Client ka CNIC profile mein missing hai — pehle profile complete karein.',
      );
      return false;
    }
    if (_contractorCnicMissing) {
      _snack(
        'Contractor ka CNIC profile mein missing hai — unhein profile complete karne ke liye bolein.',
      );
      return false;
    }
    if (_clientLocationMissing) {
      _snack(
        'Apna area/city profile mein fill karein — yeh contract ke liye zaroori hai.',
      );
      return false;
    }
    if (_siteAddressCtrl.text.trim().isEmpty) {
      _snack(
        'Site/work address required hai — kaam kahan hoga ye clear hona chahiye.',
      );
      return false;
    }
    if (_scopeItems.where((s) => s.included).isEmpty) {
      _snack('Kam se kam 1 scope-of-work item required hai.');
      return false;
    }
    if (_startDate == null) {
      _snack('Work start date select karein.');
      return false;
    }
    if (_totalAmount <= 0) {
      _snack(
        'Project ka accepted amount nahi mila — project record check karein.',
      );
      return false;
    }
    return true;
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submitContract() async {
    if (!_validateBeforeSubmit()) return;

    setState(() => _isSaving = true);

    final advanceAmount = _totalAmount * (_advancePercent / 100);
    final clientAddress = [
      _clientArea,
      _clientCity,
    ].where((e) => e.trim().isNotEmpty).join(', ');

    final contract = ContractModel(
      contractId: '',
      projectId: widget.projectId,
      clientId: widget.clientId,
      contractorId: widget.contractorId,
      clientName: widget.clientName,
      contractorName: widget.contractorName,
      projectBriefDescription: _projectBriefCtrl.text.trim(),
      advancePercent: _advancePercent,
      advanceAmount: advanceAmount,
      totalAmount: _totalAmount,
      scopeOfWork: _scopeItems,
      milestones: _buildMilestones(),
      expectedStartDate: _startDate,
      expectedEndDate: _endDate,
      legalTerms: ContractLegalTerms(
        clientCnic: _clientCnic,
        contractorCnic: _contractorCnic,
        clientPhone: _clientPhone,
        contractorPhone: _contractorPhone,
        clientAddress: clientAddress,
        contractorAddress: _siteAddressCtrl.text.trim(),
        materialsResponsibility: _materialsResponsibility,
        delayPenaltyPercent: _delayPenaltyPercent,
        warrantyDays: _warrantyDays,
      ),
    );

    try {
      final contractId = await _service.createContract(contract);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ContractDetailScreen(
              contractId: contractId,
              currentUserId: widget.clientId,
              currentUserFullName: widget.clientName,
              isContractor: false,
            ),
          ),
        );
      }
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingDetails) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F5EF),
        body: Center(child: CircularProgressIndicator(color: kNavy)),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F5EF),
        appBar: AppBar(
          title: const Text('Create Work Agreement'),
          backgroundColor: kNavy,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: kDanger, size: 40),
                const SizedBox(height: 12),
                Text(_loadError!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _fetchAllDetails,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F5EF),
      appBar: AppBar(
        title: const Text('Create Work Agreement'),
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8, top: 10, bottom: 10),
            child: LanguageToggleChip(compact: true),
          ),
        ],
      ),
      // SafeArea bottom — keeps the last form card clear of the
      // gesture bar / home indicator (top is handled by AppBar).
      body: SafeArea(
        top: false,
        child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('1. Parties (from verified profiles)'),
          _buildIdentityCard(),
          const SizedBox(height: 20),

          // ── Project Brief Description ─────────────────────────────
          _sectionTitle('Project Brief Description (optional)'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _projectBriefCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'e.g. 2-story house, 5 marla, grey structure + finishing with modern kitchen...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                  labelText: 'Brief description of the construction project',
                  labelStyle: const TextStyle(fontSize: 13, color: Color(0xFF5D6B64)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle('2. Payment Terms'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Project Amount',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                      Text(
                        'Rs. ${_totalAmount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    'Yeh amount aapke accepted bid se fixed hai — badla nahi ja sakta.',
                    style: TextStyle(color: Colors.grey, fontSize: 11.5),
                  ),
                  const Divider(height: 24),
                  Text(
                    'Advance Payment: ${_advancePercent.toInt()}%',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _advancePercent,
                    min: 5,
                    max: 50,
                    divisions: 9,
                    activeColor: kAmber,
                    label: '${_advancePercent.toInt()}%',
                    onChanged: (val) => setState(() => _advancePercent = val),
                  ),
                  const Text(
                    'Ye % kaam shuru hone se pehle client ko pay karna hoga.',
                    style: TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle('3. Scope of Work (auto-generated — edit as needed)'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (_projectType.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Chip(
                        label: Text('Project type: $_projectType'),
                        backgroundColor: kNavy.withValues(alpha: 0.08),
                      ),
                    ),
                  const SizedBox(height: 8),
                  ..._scopeItems.asMap().entries.map((entry) {
                    final i = entry.key;
                    final item = entry.value;
                    return CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: item.included,
                      onChanged: (v) => setState(() {
                        _scopeItems[i] = ScopeItem(
                          task: item.task,
                          description: item.description,
                          timelineDays: item.timelineDays,
                          decision: (v ?? true)
                              ? ScopeDecision.included
                              : ScopeDecision.excluded,
                          isDone: item.isDone,
                        );
                      }),
                      title: Text(item.task),
                      subtitle: item.timelineDays > 0
                          ? Text('${item.timelineDays} days')
                          : null,
                      secondary: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () =>
                            setState(() => _scopeItems.removeAt(i)),
                      ),
                    );
                  }),
                  const Divider(height: 24),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '+ Add extra task',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _taskCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Task',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _daysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Days',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.add_circle, color: kNavyLight),
                        onPressed: _addCustomScopeItem,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          _sectionTitle('4. Timeline'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(true),
                  child: Text(
                    _startDate == null
                        ? 'Start Date'
                        : '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickDate(false),
                  child: Text(
                    _endDate == null
                        ? 'End Date'
                        : '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          _sectionTitle('5. Legal Terms'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade300),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _siteAddressCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Site / Work Address',
                      helperText:
                          'Kaam kahan hoga — clear address, taake location par koi ikhtilaf na ho.',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Materials Responsibility',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Samaan/material kaun layega? Isse baad mein cost ke jhagray se bacha jata hai.',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'contractor',
                        label: Text('Contractor'),
                      ),
                      ButtonSegment(value: 'client', label: Text('Client')),
                      ButtonSegment(value: 'shared', label: Text('Shared')),
                    ],
                    selected: {_materialsResponsibility},
                    onSelectionChanged: (s) =>
                        setState(() => _materialsResponsibility = s.first),
                  ),
                  const SizedBox(height: 18),

                  const Text(
                    'Delay Penalty',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _delayPenaltyPercent == 0
                        ? 'No penalty clause — deadline miss hone par koi deduction nahi.'
                        : 'Deadline ke baad har din ${_delayPenaltyPercent.toInt()}% deduct hoga next milestone se.',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  Slider(
                    value: _delayPenaltyPercent,
                    min: 0,
                    max: 10,
                    divisions: 10,
                    activeColor: kAmber,
                    label: '${_delayPenaltyPercent.toInt()}%/day',
                    onChanged: (val) =>
                        setState(() => _delayPenaltyPercent = val),
                  ),
                  const SizedBox(height: 12),

                  const Text(
                    'Warranty / Defect-Repair Period',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Final payment ke baad $_warrantyDays din tak free repair guarantee.',
                    style: const TextStyle(fontSize: 11.5, color: Colors.grey),
                  ),
                  Slider(
                    value: _warrantyDays.toDouble(),
                    min: 0,
                    max: 30,
                    divisions: 30,
                    activeColor: kAmber,
                    label: '$_warrantyDays days',
                    onChanged: (val) =>
                        setState(() => _warrantyDays = val.round()),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kNavy,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Project Cost',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                Text(
                  'Rs. ${_totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _submitContract,
              style: ElevatedButton.styleFrom(
                backgroundColor: kAmber,
                foregroundColor: kNavy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: kNavy)
                  : const Text(
                      'Create & Send for Signing',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Read-only identity card — shows what was fetched from Firestore, and
  // a clear warning (not an editable field!) when something's missing.
  // ---------------------------------------------------------------------
  Widget _buildIdentityCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CLIENT',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _readOnlyRow('Name', widget.clientName),
            _readOnlyRow('CNIC', _clientCnic.isEmpty ? '—' : _clientCnic),
            _readOnlyRow('Phone', _clientPhone.isEmpty ? '—' : _clientPhone),
            _readOnlyRow(
              'Area / City',
              [
                    _clientArea,
                    _clientCity,
                  ].where((e) => e.isNotEmpty).join(', ').isEmpty
                  ? '—'
                  : [
                      _clientArea,
                      _clientCity,
                    ].where((e) => e.isNotEmpty).join(', '),
            ),
            if (_clientCnicMissing || _clientLocationMissing) _profileWarning(),
            const Divider(height: 28),

            const Text(
              'CONTRACTOR',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(height: 6),
            _readOnlyRow('Name', widget.contractorName),
            _readOnlyRow(
              'CNIC',
              _contractorCnic.isEmpty ? '—' : _contractorCnic,
            ),
            _readOnlyRow(
              'Phone',
              _contractorPhone.isEmpty ? '—' : _contractorPhone,
            ),
            _readOnlyRow(
              'City',
              _contractorCity.isEmpty ? '—' : _contractorCity,
            ),
            if (_contractorCnicMissing) _profileWarning(isContractor: true),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 12.5),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );

  Widget _profileWarning({bool isContractor = false}) => Container(
    margin: const EdgeInsets.only(top: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: kDanger.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.warning_amber_rounded, color: kDanger, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            isContractor
                ? 'Contractor ka profile incomplete hai — unhein CNIC upload karne ke liye bolein.'
                : 'Apna area/city aur CNIC profile mein complete karein — is ke baghair contract nahi ban sakta.',
            style: const TextStyle(color: kDanger, fontSize: 11.5),
          ),
        ),
      ],
    ),
  );

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: kNavy,
      ),
    ),
  );
}

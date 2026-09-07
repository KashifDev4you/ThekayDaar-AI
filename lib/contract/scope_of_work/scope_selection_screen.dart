// scope_selection_screen.dart
// Contract creation stage par dikhta hai. Har item ka decision
// lena MANDATORY hai — "Generate Contract" button tab tak disabled
// rehta hai jab tak har item Included/Excluded/Client-Material
// mark na ho jaye.

import 'package:flutter/material.dart';
import 'scope_templates.dart';
import 'package:ali_app/model/contract_model.dart';

const Color kNavy = Color(0xFF0E3B2E);
const Color kAmber = Color(0xFFC9A227);

class ScopeSelectionScreen extends StatefulWidget {
  final List<String> selectedCategories; // e.g. ['Tile & Marble Work']
  final void Function(List<ScopeItem> finalizedScope) onConfirm;

  const ScopeSelectionScreen({
    super.key,
    required this.selectedCategories,
    required this.onConfirm,
  });

  @override
  State<ScopeSelectionScreen> createState() => _ScopeSelectionScreenState();
}

class _ScopeSelectionScreenState extends State<ScopeSelectionScreen> {
  late List<ScopeItem> _items;

  @override
  void initState() {
    super.initState();
    _items = widget.selectedCategories
        .expand((cat) => scopeCategoryTemplates[cat] ?? [])
        .map(
          (t) => ScopeItem(
            id: t.id,
            task: t.label,
            category: t.category,
            decision: ScopeDecision.undecided,
          ),
        )
        .toList();
  }

  bool get _allDecided =>
      _items.every((i) => i.decision != ScopeDecision.undecided);

  void _setDecision(ScopeItem item, ScopeDecision d) {
    setState(() => item.decision = d);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <String, List<ScopeItem>>{};
    for (final item in _items) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scope of Work — Har Item Decide Karein'),
        backgroundColor: kNavy,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: const Color(0xFFFBF6E3),
            padding: const EdgeInsets.all(12),
            child: const Text(
              'Har item ke liye batayein: ye kaam Thekaydaar karega, nahi karega, '
              'ya sirf material client dega. Koi item chhoड़ना allowed nahi — '
              'isse future mein "ye mera duty nahi tha" wala dispute nahi hoga.',
              style: TextStyle(fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: grouped.entries.map((entry) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: kNavy,
                          ),
                        ),
                        const Divider(),
                        ...entry.value.map((item) => _itemRow(item)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _allDecided
                    ? () => widget.onConfirm(_items)
                    : null, // Locked until every item is decided
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAmber,
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  _allDecided
                      ? 'Contract Generate Karein'
                      : 'Pehle sab items decide karein '
                            '(${_items.where((i) => i.decision == ScopeDecision.undecided).length} baaki)',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: kNavy,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemRow(ScopeItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.task, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Included'),
                selected: item.decision == ScopeDecision.included,
                selectedColor: const Color(0xFFD1FAE5),
                onSelected: (_) => _setDecision(item, ScopeDecision.included),
              ),
              ChoiceChip(
                label: const Text('Excluded'),
                selected: item.decision == ScopeDecision.excluded,
                selectedColor: Colors.red.shade100,
                onSelected: (_) => _setDecision(item, ScopeDecision.excluded),
              ),
              ChoiceChip(
                label: const Text('Client Material Only'),
                selected: item.decision == ScopeDecision.clientMaterial,
                selectedColor: const Color(0xFFE7F2ED),
                onSelected: (_) =>
                    _setDecision(item, ScopeDecision.clientMaterial),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

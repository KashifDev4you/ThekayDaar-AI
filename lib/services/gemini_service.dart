import 'dart:convert';

import 'package:http/http.dart' as http;

import 'gemini_config.dart';

/// One line item in an AI cost estimate (e.g. "Grey structure — 2400000").
class AiMaterialItem {
  const AiMaterialItem({required this.item, required this.cost});

  final String item;
  final int cost; // PKR
}

/// Structured result of an AI cost estimation.
class AiCostEstimate {
  const AiCostEstimate({
    required this.budgetMin,
    required this.budgetMax,
    required this.durationDays,
    required this.materials,
    required this.notes,
  });

  final int budgetMin; // PKR
  final int budgetMax; // PKR
  final int durationDays;
  final List<AiMaterialItem> materials;
  final String notes;
}

/// One material in a detailed construction material estimate.
class MaterialQuantity {
  const MaterialQuantity({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.estimatedCost,
    required this.topBrands,
    required this.tip,
  });

  final String name; // e.g. "Bricks (Awwal)"
  final String quantity; // e.g. "45,000"
  final String unit; // e.g. "pieces"
  final int estimatedCost; // PKR
  final List<String> topBrands; // e.g. ["Lucky Cement", "DG Cement"]
  final String tip; // strength/quality tip
}

/// Complete material estimation result from AI.
class MaterialEstimate {
  const MaterialEstimate({
    required this.totalCostMin,
    required this.totalCostMax,
    required this.materials,
    required this.summary,
    required this.strengthTips,
  });

  final int totalCostMin; // PKR
  final int totalCostMax; // PKR
  final List<MaterialQuantity> materials;
  final String summary; // short overview
  final List<String> strengthTips; // general tips for stronger house
}

/// AI match result for a single contractor against a project.
class AiContractorMatch {
  const AiContractorMatch({
    required this.contractorId,
    required this.score,
    required this.reason,
  });

  final String contractorId;
  final int score; // 0-100
  final String reason;
}

class GeminiService {
  GeminiService._();

  static bool get isConfigured {
    final key = GeminiConfig.apiKey;
    return key.isNotEmpty && !key.startsWith('PASTE_');
  }

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  // ── Low-level generateContent call ───────────────────────
  static Future<String> _generateText(
    String prompt, {
    double temperature = 0.4,
    int maxOutputTokens = 2048,
  }) async {
    if (!isConfigured) {
      throw Exception(
        'Gemini API key missing — paste it in lib/services/gemini_config.dart',
      );
    }

    final uri = Uri.parse(
      '$_baseUrl/${GeminiConfig.model}:generateContent?key=${GeminiConfig.apiKey}',
    );

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
            'generationConfig': {
              'temperature': temperature,
              'maxOutputTokens': maxOutputTokens,
            },
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode != 200) {
      throw Exception('Gemini API error ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw Exception('Gemini returned no response');
    }
    final parts = (candidates.first['content']['parts'] as List)
        .map((p) => (p as Map)['text'] ?? '')
        .join();
    if (parts.trim().isEmpty) {
      throw Exception('Gemini returned an empty response');
    }
    return parts;
  }

  // ── JSON helper (strips ```json fences etc.) ─────────────
  static Map<String, dynamic> _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(json)?'), '').trim();
      final fenceEnd = text.lastIndexOf('```');
      if (fenceEnd != -1) text = text.substring(0, fenceEnd);
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) {
      throw Exception('Could not parse AI response');
    }
    return jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
  }

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  // ── Feature 1: Project cost estimator ────────────────────
  static Future<AiCostEstimate> estimateProjectCost({
    required String projectType,
    required String city,
    String? plotSize,
    String? plotSizeUnit,
    String? description,
    List<String> services = const [],
  }) async {
    final plot = (plotSize != null && plotSize.trim().isNotEmpty)
        ? '$plotSize ${plotSizeUnit ?? ''}'.trim()
        : 'not specified';

    final prompt = '''
You are a senior construction cost estimator working in Pakistan.

Estimate this construction project:
- Project type: $projectType
- City: $city
- Plot size: $plot
- Services needed: ${services.isEmpty ? 'standard scope' : services.join(', ')}
- Client description: ${description ?? 'none'}

Use realistic current Pakistani market rates (cement, awwal bricks, steel, sand, labour, etc.) and answer ONLY with valid JSON in exactly this shape:
{"budget_min": <int in PKR>, "budget_max": <int in PKR>, "duration_days": <int>, "materials": [{"item": "<string>", "cost": <int in PKR>}], "notes": "<one short sentence>"}

Rules:
- Give 4 to 6 material/phase line items whose costs sum near the middle of your range.
- notes must be under 20 words.
- No text outside the JSON.''';

    final raw = await _generateText(prompt, temperature: 0.2);
    final json = _extractJson(raw);

    final materials = (json['materials'] as List? ?? [])
        .map(
          (m) => AiMaterialItem(
            item: '${(m as Map)['item']}',
            cost: _asInt(m['cost']),
          ),
        )
        .toList();

    return AiCostEstimate(
      budgetMin: _asInt(json['budget_min']),
      budgetMax: _asInt(json['budget_max']),
      durationDays: _asInt(json['duration_days']),
      materials: materials,
      notes: '${json['notes']}',
    );
  }

  // ── Feature 2: Description suggestion generator ──────────
  static Future<List<String>> generateDescriptionSuggestions({
    required String projectType,
    String? city,
    String? plotSize,
    String? plotSizeUnit,
    List<String> services = const [],
  }) async {
    final plot = (plotSize != null && plotSize.trim().isNotEmpty)
        ? '$plotSize ${plotSizeUnit ?? ''}'.trim()
        : null;

    final prompt = '''
You write clear project descriptions for Pakistani clients posting construction jobs on a hiring platform.

Project details:
- Type: $projectType
- City: ${city ?? 'not specified'}
- Plot size: ${plot ?? 'not specified'}
- Services: ${services.isEmpty ? 'standard scope' : services.join(', ')}

Write 3 description suggestions. Each must be under 30 words, simple English a homeowner would use, and mention the plot size only if known.

Answer ONLY with valid JSON: {"suggestions": ["<s1>", "<s2>", "<s3>"]}''';

    final raw = await _generateText(prompt, temperature: 0.8);
    final json = _extractJson(raw);
    final list = (json['suggestions'] as List? ?? [])
        .map((s) => '$s')
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (list.isEmpty) throw Exception('No suggestions generated');
    return list;
  }

  // ── Feature 3: Contractor-to-project matching ─────────────
  static Future<List<AiContractorMatch>> rankContractors({
    required String projectNeed,
    required String city,
    required List<Map<String, dynamic>> contractors,
  }) async {
    if (contractors.isEmpty) return [];

    final contractorList = contractors.map((c) {
      final skills = (c['skills'] as List? ?? []).join(', ');
      return {
        'id': '${c['id']}',
        'name': '${c['fullName'] ?? 'Contractor'}',
        'skills': skills,
        'rating': c['rating'] ?? 0,
        'city': '${c['city'] ?? ''}',
        'area': '${c['area'] ?? ''}',
      };
    }).toList();

    final prompt =
        "You are the matching engine for Thekaydaar.pk, a Pakistani construction marketplace.\n\n"
        "Project need: $projectNeed\n"
        "Client city: $city\n\n"
        "Contractors:\n"
        "${jsonEncode(contractorList)}\n\n"
        "Rank the TOP 5 best-matching contractors. Consider:\n"
        "- Skills directly relevant to the project need\n"
        "- Higher rating is better\n"
        "- Same city/area is a plus but not required\n"
        "- Give extra weight to specialists over generalists\n\n"
        "Return ONLY valid JSON in this exact shape:\n"
        r'{"matches": [{"contractorId": "<id>", "score": <int 0-100>, "reason": "<one short sentence>"}]}' "\n\n"
        "Rules:\n"
        "- score must be between 0 and 100.\n"
        "- reason must be under 15 words.\n"
        "- Only return contractors from the list provided.\n"
        "- No text outside the JSON.";

    final raw = await _generateText(prompt, temperature: 0.3);
    final json = _extractJson(raw);
    final matches = (json['matches'] as List? ?? [])
        .map(
          (m) => AiContractorMatch(
            contractorId: '${(m as Map)['contractorId']}',
            score: _asInt(m['score']).clamp(0, 100),
            reason: '${m['reason']}',
          ),
        )
        .toList();
    return matches;
  }

  // ── Feature 4: AI support chatbot ────────────────────────
  static Future<String> answerSupport(String question) async {
    final prompt =
        "You are a friendly, concise support assistant for Thekaydaar.pk, a Pakistani construction marketplace app.\n\n"
        "The app has three roles:\n"
        "- Client / Maalik: posts construction projects, hires contractors, pays for work.\n"
        r'- Contractor / Thekaydaar: finds projects, places bids using "Connects", gets hired, completes work.' "\n"
        "- Admin: manages the platform, handles disputes, passcodes, and payouts.\n\n"
        "Key concepts:\n"
        "- Connects: virtual credits contractors spend to bid on projects.\n"
        "- Contracts: created after a client accepts a bid; includes scope of work and payment terms.\n"
        "- Bidding: contractors submit price and timeline for a project.\n"
        "- Reviews: clients rate contractors after job completion.\n\n"
        "Answer the user's question in simple English or Roman Urdu if they asked in Urdu. Keep it under 60 words. If you don't know, suggest contacting support through the Help & Support screen.\n\n"
        "User question: $question";

    return _generateText(prompt, temperature: 0.4);
  }

  // ── Feature 6: Detailed material estimator ──────────────
  static Future<MaterialEstimate> estimateMaterials({
    required String plotSize,
    required String plotSizeUnit,
    required int stories,
    required String wallMaterial,
    required String finishingLevel,
    String tileType = 'Ceramic',
    String paintPreference = 'Standard Colors',
    String city = 'Lahore',
  }) async {
    final prompt = '''
You are a senior Pakistani civil engineer. Calculate material quantities for:
- Plot: $plotSize $plotSizeUnit, Stories: $stories, City: $city
- Wall material: $wallMaterial
- Finishing level: $finishingLevel
- Floor tile preference: $tileType
- Paint preference: $paintPreference

Return ONLY valid JSON (no markdown, no extra text):
{"total_cost_min":<int>,"total_cost_max":<int>,"summary":"<20 words>","materials":[{"name":"<string>","quantity":"<number>","unit":"<unit>","estimated_cost":<int>,"top_brands":["<b1>","<b2>"],"tip":"<10 words>"}],"strength_tips":["<t1>","<t2>","<t3>"]}

Rules: 8 materials max. Include tiles and paint as separate line items matching the user preferences. Use real Pakistani brands (Lucky, DG, Fauji, Amreli, FF Steel, Master Paint, Diamond, Gori). Current PKR rates. 3 strength tips. Keep every field SHORT.''';

    final raw = await _generateText(
      prompt,
      temperature: 0.25,
      maxOutputTokens: 4096,
    );
    final json = _extractJson(raw);

    final materials = (json['materials'] as List? ?? [])
        .map(
          (m) => MaterialQuantity(
            name: '${(m as Map)['name']}',
            quantity: '${m['quantity']}',
            unit: '${m['unit']}',
            estimatedCost: _asInt(m['estimated_cost']),
            topBrands: ((m['top_brands'] as List?) ?? [])
                .map((b) => '$b')
                .toList(),
            tip: '${m['tip']}',
          ),
        )
        .toList();

    final strengthTips = (json['strength_tips'] as List? ?? [])
        .map((t) => '$t')
        .where((t) => t.trim().isNotEmpty)
        .toList();

    return MaterialEstimate(
      totalCostMin: _asInt(json['total_cost_min']),
      totalCostMax: _asInt(json['total_cost_max']),
      materials: materials,
      summary: '${json['summary']}',
      strengthTips: strengthTips,
    );
  }

  // ── Feature 5: Smart chat replies ────────────────────────
  static Future<List<String>> suggestChatReplies({
    required List<String> recentMessageLines,
    required String otherPartyName,
  }) async {
    if (recentMessageLines.isEmpty) {
      throw Exception('No messages to reply to');
    }

    final context = recentMessageLines.take(6).join('\n');

    final prompt =
        "You are helping a user reply in a polite, professional chat on Thekaydaar.pk, a Pakistani construction marketplace.\n\n"
        "Recent conversation:\n"
        "$context\n\n"
        "The user is replying to $otherPartyName.\n"
        "Suggest 3 short reply options in simple English. Each should feel natural and helpful. Keep each under 12 words.\n\n"
        r'Answer ONLY with valid JSON: {"replies": ["<r1>", "<r2>", "<r3>"]}';

    final raw = await _generateText(prompt, temperature: 0.7);
    final json = _extractJson(raw);
    final list = (json['replies'] as List? ?? [])
        .map((r) => '$r')
        .where((r) => r.trim().isNotEmpty)
        .toList();
    if (list.isEmpty) throw Exception('No replies generated');
    return list;
  }

  // ── Feature: AI House Planner (structured floor plan) ────
  /// Asks Gemini to lay out rooms for the given plot and returns the
  /// RAW JSON in the house-plan schema (the caller validates and repairs
  /// it via HousePlan.fromJson — an AI image is never the source of truth).
  ///
  /// Throws when the API is unavailable or the response cannot be parsed;
  /// callers fall back to the local rule-based planner.
  static Future<Map<String, dynamic>> generateHousePlanLayout({
    required double plotWidth,
    required double plotLength,
    required String unit,
    required List<int> floors,
    required List<Map<String, dynamic>> requirements,
  }) async {
    final reqLines = requirements
        .map((r) =>
            '- ${r['name'] ?? r['type']}: quantity ${r['quantity'] ?? 1}, '
            'min size ${r['minWidth'] ?? 'any'} x ${r['minLength'] ?? 'any'} $unit, '
            'preferred floor ${r['floorPref'] ?? 'auto'}'
            '${r['attachedBathroom'] == true ? ', needs attached bathroom' : ''}')
        .join('\n');

    final prompt = '''
You are a senior Pakistani residential architect designing a house floor plan.

Plot: $plotWidth x $plotLength $unit (width x length).
Floors to design (-1 = basement, 0 = ground, 1 = first, 2 = second): ${floors.join(', ')}.

Room requirements:
$reqLines

Layout rules:
- Coordinates: x measured from the LEFT (west) wall, y from the BACK (north) wall, in $unit.
- Rooms must NOT overlap and must fit inside the plot rectangle.
- Use realistic Pakistani layouts: car porch at the front, staircase in a side strip, kitchen and lounge on the ground floor, bedrooms upstairs.
- Give every room at least one door (wall: "n"/"s"/"e"/"w" + offset + width) and windows on exterior walls.
- Room types use snake_case (master_bedroom, bedroom, bathroom, kitchen, tv_lounge, drawing_room, dining_room, car_parking, staircase, etc.).

Return ONLY valid JSON in EXACTLY this shape (no markdown, no comments, no text outside the JSON):
{"plot":{"width":$plotWidth,"length":$plotLength,"unit":"$unit"},"floors":[{"floor":0,"rooms":[{"id":"room_001","type":"master_bedroom","name":"Master Bedroom","x":0,"y":0,"width":14,"length":16,"floor":0,"doors":[{"wall":"n","offset":7,"width":3}],"windows":[{"wall":"w","offset":8,"width":4}]}]}]}''';

    final raw = await _generateText(
      prompt,
      temperature: 0.2,
      maxOutputTokens: 8192,
    );
    return _extractJson(raw);
  }
}

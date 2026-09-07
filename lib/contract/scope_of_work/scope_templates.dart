// scope_templates.dart
// Har project type ka pre-built, exhaustive scope checklist.
// Maqsad: koi bhi kaam "assume" na ho — har item explicitly
// Included / Excluded / Client-Material mark hona chahiye.

enum ScopeDecision { undecided, included, excluded, clientMaterial }

class ScopeTemplateItem {
  final String id;
  final String label;
  final String category; // e.g. "Tile & Marble Work"
  final String? hint; // clarification jo UI mein dikhegi

  const ScopeTemplateItem({
    required this.id,
    required this.label,
    required this.category,
    this.hint,
  });
}

// Project type => list of scope items relevant to that type.
// Ek project multiple categories cover kar sakta hai (e.g. "Full House
// Construction" mein Tile + Electrical + Plumbing + Paint sab aayenge).
final Map<String, List<ScopeTemplateItem>> scopeCategoryTemplates = {
  'Tile & Marble Work': [
    ScopeTemplateItem(
      id: 'floor_tiles',
      label: 'Floor tiles (all rooms)',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'bathroom_tiles',
      label: 'Bathroom wall + floor tiles',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'kitchen_tiles',
      label: 'Kitchen wall + counter tiles',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'staircase_tiles',
      label: 'Staircase tiles',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'front_elevation_tiles',
      label: 'Front elevation tiles/cladding',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'boundary_wall_tiles',
      label: 'Boundary wall tiles/cladding',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'balcony_terrace_tiles',
      label: 'Balcony/terrace tiles',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'old_tile_removal',
      label: 'Old tile/marble removal & disposal',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'grouting_finishing',
      label: 'Tile joints/grouting finishing',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'skirting',
      label: 'Skirting tiles',
      category: 'Tile & Marble Work',
    ),
    ScopeTemplateItem(
      id: 'wastage_responsibility',
      label: 'Cutting wastage — responsibility',
      category: 'Tile & Marble Work',
      hint: 'Kis ki zimmedari hogi agar tile cutting mein wastage ho',
    ),
    ScopeTemplateItem(
      id: 'material_transport_tile',
      label: 'Material transport to site',
      category: 'Tile & Marble Work',
    ),
  ],
  'Electrical Work': [
    ScopeTemplateItem(
      id: 'wiring_conduit',
      label: 'Wiring & conduit fitting (concealed)',
      category: 'Electrical Work',
    ),
    ScopeTemplateItem(
      id: 'switchboards',
      label: 'Switchboards & sockets installation',
      category: 'Electrical Work',
    ),
    ScopeTemplateItem(
      id: 'db_panel',
      label: 'Distribution board / MCB panel',
      category: 'Electrical Work',
    ),
    ScopeTemplateItem(
      id: 'earthing',
      label: 'Earthing system',
      category: 'Electrical Work',
    ),
    ScopeTemplateItem(
      id: 'fan_light_fitting',
      label: 'Fan & light fixture installation',
      category: 'Electrical Work',
    ),
    ScopeTemplateItem(
      id: 'ac_wiring',
      label: 'AC point wiring',
      category: 'Electrical Work',
    ),
    ScopeTemplateItem(
      id: 'generator_ups_wiring',
      label: 'Generator/UPS changeover wiring',
      category: 'Electrical Work',
    ),
    ScopeTemplateItem(
      id: 'outdoor_wiring',
      label: 'Outdoor/garden lighting wiring',
      category: 'Electrical Work',
    ),
    ScopeTemplateItem(
      id: 'material_supply_electrical',
      label: 'Wire/switch material supply',
      category: 'Electrical Work',
    ),
  ],
  'Plumbing Work': [
    ScopeTemplateItem(
      id: 'water_supply_lines',
      label: 'Water supply lines (all floors)',
      category: 'Plumbing Work',
    ),
    ScopeTemplateItem(
      id: 'drainage_sewerage',
      label: 'Drainage & sewerage lines',
      category: 'Plumbing Work',
    ),
    ScopeTemplateItem(
      id: 'bathroom_fittings',
      label: 'Bathroom fittings (taps, shower, commode)',
      category: 'Plumbing Work',
    ),
    ScopeTemplateItem(
      id: 'kitchen_plumbing',
      label: 'Kitchen sink plumbing',
      category: 'Plumbing Work',
    ),
    ScopeTemplateItem(
      id: 'water_tank_connection',
      label: 'Water tank/motor connection',
      category: 'Plumbing Work',
    ),
    ScopeTemplateItem(
      id: 'geyser_connection',
      label: 'Geyser installation/connection',
      category: 'Plumbing Work',
    ),
    ScopeTemplateItem(
      id: 'rainwater_pipes',
      label: 'Rainwater/roof drain pipes',
      category: 'Plumbing Work',
    ),
    ScopeTemplateItem(
      id: 'material_supply_plumbing',
      label: 'Pipe/fitting material supply',
      category: 'Plumbing Work',
    ),
  ],
  'Paint & Finishing': [
    ScopeTemplateItem(
      id: 'interior_paint',
      label: 'Interior wall paint (all rooms)',
      category: 'Paint & Finishing',
    ),
    ScopeTemplateItem(
      id: 'exterior_paint',
      label: 'Exterior/facade paint',
      category: 'Paint & Finishing',
    ),
    ScopeTemplateItem(
      id: 'ceiling_paint',
      label: 'Ceiling paint/POP finishing',
      category: 'Paint & Finishing',
    ),
    ScopeTemplateItem(
      id: 'putty_primer',
      label: 'Wall putty & primer',
      category: 'Paint & Finishing',
    ),
    ScopeTemplateItem(
      id: 'gate_grill_paint',
      label: 'Gate/grill/railing paint',
      category: 'Paint & Finishing',
    ),
    ScopeTemplateItem(
      id: 'texture_wallpaper',
      label: 'Texture paint/wallpaper (if any)',
      category: 'Paint & Finishing',
    ),
    ScopeTemplateItem(
      id: 'material_supply_paint',
      label: 'Paint material supply',
      category: 'Paint & Finishing',
    ),
  ],
  'Construction / Structure': [
    ScopeTemplateItem(
      id: 'foundation',
      label: 'Foundation work',
      category: 'Construction / Structure',
    ),
    ScopeTemplateItem(
      id: 'brickwork',
      label: 'Brick/block masonry work',
      category: 'Construction / Structure',
    ),
    ScopeTemplateItem(
      id: 'rcc_slab',
      label: 'RCC slab/roof casting',
      category: 'Construction / Structure',
    ),
    ScopeTemplateItem(
      id: 'plastering',
      label: 'Internal/external plastering',
      category: 'Construction / Structure',
    ),
    ScopeTemplateItem(
      id: 'boundary_wall',
      label: 'Boundary wall construction',
      category: 'Construction / Structure',
    ),
    ScopeTemplateItem(
      id: 'staircase_structure',
      label: 'Staircase structure',
      category: 'Construction / Structure',
    ),
    ScopeTemplateItem(
      id: 'waterproofing',
      label: 'Roof/bathroom waterproofing',
      category: 'Construction / Structure',
    ),
    ScopeTemplateItem(
      id: 'debris_removal',
      label: 'Construction debris removal',
      category: 'Construction / Structure',
    ),
  ],
  'Woodwork / Carpentry': [
    ScopeTemplateItem(
      id: 'main_door',
      label: 'Main door + frame',
      category: 'Woodwork / Carpentry',
    ),
    ScopeTemplateItem(
      id: 'room_doors',
      label: 'Room doors + frames',
      category: 'Woodwork / Carpentry',
    ),
    ScopeTemplateItem(
      id: 'wardrobes',
      label: 'Wardrobes/cabinets',
      category: 'Woodwork / Carpentry',
    ),
    ScopeTemplateItem(
      id: 'kitchen_cabinets',
      label: 'Kitchen cabinets',
      category: 'Woodwork / Carpentry',
    ),
    ScopeTemplateItem(
      id: 'false_ceiling',
      label: 'False ceiling (wood/gypsum)',
      category: 'Woodwork / Carpentry',
    ),
    ScopeTemplateItem(
      id: 'material_supply_wood',
      label: 'Wood/hardware material supply',
      category: 'Woodwork / Carpentry',
    ),
  ],
};

// Har category ke against Thekaydaar-specific requirements bhi
// structured hone chahiye — free text nahi, taake dispute mein
// "maine bola tha" wala confusion na ho.
class ThekaydaarRequirementTemplate {
  final String id;
  final String label;
  const ThekaydaarRequirementTemplate({required this.id, required this.label});
}

final List<ThekaydaarRequirementTemplate> thekaydaarRequirementTemplates = [
  ThekaydaarRequirementTemplate(
    id: 'advance_percent',
    label: 'Advance payment % required before start',
  ),
  ThekaydaarRequirementTemplate(
    id: 'water_electricity',
    label: 'Site par paani/bijli available honi chahiye',
  ),
  ThekaydaarRequirementTemplate(
    id: 'working_hours',
    label: 'Working hours (e.g. 8am–6pm)',
  ),
  ThekaydaarRequirementTemplate(
    id: 'material_storage',
    label: 'Material storage/security ki zimmedari',
  ),
  ThekaydaarRequirementTemplate(
    id: 'cleanup_debris',
    label: 'Daily cleanup / debris removal zimmedari',
  ),
  ThekaydaarRequirementTemplate(
    id: 'delay_penalty',
    label: 'Timeline miss hone par penalty clause',
  ),
  ThekaydaarRequirementTemplate(
    id: 'warranty_period',
    label: 'Warranty period (days) is kaam ke liye',
  ),
  ThekaydaarRequirementTemplate(
    id: 'labour_accommodation',
    label: 'Labour accommodation/transport zimmedari',
  ),
];

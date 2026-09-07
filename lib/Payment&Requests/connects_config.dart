// =============================================================================
// connects_config.dart
// Central config for plans, connects costs, package pricing, and feature
// gating. Import this wherever you need plan/connects/feature-access logic.
// =============================================================================

class ThekaydaarPlans {
  ThekaydaarPlans._();

  // ── Platform commission on every completed project ─────────────────────
  static const double commissionRate = 0.025; // 2.5 %

  // ── Plan definitions (contractor / Thekaydaar side) ──────────────────
  static const Map<String, PlanConfig> plans = {
    'Free': PlanConfig(
      name                    : 'Free',
      monthlyConnects         : 0,
      priceMonthly            : 0,
      badge                   : '🔓',
      description             : 'Browse projects only. Upgrade to start bidding and unlock features.',
      // Access flags
      canBid                  : false,
      canViewProjects         : true,
      profileVisible          : false,
      canPostGig              : false,
      canUseAiTools           : false,
      canUseMaterialEstimator : false,
      canAccessChat           : false,
      canViewAnalytics        : false,
      prioritySupport         : false,
      featuredListing         : false,
      verifiedBadge           : false,
      bidsAllowed             : 0,
    ),
    'Pro': PlanConfig(
      name                    : 'Pro',
      monthlyConnects         : 10,
      priceMonthly            : 999,
      badge                   : '⚡',
      description             : '10 bids/mo. Direct messaging, contract system, verified profile.',
      // Access flags
      canBid                  : true,
      canViewProjects         : true,
      profileVisible          : true,
      canPostGig              : true,
      canUseAiTools           : false,
      canUseMaterialEstimator : false,
      canAccessChat           : true,
      canViewAnalytics        : false,
      prioritySupport         : false,
      featuredListing         : false,
      verifiedBadge           : true,
      bidsAllowed             : 10,
    ),
    'Elite': PlanConfig(
      name                    : 'Elite',
      monthlyConnects         : 20,
      priceMonthly            : 2499,
      badge                   : '🚀',
      description             : '20 bids/mo. AI tools, material estimator, priority search, analytics.',
      // Access flags
      canBid                  : true,
      canViewProjects         : true,
      profileVisible          : true,
      canPostGig              : true,
      canUseAiTools           : true,
      canUseMaterialEstimator : true,
      canAccessChat           : true,
      canViewAnalytics        : true,
      prioritySupport         : true,
      featuredListing         : true,
      verifiedBadge           : true,
      bidsAllowed             : 20,
    ),
    'Business': PlanConfig(
      name                    : 'Business',
      monthlyConnects         : 40,
      priceMonthly            : 3999,
      badge                   : '💼',
      description             : '40 bids/mo. All features unlocked. Featured badge + priority support.',
      // Access flags
      canBid                  : true,
      canViewProjects         : true,
      profileVisible          : true,
      canPostGig              : true,
      canUseAiTools           : true,
      canUseMaterialEstimator : true,
      canAccessChat           : true,
      canViewAnalytics        : true,
      prioritySupport         : true,
      featuredListing         : true,
      verifiedBadge           : true,
      bidsAllowed             : 40,
    ),
  };

  // ── Client plan definitions ───────────────────────────────────────────
  static const Map<String, ClientPlanConfig> clientPlans = {
    'Free': ClientPlanConfig(
      name                : 'Free',
      priceMonthly        : 0,
      badge               : '🔓',
      description         : '1 project post/mo. View up to 5 bids. Basic listing.',
      projectPostsAllowed : 1,
      bidsViewLimit       : 5,
      verifiedBadge       : false,
      featuredListing     : false,
      canAccessChat       : false,
      canUseAiTools       : false,
      prioritySupport     : false,
    ),
    'Standard': ClientPlanConfig(
      name                : 'Standard',
      priceMonthly        : 499,
      badge               : '⚡',
      description         : '5 posts/mo. All bids visible. Priority placement. Direct messaging.',
      projectPostsAllowed : 5,
      bidsViewLimit       : 999,
      verifiedBadge       : false,
      featuredListing     : false,
      canAccessChat       : true,
      canUseAiTools       : false,
      prioritySupport     : false,
    ),
    'Premium': ClientPlanConfig(
      name                : 'Premium',
      priceMonthly        : 1499,
      badge               : '🚀',
      description         : 'Unlimited posts. Verified badge. Featured in search. AI tools. Priority support.',
      projectPostsAllowed : 999,
      bidsViewLimit       : 999,
      verifiedBadge       : true,
      featuredListing     : true,
      canAccessChat       : true,
      canUseAiTools       : true,
      prioritySupport     : true,
    ),
  };

  // ── Connects cost per bid by budget range ─────────────────────────────
  static int bidCost(String budgetMin, String budgetMax) {
    final max = int.tryParse(
            budgetMax.replaceAll(RegExp(r'[^0-9]'), '')) ??
        0;
    if (max <= 10000) return 1;  // small project
    if (max <= 50000) return 2;  // medium project
    return 3;                    // large project
  }

  // ── Connect packages for purchase ─────────────────────────────────────
  static const List<ConnectPackage> packages = [
    ConnectPackage(id: 'pkg_10',  connects: 10,  priceRs: 299,  label: '10 Connects'),
    ConnectPackage(id: 'pkg_20',  connects: 20,  priceRs: 549,  label: '20 Connects'),
    ConnectPackage(id: 'pkg_40',  connects: 40,  priceRs: 999,  label: '40 Connects'),
    ConnectPackage(id: 'pkg_80',  connects: 80,  priceRs: 1799, label: '80 Connects'),
    ConnectPackage(id: 'pkg_150', connects: 150, priceRs: 2999, label: '150 Connects'),
  ];

  // ── Utility: get contractor plan config ───────────────────────────────
  static PlanConfig getContractorPlan(String planName) =>
      plans[planName] ?? plans['Free']!;

  // ── Utility: get client plan config ───────────────────────────────────
  static ClientPlanConfig getClientPlan(String planName) =>
      clientPlans[planName] ?? clientPlans['Free']!;

  // ── Feature-gating helper for contractor plans ─────────────────────────
  static bool canAccessFeature(String planName, String feature) {
    final plan = plans[planName];
    if (plan == null) return false;
    switch (feature) {
      case 'bid':              return plan.canBid;
      case 'viewProjects':     return plan.canViewProjects;
      case 'profileVisible':   return plan.profileVisible;
      case 'postGig':          return plan.canPostGig;
      case 'aiTools':          return plan.canUseAiTools;
      case 'materialEstimator': return plan.canUseMaterialEstimator;
      case 'chat':             return plan.canAccessChat;
      case 'analytics':        return plan.canViewAnalytics;
      case 'prioritySupport':  return plan.prioritySupport;
      case 'featuredListing':  return plan.featuredListing;
      case 'verifiedBadge':    return plan.verifiedBadge;
      default:                 return false;
    }
  }

  // ── Feature-gating helper for client plans ────────────────────────────
  static bool canClientAccess(String planName, String feature) {
    final plan = clientPlans[planName];
    if (plan == null) return false;
    switch (feature) {
      case 'chat':             return plan.canAccessChat;
      case 'aiTools':          return plan.canUseAiTools;
      case 'verifiedBadge':    return plan.verifiedBadge;
      case 'featuredListing':  return plan.featuredListing;
      case 'prioritySupport':  return plan.prioritySupport;
      default:                 return false;
    }
  }
}

// ── Contractor Plan config model ──────────────────────────────────────────
class PlanConfig {
  final String  name;
  final int     monthlyConnects;
  final int     priceMonthly;      // in PKR
  final String  badge;
  final String  description;

  // Feature flags
  final bool    canBid;
  final bool    canViewProjects;
  final bool    profileVisible;
  final bool    canPostGig;
  final bool    canUseAiTools;
  final bool    canUseMaterialEstimator;
  final bool    canAccessChat;
  final bool    canViewAnalytics;
  final bool    prioritySupport;
  final bool    featuredListing;
  final bool    verifiedBadge;
  final int     bidsAllowed;

  const PlanConfig({
    required this.name,
    required this.monthlyConnects,
    required this.priceMonthly,
    required this.badge,
    required this.description,
    required this.canBid,
    required this.canViewProjects,
    required this.profileVisible,
    required this.canPostGig,
    required this.canUseAiTools,
    required this.canUseMaterialEstimator,
    required this.canAccessChat,
    required this.canViewAnalytics,
    required this.prioritySupport,
    required this.featuredListing,
    required this.verifiedBadge,
    required this.bidsAllowed,
  });

  /// Returns a human-readable list of features this plan unlocks.
  List<String> get featureList {
    final list = <String>[];
    if (monthlyConnects > 0) list.add('$monthlyConnects connects/month');
    if (canBid) list.add('Bid on projects');
    if (canPostGig) list.add('Post gig & public profile');
    if (canAccessChat) list.add('Direct client messaging');
    if (canUseAiTools) list.add('AI Material Estimator');
    if (canUseMaterialEstimator) list.add('Smart material tools');
    if (canViewAnalytics) list.add('Monthly analytics report');
    if (verifiedBadge) list.add('Verified badge');
    if (featuredListing) list.add('Featured in search');
    if (prioritySupport) list.add('Priority support');
    return list;
  }
}

// ── Client Plan config model ──────────────────────────────────────────────
class ClientPlanConfig {
  final String  name;
  final int     priceMonthly;      // in PKR
  final String  badge;
  final String  description;
  final int     projectPostsAllowed;
  final int     bidsViewLimit;
  final bool    verifiedBadge;
  final bool    featuredListing;
  final bool    canAccessChat;
  final bool    canUseAiTools;
  final bool    prioritySupport;

  const ClientPlanConfig({
    required this.name,
    required this.priceMonthly,
    required this.badge,
    required this.description,
    required this.projectPostsAllowed,
    required this.bidsViewLimit,
    required this.verifiedBadge,
    required this.featuredListing,
    required this.canAccessChat,
    required this.canUseAiTools,
    required this.prioritySupport,
  });

  /// Returns a human-readable list of features this plan unlocks.
  List<String> get featureList {
    final list = <String>[];
    if (projectPostsAllowed >= 999) {
      list.add('Unlimited project posts');
    } else {
      list.add('$projectPostsAllowed project posts/month');
    }
    if (bidsViewLimit >= 999) {
      list.add('All bids visible');
    } else {
      list.add('View up to $bidsViewLimit bids');
    }
    if (canAccessChat) list.add('Direct messaging');
    if (canUseAiTools) list.add('AI tools access');
    if (verifiedBadge) list.add('Verified client badge');
    if (featuredListing) list.add('Featured in search');
    if (prioritySupport) list.add('Priority support');
    return list;
  }
}

// ── Connect package model ────────────────────────────────────────────────
class ConnectPackage {
  final String id;
  final int    connects;
  final int    priceRs;
  final String label;

  const ConnectPackage({
    required this.id,
    required this.connects,
    required this.priceRs,
    required this.label,
  });
}

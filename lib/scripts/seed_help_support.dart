// lib/scripts/seed_help_support.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

final List<Map<String, dynamic>> helpSupportSeedData = [
  {
    "category": "Client",
    "question": "How do I post a new project?",
    "answer":
        "Go to the Home screen and tap 'Post a Project'. Fill in the project details — title, description, category, budget range, and location — then submit. Nearby contractors will be able to view and bid on it."
  },
  {
    "category": "Client",
    "question": "How does bidding work?",
    "answer":
        "Once you post a project, contractors can submit bids with their proposed amount and a short message. You can view all bids under 'My Projects', compare them by price, contractor rating, and past work, then choose the one that best fits your needs."
  },
  {
    "category": "Client",
    "question": "How do I accept a bid and hire a contractor?",
    "answer":
        "Open your project from 'My Projects', view the list of bids, and tap 'Accept' on the one you want. This will mark the project as in-progress and notify the contractor. Other bids will automatically be closed."
  },
  {
    "category": "Client",
    "question": "Can I cancel or edit a project after posting?",
    "answer":
        "You can edit a project's details as long as no bid has been accepted yet. Once a contractor is hired, cancellations may be subject to a cancellation policy — contact support if you need to cancel an active project."
  },
  {
    "category": "Client",
    "question": "How do I contact a contractor before accepting their bid?",
    "answer":
        "You can message a contractor directly from their bid card before making a decision. This lets you ask questions about their experience, timeline, or approach before hiring."
  },
  {
    "category": "Client",
    "question": "How is payment handled?",
    "answer":
        "Payment terms are agreed upon between you and the contractor directly. We recommend confirming milestones and payment schedule before work begins. Thekaydaar does not currently process payments within the app."
  },
  {
    "category": "Client",
    "question": "What if a contractor doesn't show up or doesn't complete the work?",
    "answer":
        "If a contractor fails to deliver as agreed, please report the issue through 'Help & Support > Report a Problem' with your project details. Our team will review the case and may take action on the contractor's account."
  },
  {
    "category": "Client",
    "question": "How do I leave a review for a contractor?",
    "answer":
        "Once a project is marked complete, you'll be prompted to rate and review the contractor. You can also do this anytime from the completed project's details page."
  },
  {
    "category": "Client",
    "question": "Is my personal info visible to all contractors?",
    "answer":
        "Your phone number and exact address are only shared with a contractor after you've accepted their bid. Before that, contractors can only see your project details and general location area."
  },
  {
    "category": "Contractor",
    "question": "How do I find available projects near me?",
    "answer":
        "Go to the 'My Gigs' or 'Browse Projects' tab to see open projects filtered by your location and skill category. You can tap any project to view full details before bidding."
  },
  {
    "category": "Contractor",
    "question": "How do I submit a bid on a project?",
    "answer":
        "Open the project you're interested in, tap 'Place Bid', enter your proposed amount and an optional message explaining your approach or timeline, then submit."
  },
  {
    "category": "Contractor",
    "question": "How do I mark a project as complete?",
    "answer":
        "Once you've finished the work, open the project from 'My Bids' and tap 'Mark as Complete'. The client will be notified to confirm completion and leave a review."
  },
  {
    "category": "Contractor",
    "question": "Why am I not showing up as online to clients?",
    "answer":
        "Your online status updates automatically while the app is active. If you believe you're online but not appearing to clients, try closing and reopening the app. If the issue continues, contact support."
  },
  {
    "category": "Contractor",
    "question": "How does Thekaydaar verify contractor profiles?",
    "answer":
        "Contractors can add their skills, experience, past project photos, and certifications to their profile. Verified badges may be added over time based on completed projects and client reviews."
  },
  {
    "category": "Contractor",
    "question": "Does Thekaydaar take a commission/fee?",
    "answer":
        "Current fee details, if any, are outlined in your contractor agreement. Check the 'Terms & Conditions' section or contact support for the latest fee structure."
  },
  {
    "category": "Contractor",
    "question": "How do I withdraw my earnings?",
    "answer":
        "Since payments are currently handled directly between you and the client, there is no in-app withdrawal process. Make sure to agree on payment method and schedule with your client beforehand."
  },
  {
    "category": "Contractor",
    "question": "What happens if a client cancels after I've started work?",
    "answer":
        "If a client cancels a project after work has begun, please document the work done and report the issue through 'Help & Support > Report a Problem' so our team can assist in resolving the dispute."
  },
  {
    "category": "General",
    "question": "How do I reset my password?",
    "answer":
        "On the login screen, tap 'Forgot Password' and enter your registered phone number or email. You'll receive instructions to reset your password."
  },
  {
    "category": "General",
    "question": "Can I switch between client and contractor roles?",
    "answer":
        "Currently, each account is set up as either a client or a contractor. To use the other role, you'll need to create a separate account with a different phone number or email."
  },
  {
    "category": "General",
    "question": "How do I delete my account?",
    "answer":
        "Go to Profile > Settings > Delete Account. Note that this action is permanent and will remove your project history, bids, and messages."
  },
  {
    "category": "General",
    "question": "How do I report a fake profile or scam?",
    "answer":
        "Go to Help & Support > Report a Problem, select 'Fake Profile / Scam', and provide as much detail as possible. Our team will investigate and take appropriate action."
  },
  {
    "category": "General",
    "question": "How do I contact Thekaydaar support directly?",
    "answer":
        "You can reach us via the 'Contact Us' option in Help & Support, or email our support team. We aim to respond within 24-48 hours."
  },
];

/// Seeds the `help_support` collection.
/// `force: true` skips the "already has data" check and writes anyway —
/// use this once to guarantee data lands, then set back to false.
Future<void> seedHelpSupport({bool force = true}) async {
  debugPrint('[SEED] Starting help_support seed...');

  final collection = FirebaseFirestore.instance.collection('help_support');

  if (!force) {
    final existing = await collection.limit(1).get();
    if (existing.docs.isNotEmpty) {
      debugPrint('[SEED] help_support already has data — skipping.');
      return;
    }
  }

  try {
    for (final item in helpSupportSeedData) {
      final ref = await collection.add(item);
      debugPrint('[SEED] Added doc ${ref.id} — ${item['question']}');
    }
    debugPrint('[SEED] DONE — seeded ${helpSupportSeedData.length} docs.');
  } catch (e, st) {
    debugPrint('[SEED] FAILED: $e');
    debugPrint('$st');
  }
}
// =============================================================================
// translation_service.dart
// Simple English <-> Urdu translation service for Thekaydaar.pk.
// Singleton pattern — import and use TranslationService.instance.
// =============================================================================

import 'package:flutter/foundation.dart';

class TranslationService extends ChangeNotifier {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  bool _isUrdu = false;
  bool get isUrdu => _isUrdu;
  String get currentLocale => _isUrdu ? 'ur' : 'en';
  String get localeLabel => _isUrdu ? 'اردو' : 'EN';

  void toggleLanguage() {
    _isUrdu = !_isUrdu;
    notifyListeners();
  }

  void setLanguage(bool urdu) {
    if (_isUrdu != urdu) {
      _isUrdu = urdu;
      notifyListeners();
    }
  }

  /// Translate a key. Returns Urdu text if current locale is Urdu,
  /// otherwise returns the English text (or the key itself as fallback).
  String t(String key) {
    if (!_isUrdu) return key;
    return _dictionary[key] ?? key;
  }

  /// Translate a full string — if Urdu mode, look up the string directly.
  /// If no translation found, return the original.
  String translateText(String text) {
    if (!_isUrdu) return text;
    return _fullTextMap[text] ?? text;
  }

  // ── Key-based dictionary (Urdu translations) ────────────────────────────
  static const Map<String, String> _dictionary = {
    // ─── Navigation & Common ───
    'Back': 'واپس',
    'Cancel': 'منسوخ کریں',
    'Confirm': 'تصدیق کریں',
    'Submit': 'جمع کرائیں',
    'Save': 'محفوظ کریں',
    'Delete': 'حذف کریں',
    'Edit': 'ترمیم',
    'Done': 'مکمل',
    'Next': 'اگلا',
    'Previous': 'پچھلا',
    'Close': 'بند کریں',
    'Search': 'تلاش',
    'Settings': 'ترتیبات',
    'Profile': 'پروفائل',
    'Home': 'ہوم',
    'Projects': 'پراجیکٹس',
    'Messages': 'پیغامات',
    'Notifications': 'اطلاعات',
    'Loading...': 'لوڈ ہو رہا ہے...',
    'Error': 'خرابی',
    'Success': 'کامیابی',
    'Overview': 'جائزہ',
    'Browse': 'دیکھیں',
    'Earnings': 'کمائی',
    'Incoming Requests': 'آنے والی درخواستیں',

    // ─── Dashboard ───
    'Dashboard': 'ڈیش بورڈ',
    'Welcome back': 'واپسی خوش آمدید',
    'Active Projects': 'فعال پراجیکٹس',
    'Completed Projects': 'مکمل پراجیکٹس',
    'My Projects': 'میرے پراجیکٹس',
    'Post a Project': 'پراجیکٹ پوسٹ کریں',
    'Browse Projects': 'پراجیکٹس دیکھیں',
    'Post New Project': 'نیا پراجیکٹ پوسٹ کریں',
    'Online Contractors': 'آن لائن ٹھیکیدار',
    'Post Project': 'پراجیکٹ پوسٹ کریں',
    'No projects yet.': 'ابھی تک کوئی پراجیکٹ نہیں',
    'Projects you post will show up here.': 'آپ کے پوسٹ کیے گئے پراجیکٹس یہاں نظر آئیں گے۔',

    // ─── Plans & Billing ───
    'Plans & Billing': 'پلانز اور بلنگ',
    'Current Plan': 'موجودہ پلان',
    'Available Plans': 'دستیاب پلانز',
    'Upgrade Plan': 'پلان اپ گریڈ کریں',
    'Free': 'مفت',
    'Pro': 'پرو',
    'Elite': 'ایلیٹ',
    'Standard': 'اسٹینڈرڈ',
    'Premium': 'پریمیم',
    'Business': 'بزنس',
    'Connects': 'کنیکٹس',
    'Buy Connects': 'کنیکٹس خریدیں',
    'Payment History': 'ادائیگی کی تاریخ',
    'Payment Under Review': 'ادائیگی زیر جائزہ',
    'Expiring soon': 'جلد ختم ہو رہا ہے',
    'Plans': 'پلانز',

    // ─── Payment ───
    'Payment Method': 'ادائیگی کا طریقہ',
    'Transaction ID': 'ٹرانزیکشن آئی ڈی',
    'Submit Payment': 'ادائیگی جمع کرائیں',
    'Payment Submitted': 'ادائیگی جمع ہو گئی',
    'Payment Confirmed': 'ادائیگی کی تصدیق ہو گئی',
    'EasyPaisa': 'ایزی پیسہ',
    'JazzCash': 'جاز کیش',
    'Escrow Protection': 'ایسکرو تحفظ',
    'Platform Fee': 'پلیٹ فارم فیس',
    'Commission': 'کمیشن',
    'Contractor Payout': 'ٹھیکیدار کی ادائیگی',
    'Total Amount': 'کل رقم',

    // ─── Contracts ───
    'Contract': 'معاہدہ',
    'Create Contract': 'معاہدہ بنائیں',
    'Contract Details': 'معاہدہ کی تفصیلات',
    'Sign Contract': 'معاہدے پر دستخط کریں',
    'Digital Signature': 'ڈیجیٹل دستخط',
    'Scope of Work': 'کام کی گنجائش',
    'Milestones': 'سنگ میل',
    'Payment Terms': 'ادائیگی کی شرائط',
    'Legal Terms': 'قانونی شرائط',
    'Print Contract': 'معاہدہ پرنٹ کریں',
    'Download PDF': 'پی ڈی ایف ڈاؤن لوڈ کریں',
    'Both parties signed': 'دونوں فریقوں نے دستخط کر دیے',
    'Pending Signatures': 'دستخط زیر التوا',
    'Work Completed': 'کام مکمل ہو گیا',
    'Project Brief Description': 'پراجیکٹ کی مختصر تفصیل',
    'Mark Project Complete': 'پراجیکٹ مکمل نشان زد کریں',
    'Raise a Dispute': 'تنازعہ اٹھائیں',

    // ─── Bidding ───
    'Place Bid': 'بولی لگائیں',
    'My Bids': 'میری بولیاں',
    'Bid Amount': 'بولی کی رقم',
    'Budget Range': 'بجٹ کی حد',

    // ─── Messages & Chat ───
    'Type a message...': 'پیغام لکھیں...',
    'Send': 'بھیجیں',
    'Conversations': 'بات چیت',
    'Start the conversation': 'بات چیت شروع کریں',
    'Smart Reply': 'سمارٹ جواب',

    // ─── AI Tools ───
    'AI Material Estimator': 'اے آئی مٹیریل ایسٹیمیٹر',
    'AI Tools': 'اے آئی ٹولز',
    'Powered by Gemini AI': 'جیمنی اے آئی کی طاقت سے',

    // ─── Status Labels ───
    'Active': 'فعال',
    'Pending': 'زیر التوا',
    'Completed': 'مکمل',
    'Cancelled': 'منسوخ',
    'Disputed': 'تنازعہ',
    'Approved': 'منظور',
    'Rejected': 'مسترد',

    // ─── Feature Access ───
    'Upgrade to access this feature': 'یہ فیچر استعمال کرنے کے لیے اپ گریڈ کریں',
    'This feature requires Pro plan': 'یہ فیچر پرو پلان کی ضرورت ہے',
    'This feature requires Elite plan': 'یہ فیچر ایلیٹ پلان کی ضرورت ہے',

    // ─── General ───
    'Language': 'زبان',
    'Help & Support': 'مدد اور تعاون',
    'About': 'ہمارے بارے میں',
    'Logout': 'لاگ آؤٹ',
    'Verified': 'تصدیق شدہ',
    'Featured': 'نمایاں',

    // ─── AI House Planner ───
    'Create Project': 'پروجیکٹ بنائیں',
    'AI House Planner': 'اے آئی ہاؤس پلانر',
    'Generate House Plan': 'ہاؤس پلان بنائیں',
    'Blueprint': 'بلیو پرنٹ',
    'Edit Blueprint': 'بلیو پرنٹ میں ترمیم کریں',
    'View 3D': 'تین جہتی دیکھیں',
    'View 360': '۳۶۰-degree ڈیکھیں',
    'Publish Project': 'پروجیکٹ شائع کریں',
    'Plot Details': 'پلاٹ کی تفصیلات',
    'House Requirements': 'گھر کی ضروریات',
    'Room Dimensions': 'کمرے کے پیمانے',
  };

  // ── Full-text translation map (for longer strings) ───────────────────────
  static const Map<String, String> _fullTextMap = {
    // Contract screen texts
    'Confirm Digital Signature': 'ڈیجیٹل دستخط کی تصدیق',
    'Sign This Agreement': 'اس معاہدے پر دستخط کریں',
    'Mark Project Complete': 'پراجیکٹ مکمل نشان زد کریں',
    'Waiting for the contractor to mark the project complete.':
        'ٹھیکیدار کے پراجیکٹ مکمل نشان زد کرنے کا انتظار۔',
    'Raise a Dispute': 'تنازعہ اٹھائیں',
    'Payment submitted. Admin verification pending.':
        'ادائیگی جمع ہو گئی۔ ایڈمن کی تصدیق زیر التوا ہے۔',
    'Payment confirmed and project closed.':
        'ادائیگی کی تصدیق ہو گئی اور پراجیکٹ بند ہو گیا۔',

    // Dashboard texts
    'Post a new project and get bids from verified contractors.':
        'نیا پراجیکٹ پوسٹ کریں اور تصدیق شدہ ٹھیکیداروں سے بولیاں حاصل کریں۔',
    'Browse available projects and place your bids.':
        'دستیاب پراجیکٹس دیکھیں اور اپنی بولیاں لگائیں۔',

    // Escrow related
    'Payment held securely by Thekaydaar.pk':
        'ادائیگی Thekaydaar.pk نے محفوظ طریقے سے رکھی ہے',
    'Payment secured. Amount will be released after verification.':
        'ادائیگی محفوظ ہو گئی۔ تصدیق کے بعد رقم جاری کی جائے گی۔',

    // Plan descriptions
    'Upgrade your plan to unlock more features.':
        'مزید فیچرز کے لیے اپنا پلان اپ گریڈ کریں۔',
    'Your plan will activate once admin approves your payment.':
        'ایڈمن کی ادائیگی کی منظوری کے بعد آپ کا پلان فعال ہو جائے گا۔',

    // Common contract/legal phrases
    'Client': 'کلائنٹ / مالک',
    'Contractor': 'ٹھیکیدار',
    'Advance Payment': 'ایڈوانس ادائیگی',
    'Mid-Project Payment': 'درمیانی ادائیگی',
    'Final Payment': 'حتمی ادائیگی',
    'Materials Responsibility': 'مواد کی ذمہ داری',
    'Delay Penalty': 'تاخیر کی جرمانہ',
    'Warranty Period': 'وارنٹی کی مدت',
    'Start Date': 'شروع کی تاریخ',
    'End Date': 'ختم کی تاریخ',

    // Project types
    'Grey Structure': 'گرے اسٹرکچر',
    'Finishing': 'فنشنگ',
    'Renovation': 'تزئین و آرائش',
    'Plumbing': 'پلمبنگ',
    'Electrical': 'بجلی کا کام',
    'Painting': 'پینٹنگ',
    'Tiles': 'ٹائلز',
    'Carpentry': 'بڑھئی گیری',
    'Roofing': 'چھت',
    'Foundation': 'بنیاد',
  };
}

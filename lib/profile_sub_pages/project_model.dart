import 'package:cloud_firestore/cloud_firestore.dart';
import 'bid_model.dart';

/// Represents a single project document from the top-level `projects`
/// collection. Matches the real schema (fields confirmed from Firestore
/// console), including that several numeric-looking fields are actually
/// stored as Strings. 
  class ProjectModel {
  final String id;
  final String title;
  final String description;
  final String status;
  final String projectType;
  final String city;
  final String area;
  final String budgetMin;
  final String budgetMax;
  final String duration;
  final String startDate;
  final List<String> services;
  final bool urgentRequired;

  final String clientId;
  final String clientName;

  final String coverImage;      // ← NEW
  final List<String> images;    // ← NEW

  final String? acceptedAmount;
  final String? acceptedTkId;
  final String? acceptedTkName;
  final BidModel? acceptedBid;
  final List<BidModel> bids;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? completedAt;

  ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.projectType,
    required this.city,
    required this.area,
    required this.budgetMin,
    required this.budgetMax,
    required this.duration,
    required this.startDate,
    required this.services,
    required this.urgentRequired,
    required this.clientId,
    required this.clientName,
    this.coverImage = '',        // ← NEW
    this.images = const [],      // ← NEW
    this.acceptedAmount,
    this.acceptedTkId,
    this.acceptedTkName,
    this.acceptedBid,
    required this.bids,
    this.createdAt,
    this.updatedAt,
    this.completedAt,
  });

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    return ProjectModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      status: data['status'] ?? '',
      projectType: data['projectType'] ?? '',
      city: data['city'] ?? '',
      area: data['area'] ?? '',
      budgetMin: data['budgetMin']?.toString() ?? '',
      budgetMax: data['budgetMax']?.toString() ?? '',
      duration: data['duration'] ?? '',
      startDate: data['startDate'] ?? '',
      services: (data['services'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      urgentRequired: data['urgentRequired'] ?? false,
      clientId: data['clientId'] ?? '',
      clientName: data['clientName'] ?? '',
      coverImage: data['coverImage'] ?? '',                         // ← NEW
      images: (data['images'] as List<dynamic>?)                    // ← NEW
              ?.map((e) => e.toString())
              .toList() ??
          [],
      acceptedAmount: data['acceptedAmount']?.toString(),
      acceptedTkId: data['acceptedTkId'],
      acceptedTkName: data['acceptedTkName'],
      acceptedBid: data['acceptedBid'] != null
          ? BidModel.fromMap(Map<String, dynamic>.from(data['acceptedBid']))
          : null,
      bids: (data['bids'] as List<dynamic>?)
              ?.map((e) => BidModel.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
    );
  }

  int get bidCount => bids.length;
  bool get hasAcceptedBid => acceptedBid != null;
}
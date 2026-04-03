import 'package:cloud_firestore/cloud_firestore.dart';

class FamilyModel {
  final String id;
  final List<String> members;
  final DateTime createdAt;
  final String inviteCode;

  FamilyModel({
    required this.id,
    required this.members,
    required this.createdAt,
    this.inviteCode = '',
  });

  factory FamilyModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FamilyModel(
      id: doc.id,
      members: List<String>.from(data['members'] ?? []),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      inviteCode: data['inviteCode'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'members': members,
      'createdAt': Timestamp.fromDate(createdAt),
      'inviteCode': inviteCode,
    };
  }
}

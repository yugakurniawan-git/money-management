import 'package:cloud_firestore/cloud_firestore.dart';

class GoalModel {
  final String id;
  final String title;
  final String emoji;
  final double targetAmount;
  final double savedAmount;
  final DateTime? targetDate;
  final DateTime createdAt;

  const GoalModel({
    required this.id,
    required this.title,
    required this.emoji,
    required this.targetAmount,
    required this.savedAmount,
    this.targetDate,
    required this.createdAt,
  });

  double get progress =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0;

  double get remaining => (targetAmount - savedAmount).clamp(0, double.infinity);

  bool get isCompleted => savedAmount >= targetAmount;

  factory GoalModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return GoalModel(
      id: doc.id,
      title: d['title'] ?? '',
      emoji: d['emoji'] ?? '🎯',
      targetAmount: (d['targetAmount'] ?? 0).toDouble(),
      savedAmount: (d['savedAmount'] ?? 0).toDouble(),
      targetDate: (d['targetDate'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'emoji': emoji,
        'targetAmount': targetAmount,
        'savedAmount': savedAmount,
        'targetDate':
            targetDate != null ? Timestamp.fromDate(targetDate!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  GoalModel copyWith({
    String? id,
    String? title,
    String? emoji,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
    bool clearTargetDate = false,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      title: title ?? this.title,
      emoji: emoji ?? this.emoji,
      targetAmount: targetAmount ?? this.targetAmount,
      savedAmount: savedAmount ?? this.savedAmount,
      targetDate: clearTargetDate ? null : (targetDate ?? this.targetDate),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

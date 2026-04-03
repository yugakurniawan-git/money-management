import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CategoryModel {
  final String id;
  final String name;
  final String icon;
  final Color color;
  final String type; // "expense", "income", "both"
  final bool isDefault;
  final List<String> keywords;

  CategoryModel({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.isDefault = false,
    this.keywords = const [],
  });

  factory CategoryModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CategoryModel(
      id: doc.id,
      name: data['name'] ?? '',
      icon: data['icon'] ?? '',
      color: Color(data['color'] ?? 0xFF9E9E9E),
      type: data['type'] ?? 'expense',
      isDefault: data['isDefault'] ?? false,
      keywords: List<String>.from(data['keywords'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'icon': icon,
      'color': color.toARGB32(),
      'type': type,
      'isDefault': isDefault,
      'keywords': keywords,
    };
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? icon,
    Color? color,
    String? type,
    bool? isDefault,
    List<String>? keywords,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      keywords: keywords ?? this.keywords,
    );
  }
}

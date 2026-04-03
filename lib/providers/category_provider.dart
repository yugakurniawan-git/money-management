import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/category.dart';
import 'transaction_provider.dart';

final categoriesProvider = StreamProvider<List<CategoryModel>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value([]);
  try {
    return ref.watch(firebaseServiceProvider).getCategories();
  } catch (_) {
    return Stream.value([]);
  }
});

// Map category ID to category name for display
final categoryNameMapProvider = Provider<Map<String, String>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? [];
  return {for (final cat in categories) cat.id: cat.name};
});

// Map category ID to category for full access
final categoryMapProvider = Provider<Map<String, CategoryModel>>((ref) {
  final categories = ref.watch(categoriesProvider).value ?? [];
  return {for (final cat in categories) cat.id: cat};
});

// Load and seed default categories
Future<List<CategoryModel>> loadDefaultCategories() async {
  const uuid = Uuid();
  final jsonStr = await rootBundle.loadString('assets/default_categories.json');
  final List<dynamic> jsonList = json.decode(jsonStr);

  return jsonList.map((json) {
    return CategoryModel(
      id: uuid.v4(),
      name: json['name'],
      icon: json['icon'],
      color: Color(json['color']),
      type: json['type'],
      isDefault: true,
      keywords: List<String>.from(json['keywords']),
    );
  }).toList();
}

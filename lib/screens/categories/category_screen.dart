import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/category.dart';
import '../../theme/app_colors.dart';
import '../../providers/category_provider.dart';
import '../../services/firebase_service.dart';
import '../../widgets/common/glass_container.dart';
import '../../widgets/common/staggered_list_animation.dart';


class CategoryScreen extends ConsumerWidget {
  const CategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kategori'),
        actions: [
          GestureDetector(
            onTap: () => _showCategoryDialog(context, ref, null),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
      body: categoriesAsync.when(
        loading: () =>
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (categories) {
          if (categories.isEmpty) {
            return Center(
              child: Text('Belum ada kategori',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return StaggeredListItem(
                index: index,
                child: GlassContainer(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      // Emoji icon
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cat.color,
                              cat.color.withAlpha(180),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            cat.icon.isNotEmpty ? cat.icon : '•',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(cat.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${cat.keywords.length} keyword • ${cat.type == 'expense' ? 'Pengeluaran' : cat.type == 'income' ? 'Pemasukan' : 'Keduanya'}',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!cat.isDefault)
                        PopupMenuButton<String>(
                          icon: Icon(Icons.more_vert,
                              color: AppColors.textSecondary, size: 20),
                          onSelected: (value) {
                            if (value == 'edit') {
                              _showCategoryDialog(context, ref, cat);
                            } else if (value == 'delete') {
                              _deleteCategory(context, ref, cat.id);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Hapus',
                                  style: TextStyle(color: AppColors.expense)),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showCategoryDialog(
      BuildContext context, WidgetRef ref, CategoryModel? existing) {
    final nameController =
        TextEditingController(text: existing?.name ?? '');
    final keywordsController =
        TextEditingController(text: existing?.keywords.join(', ') ?? '');
    String type = existing?.type ?? 'expense';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(existing == null ? 'Tambah Kategori' : 'Edit Kategori'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration:
                      const InputDecoration(hintText: 'Nama Kategori'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(hintText: 'Tipe'),
                  items: const [
                    DropdownMenuItem(
                        value: 'expense', child: Text('Pengeluaran')),
                    DropdownMenuItem(
                        value: 'income', child: Text('Pemasukan')),
                    DropdownMenuItem(
                        value: 'both', child: Text('Keduanya')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v!),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: keywordsController,
                  decoration: const InputDecoration(
                    hintText: 'Keywords (pisah koma): GRAB, GOJEK',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            GestureDetector(
              onTap: () async {
                final keywords = keywordsController.text
                    .split(',')
                    .map((k) => k.trim().toUpperCase())
                    .where((k) => k.isNotEmpty)
                    .toList();

                final service = FirebaseService();
                if (existing == null) {
                  await service.addCategory(CategoryModel(
                    id: const Uuid().v4(),
                    name: nameController.text,
                    icon: '',
                    color: Colors.blue,
                    type: type,
                    keywords: keywords,
                  ));
                } else {
                  await service.updateCategory(existing.copyWith(
                    name: nameController.text,
                    type: type,
                    keywords: keywords,
                  ));
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Simpan',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteCategory(
      BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Kategori?'),
        content: const Text(
            'Transaksi dengan kategori ini akan menjadi tidak berkategori.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
          GestureDetector(
            onTap: () => Navigator.pop(context, true),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: AppColors.expenseGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Hapus',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseService().deleteCategory(id);
    }
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/family.dart';
import '../models/stock.dart';
import '../models/budget.dart';
import '../models/goal.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String get _userId {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('User not authenticated');
    return uid;
  }

  // ===== TRANSACTIONS =====

  CollectionReference get _transactionsRef =>
      _firestore.collection('users').doc(_userId).collection('transactions');

  Stream<List<TransactionModel>> getTransactions({
    String? accountId,
    DateTime? startDate,
    DateTime? endDate,
  }) {
    // Use simple query without orderBy to avoid needing Firestore indexes
    Query query = _transactionsRef;

    if (accountId != null) {
      query = query.where('accountId', isEqualTo: accountId);
    }

    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => TransactionModel.fromFirestore(doc))
          .where((txn) {
            if (startDate != null && txn.transactionDate.isBefore(startDate)) {
              return false;
            }
            if (endDate != null && txn.transactionDate.isAfter(endDate)) {
              return false;
            }
            return true;
          })
          .toList();
      // Sort by date descending in Dart (no index needed)
      list.sort((a, b) => b.transactionDate.compareTo(a.transactionDate));
      return list;
    });
  }

  Future<void> addTransaction(TransactionModel transaction) async {
    await _transactionsRef.doc(transaction.id).set(transaction.toFirestore());
  }

  Future<void> addTransactions(List<TransactionModel> transactions) async {
    final batch = _firestore.batch();
    for (final txn in transactions) {
      batch.set(_transactionsRef.doc(txn.id), txn.toFirestore());
    }
    await batch.commit();
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    await _transactionsRef.doc(transaction.id).update(transaction.toFirestore());
  }

  Future<void> deleteTransaction(String transactionId) async {
    await _transactionsRef.doc(transactionId).delete();
  }

  Future<Set<String>> getExistingHashes() async {
    final snapshot = await _transactionsRef.get();
    return snapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>)['importHash'] as String? ?? '')
        .where((hash) => hash.isNotEmpty)
        .toSet();
  }

  /// Get map of importHash → document ID for existing transactions
  Future<Map<String, String>> getExistingHashToIdMap() async {
    final snapshot = await _transactionsRef.get();
    final map = <String, String>{};
    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final hash = data['importHash'] as String? ?? '';
      if (hash.isNotEmpty) {
        map[hash] = doc.id;
      }
    }
    return map;
  }

  /// Delete existing transactions by their document IDs, then add new ones (replace)
  Future<void> replaceTransactions(
    List<String> deleteIds,
    List<TransactionModel> newTransactions,
  ) async {
    // Firestore batch limit is 500, so we chunk if needed
    final allOps = <_BatchOp>[];
    for (final id in deleteIds) {
      allOps.add(_BatchOp.delete(id));
    }
    for (final txn in newTransactions) {
      allOps.add(_BatchOp.set(txn));
    }

    // Process in chunks of 450 (safe margin under 500 limit)
    const chunkSize = 450;
    for (var i = 0; i < allOps.length; i += chunkSize) {
      final chunk = allOps.skip(i).take(chunkSize).toList();
      final batch = _firestore.batch();
      for (final op in chunk) {
        if (op.isDelete) {
          batch.delete(_transactionsRef.doc(op.deleteId!));
        } else {
          batch.set(
            _transactionsRef.doc(op.transaction!.id),
            op.transaction!.toFirestore(),
          );
        }
      }
      await batch.commit();
    }
  }

  // ===== CATEGORIES =====

  CollectionReference get _categoriesRef =>
      _firestore.collection('users').doc(_userId).collection('categories');

  Stream<List<CategoryModel>> getCategories() {
    return _categoriesRef.orderBy('name').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => CategoryModel.fromFirestore(doc)).toList());
  }

  Future<void> addCategory(CategoryModel category) async {
    await _categoriesRef.doc(category.id).set(category.toFirestore());
  }

  Future<void> updateCategory(CategoryModel category) async {
    await _categoriesRef.doc(category.id).update(category.toFirestore());
  }

  Future<void> deleteCategory(String categoryId) async {
    await _categoriesRef.doc(categoryId).delete();
  }

  Future<void> seedDefaultCategories(List<CategoryModel> categories) async {
    final snapshot = await _categoriesRef.limit(1).get();
    if (snapshot.docs.isNotEmpty) return; // Already seeded

    final batch = _firestore.batch();
    for (final cat in categories) {
      batch.set(_categoriesRef.doc(cat.id), cat.toFirestore());
    }
    await batch.commit();
  }

  /// Force re-seed: delete all default categories and replace with new ones.
  /// Preserves user-created categories (isDefault == false).
  Future<void> forceReseedCategories(List<CategoryModel> newDefaults) async {
    // Delete existing default categories
    final snapshot = await _categoriesRef.get();
    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['isDefault'] == true) {
        batch.delete(doc.reference);
      }
    }

    // Add new defaults
    for (final cat in newDefaults) {
      batch.set(_categoriesRef.doc(cat.id), cat.toFirestore());
    }

    await batch.commit();
  }

  // ===== ACCOUNTS =====

  CollectionReference get _accountsRef =>
      _firestore.collection('users').doc(_userId).collection('accounts');

  Stream<List<AccountModel>> getAccounts() {
    return _accountsRef.snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => AccountModel.fromFirestore(doc)).toList());
  }

  Future<void> addAccount(AccountModel account) async {
    await _accountsRef.doc(account.id).set(account.toFirestore());
  }

  Future<void> updateAccount(AccountModel account) async {
    await _accountsRef.doc(account.id).update(account.toFirestore());
  }

  // ===== WATCHLIST (Stock) =====

  CollectionReference get _watchlistRef =>
      _firestore.collection('users').doc(_userId).collection('watchlist');

  Stream<List<WatchlistItemModel>> getWatchlist() {
    return _watchlistRef.orderBy('addedAt', descending: true).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => WatchlistItemModel.fromFirestore(doc))
            .toList());
  }

  Future<void> addToWatchlist(WatchlistItemModel item) async {
    await _watchlistRef.doc(item.id).set(item.toFirestore());
  }

  Future<void> removeFromWatchlist(String itemId) async {
    await _watchlistRef.doc(itemId).delete();
  }

  // ===== BUDGET =====

  CollectionReference get _budgetsRef =>
      _firestore.collection('users').doc(_userId).collection('budgets');

  Stream<List<BudgetModel>> getBudgets() {
    return _budgetsRef.snapshots().map((s) =>
        s.docs.map((d) => BudgetModel.fromFirestore(d)).toList());
  }

  Future<void> setBudget(BudgetModel budget) async {
    await _budgetsRef.doc(budget.id).set(budget.toFirestore());
  }

  Future<void> deleteBudget(String budgetId) async {
    await _budgetsRef.doc(budgetId).delete();
  }

  // ===== GOALS =====

  CollectionReference get _goalsRef =>
      _firestore.collection('users').doc(_userId).collection('goals');

  Stream<List<GoalModel>> getGoals() {
    return _goalsRef.orderBy('createdAt').snapshots().map(
        (s) => s.docs.map((d) => GoalModel.fromFirestore(d)).toList());
  }

  Future<void> setGoal(GoalModel goal) async {
    await _goalsRef.doc(goal.id).set(goal.toFirestore());
  }

  Future<void> deleteGoal(String goalId) async {
    await _goalsRef.doc(goalId).delete();
  }

  // ===== RESET =====

  /// Hapus semua transaksi, akun, dan watchlist user. Kategori dipertahankan.
  Future<void> resetAllData() async {
    final collections = [_transactionsRef, _accountsRef, _watchlistRef];
    for (final ref in collections) {
      var snapshot = await ref.limit(450).get();
      while (snapshot.docs.isNotEmpty) {
        final batch = _firestore.batch();
        for (final doc in snapshot.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
        snapshot = await ref.limit(450).get();
      }
    }
  }

  // ===== FAMILY =====

  Future<FamilyModel?> getFamily() async {
    final snapshot = await _firestore
        .collection('families')
        .where('members', arrayContains: _userId)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return FamilyModel.fromFirestore(snapshot.docs.first);
  }

  Future<void> createFamily() async {
    final familyRef = _firestore.collection('families').doc();
    await familyRef.set(FamilyModel(
      id: familyRef.id,
      members: [_userId],
      createdAt: DateTime.now(),
    ).toFirestore());
  }

  Stream<List<TransactionModel>> getFamilyTransactions(
      List<String> memberIds) {
    // Listen to all family members' transactions
    return _firestore
        .collectionGroup('transactions')
        .orderBy('transactionDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => TransactionModel.fromFirestore(doc))
            .toList());
  }
}

class _BatchOp {
  final String? deleteId;
  final TransactionModel? transaction;

  _BatchOp.delete(this.deleteId) : transaction = null;
  _BatchOp.set(this.transaction) : deleteId = null;

  bool get isDelete => deleteId != null;
}

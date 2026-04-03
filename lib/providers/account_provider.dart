import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/account.dart';
import 'transaction_provider.dart';

final accountsProvider = StreamProvider<List<AccountModel>>((ref) {
  final user = ref.watch(authUserProvider).value;
  if (user == null) return Stream.value([]);
  try {
    return ref.watch(firebaseServiceProvider).getAccounts();
  } catch (_) {
    return Stream.value([]);
  }
});

// Selected account filter - null means show all
final selectedAccountProvider =
    NotifierProvider<_SelectedAccountNotifier, String?>(_SelectedAccountNotifier.new);

class _SelectedAccountNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

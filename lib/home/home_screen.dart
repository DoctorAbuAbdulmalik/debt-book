import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils.dart';
import '../customers/customer_screen.dart';
import '../customers/customers_provider.dart';
import '../entries/add_debt_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ждём 300 мс после последнего нажатия, чтобы не слать запрос на каждую букву
  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      setState(() => _query = text);
    });
  }

  Future<void> _addNew() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddDebtScreen()),
    );
    if (added == true) ref.invalidate(customersProvider);
  }

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider(_query));

    return Scaffold(
      appBar: AppBar(title: const Text('دفتر الديون')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNew,
        icon: const Icon(Icons.person_add),
        label: const Text('عميل جديد'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'ابحث عن عميل...',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(30))),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          Expanded(
            child: customers.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return Center(
                    child: Text(_query.isEmpty
                        ? 'لا توجد ديون مستحقة'
                        : 'لا توجد نتائج'),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async =>
                      ref.refresh(customersProvider(_query).future),
                  child: ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(c.name.characters.first),
                        ),
                        title: Text(c.name),
                        subtitle: c.phone == null
                            ? null
                            : Text(c.phone!,
                                textDirection: TextDirection.ltr,
                                textAlign: TextAlign.right),
                        trailing: Text(
                          formatMoney(c.balance),
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CustomerScreen(customer: c),
                            ),
                          );
                          // вернулись: обновим список (клиент мог исчезнуть)
                          ref.invalidate(customersProvider);
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
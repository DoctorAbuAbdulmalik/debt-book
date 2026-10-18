import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer.dart';

final customersProvider =
    FutureProvider.autoDispose.family<List<Customer>, String>((ref, query) async {
  // убираем символы, которые ломают поиск
  final q = query.trim().replaceAll(RegExp(r'[%_,()]'), ' ').trim();

  // Только клиенты с долгом: баланс больше нуля
  var request =
      Supabase.instance.client.from('customer_balances').select().gt('balance', 0);

  if (q.isNotEmpty) {
    request = request.ilike('name', '%$q%');
  }

  final rows = await request.order('name').limit(200);
  return rows.map<Customer>((r) => Customer.fromMap(r)).toList();
});
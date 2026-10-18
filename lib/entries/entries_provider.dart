import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../customers/customer.dart';
import 'entry.dart';

/// Актуальные данные клиента (с балансом)
final customerProvider =
    FutureProvider.autoDispose.family<Customer, String>((ref, id) async {
  final row = await Supabase.instance.client
      .from('customer_balances')
      .select()
      .eq('id', id)
      .single();
  return Customer.fromMap(row);
});

/// История операций клиента (новые сверху), вместе с позициями
final entriesProvider =
    FutureProvider.autoDispose.family<List<Entry>, String>((ref, customerId) async {
  final rows = await Supabase.instance.client
      .from('ledger_entries')
      .select('*, entry_items(*)')
      .eq('customer_id', customerId)
      .order('created_at', ascending: false);
  return rows.map<Entry>((r) => Entry.fromMap(r)).toList();
});
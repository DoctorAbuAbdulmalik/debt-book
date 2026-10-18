import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils.dart';
import '../entries/add_debt_screen.dart';
import '../entries/entries_provider.dart';
import '../entries/entry.dart';
import '../entries/invoice_pdf.dart';
import '../entries/writeoff_sheet.dart';
import 'customer.dart';
import 'edit_customer_sheet.dart';

class CustomerScreen extends ConsumerWidget {
  final Customer customer;

  const CustomerScreen({super.key, required this.customer});

  void _refresh(WidgetRef ref) {
    ref.invalidate(entriesProvider(customer.id));
    ref.invalidate(customerProvider(customer.id));
  }

  Future<void> _addDebt(
      BuildContext context, WidgetRef ref, Customer current) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddDebtScreen(
          customerId: current.id,
          customerName: current.name,
        ),
      ),
    );
    if (added == true) _refresh(ref);
  }

  Future<void> _editCustomer(
      BuildContext context, WidgetRef ref, Customer current) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditCustomerSheet(customer: current),
    );
    if (saved == true) _refresh(ref);
  }

  Future<void> _editEntry(BuildContext context, WidgetRef ref,
      Customer current, Entry entry) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddDebtScreen(
          customerId: current.id,
          customerName: current.name,
          editing: entry,
          currentBalance: current.balance,
        ),
      ),
    );
    if (saved == true) _refresh(ref);
  }

  Future<void> _writeoff(
      BuildContext context, WidgetRef ref, double balance) async {
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WriteoffSheet(customerId: customer.id, balance: balance),
    );
    if (done != true) return;

    _refresh(ref);
    final updated = await ref.read(customerProvider(customer.id).future);

    // Долг выплачен полностью: возвращаемся к списку (клиент там уже скрыт)
    if (updated.balance <= 0 && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم تسديد دين ${updated.name} بالكامل')),
      );
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteEntry(
      BuildContext context, WidgetRef ref, Entry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف العملية'),
        content: Text(
            'هل تريد حذف العملية #${entry.invoiceNo} بمبلغ ${formatMoney(entry.amount)}؟\nلا يمكن التراجع عن هذا الإجراء.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final deleted = await Supabase.instance.client
          .from('ledger_entries')
          .delete()
          .eq('id', entry.id)
          .select();

      if (!context.mounted) return;
      if (deleted.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم الحذف')),
        );
      } else {
        _refresh(ref);
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر الحذف، حاول مرة أخرى')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(customerProvider(customer.id)).value ?? customer;
    final entries = ref.watch(entriesProvider(customer.id));
    final owes = current.balance > 0;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(current.name),
        actions: [
          IconButton(
            tooltip: 'تعديل بيانات العميل',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _editCustomer(context, ref, current),
          ),
          IconButton(
            tooltip: 'طباعة كشف الحساب',
            icon: const Icon(Icons.print_outlined),
            onPressed: (entries.value?.isNotEmpty ?? false)
                ? () => printStatement(current, entries.value!)
                : null,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addDebt(context, ref, current),
        icon: const Icon(Icons.add),
        label: const Text('دين جديد'),
      ),
      body: Column(
        children: [
          // ===== Карточка баланса =====
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            elevation: 0,
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    Text(current.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    if (current.phone != null) ...[
                      const SizedBox(height: 4),
                      Text(current.phone!,
                          textDirection: TextDirection.ltr,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                    const SizedBox(height: 16),
                    Text('الرصيد المستحق',
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    Text(
                      formatMoney(current.balance),
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color:
                            owes ? Colors.red.shade700 : Colors.green.shade700,
                      ),
                    ),
                    if (owes) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () =>
                              _writeoff(context, ref, current.balance),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('شطب / تسديد',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          // ===== История операций =====
          Expanded(
            child: entries.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('لا توجد عمليات بعد'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _EntryCard(
                    entry: list[i],
                    onEdit: () => _editEntry(context, ref, current, list[i]),
                    onPrint: () =>
                        printInvoice(current, list[i], current.balance),
                    onDelete: () => _deleteEntry(context, ref, list[i]),
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

/// Карточка одной операции. Стрелка раскрытия и меню стоят
/// в фиксированных местах, поэтому у всех записей всё выровнено одинаково.
class _EntryCard extends StatefulWidget {
  final Entry entry;
  final VoidCallback onEdit;
  final VoidCallback onPrint;
  final VoidCallback onDelete;

  const _EntryCard({
    required this.entry,
    required this.onEdit,
    required this.onPrint,
    required this.onDelete,
  });

  @override
  State<_EntryCard> createState() => _EntryCardState();
}

class _EntryCardState extends State<_EntryCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    final scheme = Theme.of(context).colorScheme;
    final color = e.isDebt ? Colors.red.shade700 : Colors.green.shade700;
    final hasItems = e.items.isNotEmpty;
    final muted = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: InkWell(
        onTap: hasItems ? () => setState(() => _open = !_open) : null,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Column(
            children: [
              Row(
                children: [
                  // Значок типа операции
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: color.withValues(alpha: 0.12),
                    child: Icon(
                      e.isDebt ? Icons.arrow_upward : Icons.arrow_downward,
                      color: color,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Сумма, тип, дата, номер, примечание
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.isDebt ? '+' : '-'} ${formatMoney(e.amount)}',
                          textDirection: TextDirection.ltr,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                e.isDebt ? 'دين' : 'شطب',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: color,
                                ),
                              ),
                            ),
                            Text(formatDate(e.createdAt),
                                textDirection: TextDirection.ltr,
                                style: muted),
                            Text('#${e.invoiceNo}',
                                textDirection: TextDirection.ltr,
                                style: muted),
                          ],
                        ),
                        if (e.note != null) ...[
                          const SizedBox(height: 4),
                          Text(e.note!, style: const TextStyle(fontSize: 14)),
                        ],
                      ],
                    ),
                  ),

                  // Фиксированное место под стрелку (пустое, если позиций нет)
                  SizedBox(
                    width: 28,
                    child: hasItems
                        ? Icon(_open ? Icons.expand_less : Icons.expand_more,
                            color: scheme.onSurfaceVariant)
                        : null,
                  ),

                  // Меню: редактировать / печатать / удалить
                  PopupMenuButton<String>(
                    tooltip: '',
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade600),
                    onSelected: (v) {
                      switch (v) {
                        case 'edit':
                          widget.onEdit();
                        case 'print':
                          widget.onPrint();
                        case 'delete':
                          widget.onDelete();
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Row(children: [
                          Icon(Icons.edit_outlined),
                          SizedBox(width: 12),
                          Text('تعديل'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'print',
                        child: Row(children: [
                          Icon(Icons.print_outlined),
                          SizedBox(width: 12),
                          Text('طباعة'),
                        ]),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Row(children: [
                          Icon(Icons.delete_outline),
                          SizedBox(width: 12),
                          Text('حذف'),
                        ]),
                      ),
                    ],
                  ),
                ],
              ),

              // Раскрывающийся список позиций
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.topCenter,
                child: _open
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(0, 8, 8, 4),
                        child: Column(
                          children: [
                            const Divider(height: 1),
                            for (final it in e.items)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Expanded(child: Text(it.product)),
                                    Text(
                                      '${formatQty(it.quantity)} × ${formatMoney(it.unitPrice)} = ${formatMoney(it.total)}',
                                      textDirection: TextDirection.ltr,
                                      style: muted,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
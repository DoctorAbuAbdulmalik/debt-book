import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils.dart';
import 'entry.dart';

class _ItemRow {
  final TextEditingController product;
  final TextEditingController qty;
  final TextEditingController price;

  _ItemRow()
      : product = TextEditingController(),
        qty = TextEditingController(text: '1'),
        price = TextEditingController();

  /// Строка с уже сохранёнными данными (для редактирования)
  _ItemRow.from(EntryItem it)
      : product = TextEditingController(text: it.product),
        qty = TextEditingController(text: formatQty(it.quantity)),
        price = TextEditingController(text: it.unitPrice.toStringAsFixed(2));

  void dispose() {
    product.dispose();
    qty.dispose();
    price.dispose();
  }

  /// Строка считается пустой, если не введены ни название, ни цена
  bool get isEmpty =>
      product.text.trim().isEmpty && price.text.trim().isEmpty;

  double get total =>
      (parseNumber(qty.text) ?? 0) * (parseNumber(price.text) ?? 0);
}

class AddDebtScreen extends StatefulWidget {
  /// null = новый клиент (вводим имя и телефон)
  final String? customerId;
  final String? customerName;

  /// Если передана запись, экран работает в режиме редактирования
  final Entry? editing;

  /// Текущий баланс клиента (нужен при редактировании, чтобы
  /// не допустить отрицательного баланса)
  final double? currentBalance;

  const AddDebtScreen({
    super.key,
    this.customerId,
    this.customerName,
    this.editing,
    this.currentBalance,
  });

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final List<_ItemRow> _rows = [];
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.editing != null;
  bool get _isNew => widget.customerId == null;

  /// Позиции есть только у долгов (у списаний их нет)
  bool get _showItems => !_isEdit || widget.editing!.isDebt;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    if (e != null) {
      _note.text = e.note ?? '';
      if (e.items.isNotEmpty) {
        _rows.addAll(e.items.map(_ItemRow.from));
      } else {
        _amount.text = e.amount.toStringAsFixed(2);
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _amount.dispose();
    _note.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  List<_ItemRow> get _usedRows => _rows.where((r) => !r.isEmpty).toList();
  bool get _hasItems => _usedRows.isNotEmpty;
  double get _itemsTotal => _usedRows.fold(0, (s, r) => s + r.total);

  void _addRow() => setState(() => _rows.add(_ItemRow()));

  void _removeRow(_ItemRow row) {
    setState(() => _rows.remove(row));
    row.dispose();
  }

  /// Для нового клиента: ищем по имени (без учёта регистра).
  /// Если такой уже есть (например, раньше полностью расплатился),
  /// добавляем долг ему, иначе создаём нового.
  Future<String> _findOrCreateCustomer(SupabaseClient client) async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();

    final escaped =
        name.replaceAllMapped(RegExp(r'[%_\\]'), (m) => '\\${m[0]}');
    final existing =
        await client.from('customers').select('id').ilike('name', escaped).limit(1);

    if (existing.isNotEmpty) return existing.first['id'] as String;

    final created = await client
        .from('customers')
        .insert({'name': name, 'phone': phone.isEmpty ? null : phone})
        .select('id')
        .single();
    return created['id'] as String;
  }

  Future<void> _save() async {
    if (_isNew && _name.text.trim().isEmpty) {
      return _fail('الرجاء إدخال اسم العميل');
    }

    final used = _showItems ? _usedRows : <_ItemRow>[];
    double amount;

    if (used.isNotEmpty) {
      for (final r in used) {
        final q = parseNumber(r.qty.text);
        final p = parseNumber(r.price.text);
        if (r.product.text.trim().isEmpty) {
          return _fail('الرجاء إدخال اسم الصنف');
        }
        if (q == null || q <= 0) return _fail('الكمية غير صحيحة');
        if (p == null || p < 0) return _fail('السعر غير صحيح');
      }
      amount = _itemsTotal;
    } else {
      amount = parseNumber(_amount.text) ?? 0;
    }

    amount = double.parse(amount.toStringAsFixed(2));
    if (amount <= 0) return _fail('الرجاء إدخال مبلغ صحيح');

    // При редактировании баланс клиента не должен уйти в минус
    if (_isEdit) {
      final old = widget.editing!;
      final balance = widget.currentBalance ?? 0;
      final newBalance = old.isDebt
          ? balance - old.amount + amount
          : balance + old.amount - amount;
      if (newBalance < -0.001) {
        return _fail(old.isDebt
            ? 'المبلغ أقل من المبالغ المسددة سابقاً'
            : 'المبلغ أكبر من الرصيد المستحق');
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      final note = _note.text.trim();

      if (_isEdit) {
        final old = widget.editing!;

        final updated = await client
            .from('ledger_entries')
            .update({
              'amount': amount,
              'note': note.isEmpty ? null : note,
            })
            .eq('id', old.id)
            .select('id');

        if (updated.isEmpty) {
          _fail('تعذر حفظ التعديلات');
          return;
        }

        if (old.isDebt) {
          // Старые позиции заменяем новыми
          await client.from('entry_items').delete().eq('entry_id', old.id);
          if (used.isNotEmpty) {
            await client.from('entry_items').insert([
              for (final r in used)
                {
                  'entry_id': old.id,
                  'product': r.product.text.trim(),
                  'quantity': parseNumber(r.qty.text),
                  'unit_price': parseNumber(r.price.text),
                }
            ]);
          }
        }
      } else {
        final customerId =
            _isNew ? await _findOrCreateCustomer(client) : widget.customerId!;

        final entry = await client
            .from('ledger_entries')
            .insert({
              'customer_id': customerId,
              'kind': 'debt',
              'amount': amount,
              'note': note.isEmpty ? null : note,
            })
            .select('id')
            .single();

        if (used.isNotEmpty) {
          await client.from('entry_items').insert([
            for (final r in used)
              {
                'entry_id': entry['id'],
                'product': r.product.text.trim(),
                'quantity': parseNumber(r.qty.text),
                'unit_price': parseNumber(r.price.text),
              }
          ]);
        }
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      _fail('تعذر الحفظ، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _fail(String message) => setState(() => _error = message);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = _isEdit
        ? 'تعديل العملية #${widget.editing!.invoiceNo}'
        : (_isNew ? 'عميل جديد' : 'دين جديد');

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isNew) ...[
            TextField(
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم العميل',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف (اختياري)',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
          ] else
            Text(widget.customerName ?? '',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Сумма: вручную, либо автоматически из позиций
          if (_hasItems)
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'المبلغ (محسوب من الأصناف)',
                border: OutlineInputBorder(),
              ),
              child: Text(formatMoney(_itemsTotal),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold)),
            )
          else
            TextField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'المبلغ (دولار)',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'ملاحظة (اختياري)',
              border: OutlineInputBorder(),
            ),
          ),

          if (_showItems) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(
                  child: Text('الأصناف (اختياري)',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                TextButton.icon(
                  onPressed: _addRow,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة صنف'),
                ),
              ],
            ),
            for (final row in _rows)
              Card(
                key: ObjectKey(row),
                margin: const EdgeInsets.only(top: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row.product,
                              onChanged: (_) => setState(() {}),
                              decoration: const InputDecoration(
                                labelText: 'اسم الصنف',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeRow(row),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: row.qty,
                              onChanged: (_) => setState(() {}),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'الكمية',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: row.price,
                              onChanged: (_) => setState(() {}),
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textDirection: TextDirection.ltr,
                              decoration: const InputDecoration(
                                labelText: 'السعر',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(formatMoney(row.total),
                              textDirection: TextDirection.ltr),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],

          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isEdit ? 'حفظ التعديلات' : 'حفظ',
                      style: const TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
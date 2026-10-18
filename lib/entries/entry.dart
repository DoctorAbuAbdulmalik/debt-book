class EntryItem {
  final String product;
  final double quantity;
  final double unitPrice;

  const EntryItem({
    required this.product,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => quantity * unitPrice;

  factory EntryItem.fromMap(Map<String, dynamic> m) => EntryItem(
        product: m['product'] as String,
        quantity: double.parse(m['quantity'].toString()),
        unitPrice: double.parse(m['unit_price'].toString()),
      );
}

class Entry {
  final String id;
  final int invoiceNo;
  final String kind; // 'debt' или 'writeoff'
  final double amount;
  final String? note;
  final DateTime createdAt;
  final List<EntryItem> items;

  const Entry({
    required this.id,
    required this.invoiceNo,
    required this.kind,
    required this.amount,
    this.note,
    required this.createdAt,
    required this.items,
  });

  bool get isDebt => kind == 'debt';

  factory Entry.fromMap(Map<String, dynamic> m) => Entry(
        id: m['id'] as String,
        invoiceNo: (m['invoice_no'] as num).toInt(),
        kind: m['kind'] as String,
        amount: double.parse(m['amount'].toString()),
        note: m['note'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
        items: ((m['entry_items'] as List?) ?? [])
            .map((e) => EntryItem.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
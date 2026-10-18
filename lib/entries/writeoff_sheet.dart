import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/utils.dart';

class WriteoffSheet extends StatefulWidget {
  final String customerId;
  final double balance;

  const WriteoffSheet({
    super.key,
    required this.customerId,
    required this.balance,
  });

  @override
  State<WriteoffSheet> createState() => _WriteoffSheetState();
}

class _WriteoffSheetState extends State<WriteoffSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.parse((parseNumber(_amount.text) ?? 0).toStringAsFixed(2));

    if (amount <= 0) {
      setState(() => _error = 'الرجاء إدخال مبلغ صحيح');
      return;
    }
    if (amount > widget.balance) {
      setState(() => _error = 'المبلغ أكبر من الرصيد المستحق');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final note = _note.text.trim();
      await Supabase.instance.client.from('ledger_entries').insert({
        'customer_id': widget.customerId,
        'kind': 'writeoff',
        'amount': amount,
        'note': note.isEmpty ? null : note,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _error = 'تعذر حفظ العملية، حاول مرة أخرى');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('شطب / تسديد دين',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('الرصيد المستحق: ${formatMoney(widget.balance)}',
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.right),
          const SizedBox(height: 16),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: 'المبلغ (دولار)',
              prefixText: '\$ ',
              border: const OutlineInputBorder(),
              suffixIcon: TextButton(
                onPressed: () => _amount.text = widget.balance.toStringAsFixed(2),
                child: const Text('الكل'),
              ),
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
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('تأكيد', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
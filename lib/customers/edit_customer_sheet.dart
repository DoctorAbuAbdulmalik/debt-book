import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'customer.dart';

class EditCustomerSheet extends StatefulWidget {
  final Customer customer;

  const EditCustomerSheet({super.key, required this.customer});

  @override
  State<EditCustomerSheet> createState() => _EditCustomerSheetState();
}

class _EditCustomerSheetState extends State<EditCustomerSheet> {
  late final _name = TextEditingController(text: widget.customer.name);
  late final _phone = TextEditingController(text: widget.customer.phone ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'الرجاء إدخال اسم العميل');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;

      // Не даём переименовать в имя, которое уже занято другим клиентом
      final escaped =
          name.replaceAllMapped(RegExp(r'[%_\\]'), (m) => '\\${m[0]}');
      final duplicate = await client
          .from('customers')
          .select('id')
          .ilike('name', escaped)
          .neq('id', widget.customer.id)
          .limit(1);

      if (duplicate.isNotEmpty) {
        setState(() => _error = 'يوجد عميل آخر بنفس الاسم');
        return;
      }

      await client.from('customers').update({
        'name': name,
        'phone': phone.isEmpty ? null : phone,
      }).eq('id', widget.customer.id);

      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      setState(() => _error = 'تعذر حفظ التعديلات، حاول مرة أخرى');
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
          const Text('تعديل بيانات العميل',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'اسم العميل',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              labelText: 'رقم الهاتف (اختياري)',
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
                  : const Text('حفظ', style: TextStyle(fontSize: 18)),
            ),
          ),
        ],
      ),
    );
  }
}
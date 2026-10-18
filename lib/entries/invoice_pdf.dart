import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../core/utils.dart';
import '../customers/customer.dart';
import 'entry.dart';

/// Название, которое печатается в шапке счёта. Замените на своё.
const shopName = 'اسم المحل';

Future<pw.ThemeData> _loadTheme() async {
  final regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Regular.ttf'));
  final bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Cairo-Bold.ttf'));
  return pw.ThemeData.withFont(base: regular, bold: bold);
}

pw.PageTheme _pageTheme(pw.ThemeData theme) => pw.PageTheme(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      textDirection: pw.TextDirection.rtl,
      theme: theme,
    );

// ---------- Общие элементы ----------

pw.Widget _header(String title, String line1, String line2) {
  return pw.Column(
    children: [
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(shopName,
                  style: pw.TextStyle(
                      fontSize: 22, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(title, style: const pw.TextStyle(fontSize: 15)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(line1,
                  textDirection: pw.TextDirection.ltr,
                  style: const pw.TextStyle(fontSize: 12)),
              pw.SizedBox(height: 3),
              pw.Text(line2,
                  textDirection: pw.TextDirection.ltr,
                  style: const pw.TextStyle(fontSize: 12)),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 10),
      pw.Divider(thickness: 1.5),
      pw.SizedBox(height: 10),
    ],
  );
}

/// Пара «название: значение». Значение выводится слева направо,
/// чтобы числа и суммы не переворачивались.
pw.Widget _kv(String label, String value, {bool boldValue = false}) {
  return pw.Padding(
    padding: const pw.EdgeInsets.symmetric(vertical: 2),
    child: pw.Row(
      children: [
        pw.Text('$label: ',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.Text(value,
            textDirection: pw.TextDirection.ltr,
            style: boldValue
                ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
                : null),
      ],
    ),
  );
}

pw.Widget _customerBox(Customer c) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey500),
      borderRadius: pw.BorderRadius.circular(6),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(children: [
          pw.Text('العميل: ',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(c.name),
        ]),
        if (c.phone != null) _kv('الهاتف', c.phone!),
      ],
    ),
  );
}

pw.Widget _cell(String text,
    {int flex = 1,
    bool bold = false,
    bool ltr = false,
    pw.TextAlign align = pw.TextAlign.right,
    PdfColor? color}) {
  return pw.Expanded(
    flex: flex,
    child: pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: pw.Text(
        text,
        textAlign: align,
        textDirection: ltr ? pw.TextDirection.ltr : null,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: color,
        ),
      ),
    ),
  );
}

pw.Widget _tableHeader(List<(String, int)> columns) {
  return pw.Container(
    color: PdfColors.grey300,
    child: pw.Row(
      children: [
        for (final c in columns)
          _cell(c.$1, flex: c.$2, bold: true, align: pw.TextAlign.center),
      ],
    ),
  );
}

pw.Widget _rowWrap(pw.Widget row) {
  return pw.Container(
    decoration: const pw.BoxDecoration(
      border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
    ),
    child: row,
  );
}

/// Блок итога, прижатый к левому краю
pw.Widget _totalBox(String label, String value) {
  return pw.Align(
    alignment: pw.Alignment.centerLeft,
    child: pw.Container(
      width: 230,
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Text(value,
              textDirection: pw.TextDirection.ltr,
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ),
  );
}

pw.Widget _signatures() {
  pw.Widget line(String label) => pw.Column(
        children: [
          pw.Container(width: 140, height: 1, color: PdfColors.grey600),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 11)),
        ],
      );

  return pw.Padding(
    padding: const pw.EdgeInsets.only(top: 50),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [line('توقيع المستلم'), line('توقيع البائع')],
    ),
  );
}

// ---------- Счёт по одной операции ----------

Future<void> printInvoice(Customer c, Entry e, double balance) async {
  final theme = await _loadTheme();
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageTheme: _pageTheme(theme),
      build: (ctx) => [
        _header(
          e.isDebt ? 'فاتورة دين' : 'إيصال شطب / تسديد',
          'No: ${e.invoiceNo}',
          formatDate(e.createdAt),
        ),
        _customerBox(c),
        pw.SizedBox(height: 16),

        if (e.items.isNotEmpty) ...[
          _tableHeader(
              [('الصنف', 4), ('الكمية', 1), ('السعر', 2), ('المجموع', 2)]),
          for (final it in e.items)
            _rowWrap(pw.Row(children: [
              _cell(it.product, flex: 4),
              _cell(formatQty(it.quantity),
                  flex: 1, ltr: true, align: pw.TextAlign.center),
              _cell(formatMoney(it.unitPrice),
                  flex: 2, ltr: true, align: pw.TextAlign.center),
              _cell(formatMoney(it.total),
                  flex: 2, ltr: true, align: pw.TextAlign.center),
            ])),
        ] else ...[
          _tableHeader([('البيان', 4), ('المبلغ', 2)]),
          _rowWrap(pw.Row(children: [
            _cell(e.note ?? (e.isDebt ? 'دين' : 'شطب / تسديد'), flex: 4),
            _cell(formatMoney(e.amount),
                flex: 2, ltr: true, align: pw.TextAlign.center),
          ])),
        ],

        if (e.items.isNotEmpty && e.note != null) ...[
          pw.SizedBox(height: 8),
          pw.Text('ملاحظة: ${e.note}'),
        ],

        _totalBox(e.isDebt ? 'مبلغ الدين' : 'المبلغ المشطوب',
            formatMoney(e.amount)),
        _totalBox('الرصيد المستحق', formatMoney(balance)),
        _signatures(),
      ],
    ),
  );

  await Printing.layoutPdf(
    name: 'invoice-${e.invoiceNo}',
    onLayout: (_) => doc.save(),
  );
}

// ---------- Выписка по клиенту ----------

Future<void> printStatement(Customer c, List<Entry> entries) async {
  final theme = await _loadTheme();
  final doc = pw.Document();

  // В истории операции идут от новых к старым, а в выписке нужен
  // хронологический порядок с нарастающим остатком
  final ordered = [...entries]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  var running = 0.0;
  final rows = <pw.Widget>[];
  for (final e in ordered) {
    running += e.isDebt ? e.amount : -e.amount;
    rows.add(_rowWrap(pw.Row(children: [
      _cell(formatDate(e.createdAt),
          flex: 3, ltr: true, align: pw.TextAlign.center),
      _cell('${e.invoiceNo}', flex: 1, ltr: true, align: pw.TextAlign.center),
      _cell(
        '${e.isDebt ? 'دين' : 'شطب / تسديد'}${e.note == null ? '' : ' - ${e.note}'}',
        flex: 4,
      ),
      _cell('${e.isDebt ? '+' : '-'} ${formatMoney(e.amount)}',
          flex: 2, ltr: true, align: pw.TextAlign.center),
      _cell(formatMoney(running),
          flex: 2, ltr: true, align: pw.TextAlign.center),
    ])));
  }

  doc.addPage(
    pw.MultiPage(
      pageTheme: _pageTheme(theme),
      header: (ctx) => ctx.pageNumber == 1
          ? pw.SizedBox()
          : pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Text('$shopName - كشف حساب ${c.name}',
                  style: const pw.TextStyle(fontSize: 10)),
            ),
      footer: (ctx) => pw.Align(
        alignment: pw.Alignment.center,
        child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}',
            textDirection: pw.TextDirection.ltr,
            style: const pw.TextStyle(fontSize: 10)),
      ),
      build: (ctx) => [
        _header(
          'كشف حساب',
          formatDate(DateTime.now()),
          '',
        ),
        _customerBox(c),
        pw.SizedBox(height: 16),
        _tableHeader([
          ('التاريخ', 3),
          ('الرقم', 1),
          ('البيان', 4),
          ('المبلغ', 2),
          ('الرصيد', 2),
        ]),
        ...rows,
        _totalBox('الرصيد المستحق', formatMoney(c.balance)),
      ],
    ),
  );

  await Printing.layoutPdf(
    name: 'statement-${c.name}',
    onLayout: (_) => doc.save(),
  );
}
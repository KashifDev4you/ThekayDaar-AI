// contract_pdf_generator.dart
//
// Official contract PDF for Thekaydaar.pk:
//  • Bordered legal-document design (amber + navy frames, e-STAMP banner)
//  • Red rotated CONFIDENTIAL stamp on every page
//  • Full parties block (CNIC / phone / address)
//  • Complete project conditions: WHAT IS INCLUDED, what is EXCLUDED,
//    and client-material (labour-only) items — every single item listed
//  • Payment milestones, escrow breakdown, timeline, signatures + QR
//
// FONTS: bundled TTFs (Poppins for Latin, Jameel Noori for Urdu script)
// are loaded via rootBundle, so every word typed into the contract —
// including Urdu — actually renders. The default Helvetica font cannot
// draw Arabic-script glyphs, which is why words used to go missing.

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'package:ali_app/model/contract_model.dart';

class ContractPdfGenerator {
  // ── Brand palette (matches the app) ────────────────────────────────
  static const PdfColor _navy = PdfColor.fromInt(0xFF0E3B2E);
  static const PdfColor _amber = PdfColor.fromInt(0xFFC9A227);
  static const PdfColor _cream = PdfColor.fromInt(0xFFF7F5EF);
  static const PdfColor _green = PdfColor.fromInt(0xFF10704A);
  static const PdfColor _red = PdfColor.fromInt(0xFFB3261E);
  static const PdfColor _grey = PdfColor.fromInt(0xFF6B7280);
  static const PdfColor _line = PdfColor.fromInt(0xFFD6D3CB);

  // ── Fonts (loaded once, cached for every later build) ──────────────
  static pw.Font? _fReg;
  static pw.Font? _fSemi;
  static pw.Font? _fBold;
  static pw.Font? _fUrdu;

  static Future<void> _ensureFonts() async {
    if (_fReg != null) return;
    _fReg = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins/Poppins-Regular.ttf'));
    _fSemi = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins/Poppins-SemiBold.ttf'));
    _fBold = pw.Font.ttf(await rootBundle.load('assets/fonts/Poppins/Poppins-Bold.ttf'));
    _fUrdu = pw.Font.ttf(await rootBundle.load('assets/fonts/Jameel-Noori/Jameel-Noori.ttf'));
  }

  // ── Script detection + text helpers ────────────────────────────────
  static final RegExp _urduRe =
      RegExp(r'[\u0600-\u06FF\u0750-\u077F\uFB50-\uFDFF\uFE70-\uFEFF]');

  static bool _isUrdu(String s) => _urduRe.hasMatch(s);

  static pw.TextStyle _ts({
    double size = 9.5,
    bool bold = false,
    bool semi = false,
    PdfColor? color,
    bool urdu = false,
  }) =>
      pw.TextStyle(
        font: urdu ? _fUrdu : (bold ? _fBold : (semi ? _fSemi : _fReg)),
        fontSize: size,
        color: color,
      );

  /// Renders any string with the correct font — Urdu strings automatically
  /// switch to Jameel Noori + RTL so no word ever disappears.
  static pw.Widget _text(
    String s, {
    double size = 9.5,
    bool bold = false,
    bool semi = false,
    PdfColor? color,
  }) {
    if (s.trim().isEmpty) s = '—';
    final urdu = _isUrdu(s);
    return pw.Text(
      s,
      style: _ts(size: size, bold: bold, semi: semi, color: color, urdu: urdu),
      textAlign: urdu ? pw.TextAlign.right : pw.TextAlign.left,
      textDirection: urdu ? pw.TextDirection.rtl : pw.TextDirection.ltr,
    );
  }

  // ── Entry points ───────────────────────────────────────────────────
  static Future<pw.Document> generate(ContractModel contract) async {
    await _ensureFonts();

    final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: _fReg!, bold: _fBold!),
    );

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(26, 26, 26, 26),
        header: (context) => _pageHeader(contract),
        footer: (context) => _pageFooter(context, contract),
        build: (context) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _partiesSection(contract),
              pw.SizedBox(height: 10),
              _detailsStrip(contract),
              if (contract.projectBriefDescription.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                _briefSection(contract),
              ],
              pw.SizedBox(height: 12),
              _includedSection(contract),
              pw.SizedBox(height: 12),
              _excludedSection(contract),
              pw.SizedBox(height: 12),
              _clientMaterialSection(contract),
              if (contract.thekaydaarRequirements.isNotEmpty) ...[
                pw.SizedBox(height: 12),
                _requirementsSection(contract),
              ],
              pw.SizedBox(height: 12),
              _milestonesSection(contract),
              pw.SizedBox(height: 12),
              _escrowSection(contract),
              pw.SizedBox(height: 12),
              _conditionsSection(contract),
              pw.SizedBox(height: 14),
              _signatureSection(contract),
              pw.SizedBox(height: 12),
              _verificationSection(contract),
            ],
          ),
        ],
      ),
    );

    return doc;
  }

  static Future<void> shareContractPdf({required ContractModel contract}) async {
    final doc = await generate(contract);
    final bytes = await doc.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'Thekaydaar_Contract_${contract.contractId}.pdf',
    );
  }

  static Future<void> previewContractPdf({required ContractModel contract}) async {
    final doc = await generate(contract);
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  // ── Page header — branding band + CONFIDENTIAL stamp (every page) ──
  static pw.Widget _pageHeader(ContractModel contract) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _amber, width: 1.4),
      ),
      child: pw.Column(
        children: [
          // Navy branding band
          pw.Container(
            color: _navy,
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('THEKAYDAAR.PK',
                        style: pw.TextStyle(
                            font: _fBold,
                            color: PdfColors.white,
                            fontSize: 17,
                            letterSpacing: 1.5)),
                    pw.SizedBox(height: 2),
                    pw.Text('Construction Contractor Marketplace',
                        style: pw.TextStyle(font: _fReg, color: _amber, fontSize: 8)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('DIGITAL WORK AGREEMENT',
                        style: pw.TextStyle(
                            font: _fSemi, color: PdfColors.white, fontSize: 10)),
                    pw.SizedBox(height: 2),
                    pw.Text('Contract #: ${contract.contractId}',
                        style: pw.TextStyle(font: _fReg, color: PdfColors.white, fontSize: 7.5)),
                  ],
                ),
              ],
            ),
          ),
          // e-STAMP strip + confidential stamp
          pw.Container(
            color: _cream,
            padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'e-STAMP • DIGITALLY SIGNED AGREEMENT • THEKAYDAAR.PK VERIFIED',
                  style: pw.TextStyle(font: _fSemi, fontSize: 7.5, color: _navy, letterSpacing: 0.8),
                ),
                pw.Transform.rotate(
                  angle: -0.10,
                  child: pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: _red, width: 1.3),
                      borderRadius: pw.BorderRadius.circular(2),
                    ),
                    child: pw.Text(
                      'CONFIDENTIAL',
                      style: pw.TextStyle(
                          font: _fBold, fontSize: 8, color: _red, letterSpacing: 1.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Page footer — border rule, contract id, page numbers ───────────
  static pw.Widget _pageFooter(pw.Context ctx, ContractModel contract) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: _amber, width: 1)),
      ),
      padding: const pw.EdgeInsets.only(top: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'Contract #${contract.contractId} • CONFIDENTIAL — for the named parties only',
            style: pw.TextStyle(font: _fReg, fontSize: 7, color: _grey),
          ),
          pw.Text(
            'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(font: _fSemi, fontSize: 7.5, color: _navy),
          ),
        ],
      ),
    );
  }

  // ── Section scaffolding ────────────────────────────────────────────
  static pw.Widget _sectionTitle(String text) => pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: pw.BoxDecoration(
          color: _navy,
          borderRadius: pw.BorderRadius.circular(3),
        ),
        child: pw.Text(text,
            style: pw.TextStyle(
                font: _fBold, color: PdfColors.white, fontSize: 10.5, letterSpacing: 0.6)),
      );

  static pw.Widget _sectionBox({
    required String title,
    required List<pw.Widget> children,
  }) =>
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _navy, width: 1.1),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _sectionTitle(title),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      );

  // ── Parties & legal identity ───────────────────────────────────────
  static pw.Widget _partiesSection(ContractModel contract) {
    final lt = contract.legalTerms;
    return _sectionBox(
      title: 'PARTIES & LEGAL IDENTITY',
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: _partyBlock(
                'CLIENT',
                contract.clientName,
                lt.clientCnic,
                lt.clientPhone,
                lt.clientAddress,
                'Address',
              ),
            ),
            pw.Container(width: 1, height: 86, color: _line),
            pw.SizedBox(width: 12),
            pw.Expanded(
              child: _partyBlock(
                'CONTRACTOR (THEKAYDAAR)',
                contract.contractorName,
                lt.contractorCnic,
                lt.contractorPhone,
                lt.contractorAddress,
                'Site / Work Address',
              ),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _partyBlock(
    String label,
    String name,
    String cnic,
    String phone,
    String address,
    String addressLabel,
  ) =>
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: _fSemi, fontSize: 8, color: _grey, letterSpacing: 0.8)),
          pw.SizedBox(height: 2),
          _text(name, size: 12.5, bold: true, color: _navy),
          pw.SizedBox(height: 3),
          _kv('CNIC', cnic),
          _kv('Phone', phone),
          pw.SizedBox(height: 1),
          pw.Text(addressLabel, style: pw.TextStyle(font: _fReg, fontSize: 7.5, color: _grey)),
          _text(address, size: 9),
        ],
      );

  static pw.Widget _kv(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
                width: 38,
                child: pw.Text('$k:', style: pw.TextStyle(font: _fReg, fontSize: 8.5, color: _grey))),
            pw.Expanded(child: _text(v, size: 9)),
          ],
        ),
      );

  // ── Details strip (type / status / value / dates) ──────────────────
  static pw.Widget _detailsStrip(ContractModel contract) {
    pw.Widget cell(String label, String value) => pw.Expanded(
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: pw.BoxDecoration(
              color: _cream,
              border: pw.Border.all(color: _line, width: 0.6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(label,
                    style: pw.TextStyle(font: _fReg, fontSize: 7, color: _grey, letterSpacing: 0.5)),
                pw.SizedBox(height: 2),
                _text(value, size: 9.5, semi: true, color: _navy),
              ],
            ),
          ),
        );

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        cell('PROJECT TYPE', contract.projectType),
        pw.SizedBox(width: 6),
        cell('STATUS', _contractStatus(contract.status)),
        pw.SizedBox(width: 6),
        cell('TOTAL VALUE', 'Rs. ${contract.totalAmount.toStringAsFixed(0)}'),
        pw.SizedBox(width: 6),
        cell('START — END',
            '${_fmt(contract.expectedStartDate)} — ${_fmt(contract.expectedEndDate)}'),
      ],
    );
  }

  // ── Project brief ──────────────────────────────────────────────────
  static pw.Widget _briefSection(ContractModel contract) => _sectionBox(
        title: 'PROJECT BRIEF DESCRIPTION',
        children: [_text(contract.projectBriefDescription, size: 9.5)],
      );

  // ── WHAT IS INCLUDED — the heart of the conditions ─────────────────
  static pw.Widget _includedSection(ContractModel contract) {
    final rows = contract.scopeOfWork.where((s) => s.included).toList();
    return _sectionBox(
      title: 'CONDITIONS — WHAT IS INCLUDED IN THIS PROJECT (THEKAYDAAR KI ZIMMEDARI)',
      children: [
        if (rows.isEmpty)
          _text('(No included items recorded.)', size: 9, color: _grey)
        else ...[
          pw.Table(
            border: pw.TableBorder.all(color: _line, width: 0.6),
            columnWidths: const {
              0: pw.FixedColumnWidth(22),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(3.2),
              3: pw.FixedColumnWidth(64),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _cream),
                children: [
                  _th('#'),
                  _th('Task / Deliverable'),
                  _th('Details'),
                  _th('Timeline'),
                ],
              ),
              ...rows.asMap().entries.map(
                    (e) => pw.TableRow(
                      children: [
                        _td('${e.key + 1}', alignCenter: true),
                        _tdBold(e.value.task),
                        _td(e.value.description),
                        _td(
                          e.value.timelineDays > 0 ? '${e.value.timelineDays} days' : '—',
                          alignCenter: true,
                        ),
                      ],
                    ),
                  ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Only the items listed above are part of this contract. Payment follows the milestone schedule below.',
            style: pw.TextStyle(font: _fReg, fontSize: 7.5, color: _grey),
          ),
        ],
      ],
    );
  }

  // ── What is NOT included ───────────────────────────────────────────
  static pw.Widget _excludedSection(ContractModel contract) {
    final rows = contract.scopeOfWork.where((s) => s.excluded).toList();
    return _sectionBox(
      title: 'NOT INCLUDED IN THIS PROJECT (IS CONTRACT KA HISSA NAHI)',
      children: [
        if (rows.isEmpty)
          _text('(No exclusions — everything agreed is listed above.)', size: 9, color: _grey)
        else ...[
          pw.Text(
            'The following items are explicitly OUT of scope. If needed later, they will be agreed separately with separate charges.',
            style: pw.TextStyle(font: _fReg, fontSize: 8, color: _grey, fontStyle: pw.FontStyle.italic),
          ),
          pw.SizedBox(height: 6),
          ...rows.asMap().entries.map((e) => _bulletRow(e.key + 1, e.value.task, _red)),
        ],
      ],
    );
  }

  // ── Client-material (labour only) items ─────────────────────────────
  static pw.Widget _clientMaterialSection(ContractModel contract) {
    final rows = contract.scopeOfWork.where((s) => s.clientMaterial).toList();
    return _sectionBox(
      title: 'CLIENT MATERIAL — LABOUR BY THEKAYDAAR, MATERIAL BY CLIENT',
      children: [
        if (rows.isEmpty)
          _text('(No client-material items.)', size: 9, color: _grey)
        else
          ...rows.asMap().entries.map((e) => _bulletRow(e.key + 1, e.value.task, _amber)),
      ],
    );
  }

  // ── Thekaydaar requirements ────────────────────────────────────────
  static pw.Widget _requirementsSection(ContractModel contract) {
    final entries = contract.thekaydaarRequirements.entries.toList();
    return _sectionBox(
      title: 'THEKAYDAAR REQUIREMENTS & TERMS',
      children: [
        ...entries.map(
          (e) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 2),
                  width: 5,
                  height: 5,
                  decoration: const pw.BoxDecoration(color: _navy, shape: pw.BoxShape.circle),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.SizedBox(width: 120, child: _text(e.key, size: 9, semi: true)),
                      pw.Expanded(child: _text(e.value, size: 9)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Payment milestones ─────────────────────────────────────────────
  static pw.Widget _milestonesSection(ContractModel contract) {
    return _sectionBox(
      title: 'PAYMENT MILESTONES',
      children: [
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(3.4),
            1: pw.FixedColumnWidth(38),
            2: pw.FixedColumnWidth(76),
            3: pw.FixedColumnWidth(88),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cream),
              children: [
                _th('Milestone'),
                _th('%'),
                _th('Amount (Rs.)'),
                _th('Status'),
              ],
            ),
            ...contract.milestones.map(
              (m) => pw.TableRow(
                children: [
                  _tdBold(m.title),
                  _td('${m.percent.toStringAsFixed(0)}%', alignCenter: true),
                  _td(m.amount.toStringAsFixed(0), alignCenter: true),
                  _td(_milestoneStatus(m.status), alignCenter: true),
                ],
              ),
            ),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: _cream),
              children: [
                _tdBold('TOTAL CONTRACT VALUE'),
                _td(''),
                _tdBold(contract.totalAmount.toStringAsFixed(0), alignCenter: true),
                _td(''),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── Escrow breakdown ───────────────────────────────────────────────
  static pw.Widget _escrowSection(ContractModel contract) {
    final total = contract.totalAmount;
    final rate = contract.commissionRate;
    final commission = total * rate;
    final payout = total - commission;

    return _sectionBox(
      title: 'ESCROW PAYMENT BREAKDOWN',
      children: [
        _moneyRow('Total Contract Amount', 'Rs. ${total.toStringAsFixed(0)}', false),
        _moneyRow(
          'Platform Fee (${(rate * 100).toStringAsFixed(1)}%)',
          '- Rs. ${commission.toStringAsFixed(0)}',
          false,
          color: _red,
        ),
        pw.Divider(color: _line, height: 10),
        _moneyRow('Contractor Payout (released on completion)', 'Rs. ${payout.toStringAsFixed(0)}', true),
        pw.SizedBox(height: 4),
        pw.Text(
          'Payment is held securely by Thekaydaar.pk (escrow) and released to the contractor after admin verification.',
          style: pw.TextStyle(font: _fReg, fontSize: 7.5, color: _grey),
        ),
      ],
    );
  }

  static pw.Widget _moneyRow(String label, String value, bool bold, {PdfColor? color}) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          _text(label, size: bold ? 10 : 9.5, semi: bold, color: color),
          _text(value, size: bold ? 10 : 9.5, bold: bold, color: color ?? _navy),
        ],
      );

  // ── Essential conditions (short + practical) ────────────────────────
  static pw.Widget _conditionsSection(ContractModel contract) {
    final lt = contract.legalTerms;

    final conditions = <String>[
      'Payment is released strictly per the milestone schedule above, through Thekaydaar.pk escrow. No milestone payment is released until the corresponding work is approved by the Client in the app.',
      'Only the items listed under "WHAT IS INCLUDED IN THIS PROJECT" are the Contractor\'s responsibility. Anything under "NOT INCLUDED" requires a separate written agreement and separate charges.',
      if (lt.delayPenaltyPercent > 0)
        'If the Contractor misses the agreed End Date, ${lt.delayPenaltyPercent.toStringAsFixed(0)}% of the next unpaid milestone is deducted per day of delay, unless the delay is caused by the Client or circumstances beyond the Contractor\'s control.',
      if (lt.warrantyDays > 0)
        'The Contractor provides a free-repair / defect-liability warranty of ${lt.warrantyDays} day(s) from final payment, covering defects from the Contractor\'s workmanship.',
      'Any change to scope, timeline, or payment after signing must be re-agreed in writing by both parties inside the app.',
      'In case of dispute, both parties first attempt resolution through Thekaydaar.pk\'s in-app support process before any external legal remedy.',
    ];

    return _sectionBox(
      title: 'TERMS & CONDITIONS',
      children: [
        ...conditions.asMap().entries.map(
              (e) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 18,
                      child: pw.Text('${e.key + 1}.',
                          style: pw.TextStyle(font: _fSemi, fontSize: 8.5, color: _navy)),
                    ),
                    pw.Expanded(
                      child: _text(e.value, size: 8.5),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  // ── Signatures ─────────────────────────────────────────────────────
  static pw.Widget _signatureSection(ContractModel contract) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _amber, width: 1.6),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Container(
            width: double.infinity,
            color: _cream,
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: pw.Text('DIGITAL SIGNATURES',
                style: pw.TextStyle(
                    font: _fBold, fontSize: 10.5, color: _navy, letterSpacing: 0.6)),
          ),
          pw.Padding(
            padding: const pw.EdgeInsets.all(12),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(child: _signatureBlock('CLIENT', contract.clientSignature)),
                pw.SizedBox(width: 16),
                pw.Expanded(child: _signatureBlock('CONTRACTOR', contract.contractorSignature)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _signatureBlock(String role, ContractSignature sig) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(role, style: pw.TextStyle(font: _fSemi, fontSize: 8, color: _grey, letterSpacing: 0.8)),
          pw.SizedBox(height: 4),
          _text(sig.fullName.isNotEmpty ? sig.fullName : '—', size: 13, bold: true, color: _navy),
          pw.SizedBox(height: 4),
          if (sig.agreed)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                color: const PdfColor.fromInt(0xFFE3F4EC),
                borderRadius: pw.BorderRadius.circular(3),
                border: pw.Border.all(color: _green, width: 0.7),
              ),
              child: pw.Text('DIGITALLY SIGNED',
                  style: pw.TextStyle(font: _fBold, fontSize: 7, color: _green)),
            )
          else
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: pw.BoxDecoration(
                borderRadius: pw.BorderRadius.circular(3),
                border: pw.Border.all(color: _red, width: 0.7),
              ),
              child: pw.Text('NOT SIGNED', style: pw.TextStyle(font: _fBold, fontSize: 7, color: _red)),
            ),
          if (sig.timestamp != null) ...[
            pw.SizedBox(height: 3),
            pw.Text('Signed on ${_fmt(sig.timestamp)}',
                style: pw.TextStyle(font: _fReg, fontSize: 7.5, color: _grey)),
          ],
        ],
      );

  // ── Verification + QR ──────────────────────────────────────────────
  static pw.Widget _verificationSection(ContractModel contract) {
    final verifyLink = 'https://thekaydaar.pk/verify/${contract.contractId}';
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Expanded(
          child: pw.Text(
            'This document was generated electronically by Thekaydaar.pk and reflects the agreement '
            'digitally signed by both parties inside the app. Scan the QR code to verify authenticity.',
            style: pw.TextStyle(font: _fReg, fontSize: 7.5, color: _grey),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: verifyLink,
          width: 58,
          height: 58,
        ),
      ],
    );
  }

  // ── Small building blocks ──────────────────────────────────────────
  static pw.Widget _bulletRow(int index, String text, PdfColor dotColor) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(
              width: 18,
              child: pw.Text('$index.',
                  style: pw.TextStyle(font: _fSemi, fontSize: 8.5, color: dotColor)),
            ),
            pw.Expanded(child: _text(text, size: 9)),
          ],
        ),
      );

  static pw.Widget _th(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: pw.Text(text,
            style: pw.TextStyle(font: _fSemi, fontSize: 8.5, color: _navy)),
      );

  static pw.Widget _td(String text, {bool alignCenter = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: _text(text, size: 8.8),
      );

  static pw.Widget _tdBold(String text, {bool alignCenter = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(5),
        child: _text(text, size: 8.8, semi: true),
      );

  static String _milestoneStatus(String s) => switch (s) {
        'approved' => 'APPROVED',
        'awaiting_approval' => 'AWAITING',
        'paid' => 'PAID',
        _ => 'PENDING',
      };

  static String _contractStatus(String s) => switch (s) {
        'pending_signatures' => 'Pending Signatures',
        'active' => 'Active',
        'work_completed' => 'Work Completed',
        'payment_submitted' => 'Payment Submitted',
        'completed' => 'Completed',
        'disputed' => 'Disputed',
        'cancelled' => 'Cancelled',
        _ => s,
      };

  static String _fmt(DateTime? d) =>
      d == null ? 'TBD' : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}

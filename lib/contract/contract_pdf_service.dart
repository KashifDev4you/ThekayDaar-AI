// contract_pdf_service.dart
//
// Generates a professional, bordered PDF of a signed contract — like a real
// legal/agreement document. Includes app branding header, parties + legal
// identity block, scope-of-work checklist (done/pending, no per-task cost),
// milestone/payment table, full Terms & Conditions clause, signature block,
// and a QR code that links back to the live contract inside the app.
//
// Add these to pubspec.yaml:
//   pdf: ^3.11.1
//   printing: ^5.13.3
//
// Usage:
//   final service = ContractPdfService();
//   final file = await service.generateAndSave(contract);
//   await service.shareOrPrint(file);

import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ali_app/model/contract_model.dart';

// Brand colors — match these to your exact Navy/Amber hex codes.
final PdfColor kPdfNavy = PdfColor.fromInt(0xFF0E3B2E);
final PdfColor kPdfAmber = PdfColor.fromInt(0xFFC9A227);
final PdfColor kPdfLightGrey = PdfColor.fromInt(0xFFF7F5EF);
final PdfColor kPdfGreen = PdfColor.fromInt(0xFF10B981);

class ContractPdfService {
  // ---------------------------------------------------------------------
  // Builds the full PDF document for a given signed contract.
  // ---------------------------------------------------------------------
  Future<pw.Document> buildPdf(ContractModel contract) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(0), // we draw our own bordered frame
        header: (context) => pw.Container(),
        build: (context) => [
          // Outer decorative double-border frame — gives it a formal,
          // legal-document look rather than a plain app printout.
          pw.Container(
            margin: const pw.EdgeInsets.all(16),
            padding: const pw.EdgeInsets.all(6),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: kPdfAmber, width: 1.2),
            ),
            child: pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: kPdfNavy, width: 2.2),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Stamp paper / e-Stamp banner
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    decoration: pw.BoxDecoration(
                      color: kPdfAmber,
                      borderRadius: pw.BorderRadius.circular(4),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('e-STAMP / DIGITALLY SIGNED AGREEMENT',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: kPdfNavy)),
                        pw.Text('THEKAYDAAR.PK VERIFIED',
                            style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: kPdfNavy)),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                  _buildHeader(contract),
                  pw.SizedBox(height: 16),
                  _buildPartiesSection(contract),
                  pw.SizedBox(height: 12),
                  if (contract.projectBriefDescription.isNotEmpty) ...[                    _buildProjectBriefSection(contract),
                    pw.SizedBox(height: 12),
                  ],
                  _buildScopeTable(contract),
                  pw.SizedBox(height: 16),
                  _buildMilestoneTable(contract),
                  pw.SizedBox(height: 12),
                  _buildEscrowBreakdown(contract),
                  pw.SizedBox(height: 16),
                  _buildTimelineSection(contract),
                  pw.SizedBox(height: 16),
                  _buildTermsAndConditions(contract),
                  pw.SizedBox(height: 20),
                  _buildSignatureSection(contract),
                  pw.SizedBox(height: 20),
                  _buildFooterVerification(contract),
                ],
              ),
            ),
          ),
        ],
      ),
    );

    return doc;
  }

  // ---------------------------------------------------------------------
  // App branding header band — Navy background, app name, doc title.
  // ---------------------------------------------------------------------
  pw.Widget _buildHeader(ContractModel contract) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: pw.BoxDecoration(
        color: kPdfNavy,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('THEKAYDAAR.PK',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.2)),
              pw.SizedBox(height: 2),
              pw.Text('Construction Contractor Marketplace',
                  style: pw.TextStyle(color: kPdfAmber, fontSize: 9)),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text('DIGITAL WORK AGREEMENT',
                  style: pw.TextStyle(
                      color: PdfColors.white,
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold)),
              pw.Text('Contract ID: ${contract.contractId}',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
              pw.Text('Generated: ${_formatDate(DateTime.now())}',
                  style: const pw.TextStyle(color: PdfColors.white, fontSize: 8)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Parties section — now includes full legal identity (CNIC, phone,
  // address) for both sides, pulled from contract.legalTerms. This is the
  // block that makes the PDF usable as an actual reference document if a
  // dispute ever needs to be resolved outside the app.
  // ---------------------------------------------------------------------
  pw.Widget _buildPartiesSection(ContractModel contract) {
    final lt = contract.legalTerms;
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: kPdfLightGrey,
        borderRadius: pw.BorderRadius.circular(6),
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _partyBlock('CLIENT', contract.clientName, lt.clientCnic, lt.clientPhone, lt.clientAddress)),
          pw.Container(width: 1, height: 90, color: PdfColors.grey400),
          pw.SizedBox(width: 16),
          pw.Expanded(child: _partyBlock('CONTRACTOR (THEKAYDAAR)', contract.contractorName, lt.contractorCnic, lt.contractorPhone, lt.contractorAddress, addressLabel: 'Site / Work Address')),
        ],
      ),
    );
  }

  pw.Widget _partyBlock(String label, String name, String cnic, String phone, String address,
      {String addressLabel = 'Address'}) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(label,
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 3),
        pw.Text(name, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text('CNIC: ${cnic.isEmpty ? "—" : cnic}', style: const pw.TextStyle(fontSize: 9)),
        pw.Text('Phone: ${phone.isEmpty ? "—" : phone}', style: const pw.TextStyle(fontSize: 9)),
        pw.SizedBox(height: 2),
        pw.Text('$addressLabel:', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.Text(address.isEmpty ? "—" : address, style: const pw.TextStyle(fontSize: 9)),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Scope of work — CHANGED: no per-task cost column anymore. Instead each
  // task shows a DONE / PENDING status, since payment happens only at the
  // milestone level (see _buildMilestoneTable below), not per task.
  // ---------------------------------------------------------------------
  pw.Widget _buildScopeTable(ContractModel contract) {
    final rows = contract.scopeOfWork.where((s) => s.included).toList();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('SCOPE OF WORK'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: kPdfNavy),
              children: [
                _tableHeaderCell('Task / Deliverable'),
                _tableHeaderCell('Timeline'),
                _tableHeaderCell('Status'),
              ],
            ),
            ...rows.map((s) => pw.TableRow(children: [
                  _tableCell(s.task),
                  _tableCell(s.timelineDays > 0 ? '${s.timelineDays} days' : '—'),
                  pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      s.isDone ? 'DONE' : 'PENDING',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: s.isDone ? kPdfGreen : PdfColors.orange800,
                      ),
                    ),
                  ),
                ])),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Note: task status reflects contractor-reported progress only. Payment release is governed solely by the milestone schedule below.',
          style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
        ),
      ],
    );
  }

  pw.Widget _buildMilestoneTable(ContractModel contract) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('PAYMENT MILESTONES'),
        pw.SizedBox(height: 6),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
          columnWidths: const {
            0: pw.FlexColumnWidth(3),
            1: pw.FlexColumnWidth(1),
            2: pw.FlexColumnWidth(2),
            3: pw.FlexColumnWidth(2),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: kPdfNavy),
              children: [
                _tableHeaderCell('Milestone'),
                _tableHeaderCell('%'),
                _tableHeaderCell('Amount (Rs.)'),
                _tableHeaderCell('Status'),
              ],
            ),
            ...contract.milestones.map((m) => pw.TableRow(children: [
                  _tableCell(m.title),
                  _tableCell('${m.percent.toStringAsFixed(0)}%'),
                  _tableCell(m.amount.toStringAsFixed(0)),
                  _tableCell(m.status.replaceAll('_', ' ').toUpperCase()),
                ])),
            pw.TableRow(
              decoration: pw.BoxDecoration(color: kPdfLightGrey),
              children: [
                _tableCell('TOTAL CONTRACT VALUE', bold: true),
                _tableCell(''),
                _tableCell(contract.totalAmount.toStringAsFixed(0), bold: true),
                _tableCell(''),
              ],
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildTimelineSection(ContractModel contract) {
    return pw.Row(
      children: [
        pw.Expanded(
          child: pw.Text(
            'Start Date: ${contract.expectedStartDate != null ? _formatDate(contract.expectedStartDate!) : "TBD"}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            'End Date: ${contract.expectedEndDate != null ? _formatDate(contract.expectedEndDate!) : "TBD"}',
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Project brief description section
  // ---------------------------------------------------------------------
  pw.Widget _buildProjectBriefSection(ContractModel contract) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('PROJECT BRIEF DESCRIPTION'),
        pw.SizedBox(height: 6),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: kPdfLightGrey,
            borderRadius: pw.BorderRadius.circular(4),
            border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
          ),
          child: pw.Text(
            contract.projectBriefDescription,
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 1.4),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Escrow payment breakdown — shows total, commission, and payout
  // ---------------------------------------------------------------------
  pw.Widget _buildEscrowBreakdown(ContractModel contract) {
    final total = contract.totalAmount;
    final rate = contract.commissionRate;
    final commission = total * rate;
    final payout = total - commission;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('ESCROW PAYMENT BREAKDOWN'),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(12),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: kPdfNavy, width: 1),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Total Contract Amount', style: pw.TextStyle(fontSize: 10)),
                  pw.Text('Rs. ${total.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Platform Fee (${(rate * 100).toStringAsFixed(1)}%)', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
                  pw.Text('- Rs. ${commission.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9, color: PdfColors.red700)),
                ],
              ),
              pw.Divider(color: PdfColors.grey400, height: 12),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Contractor Payout', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: kPdfNavy)),
                  pw.Text('Rs. ${payout.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: kPdfNavy)),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'Payment is held securely by Thekaydaar.pk (escrow) and released to the contractor upon admin verification.',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // NEW: full written Terms & Conditions clause block — spells out
  // materials responsibility, delay penalty, and warranty in formal legal
  // language, plus standard boilerplate clauses every work agreement
  // needs (dispute resolution, scope changes, termination).
  // ---------------------------------------------------------------------
  pw.Widget _buildTermsAndConditions(ContractModel contract) {
    final lt = contract.legalTerms;

    final materialsText = switch (lt.materialsResponsibility) {
      'client' => 'The Client shall be responsible for procuring and supplying all materials required for the work described above.',
      'shared' => 'Materials required for the work shall be supplied jointly by the Client and the Contractor as mutually agreed for each task.',
      _ => 'The Contractor shall be responsible for procuring and supplying all materials required for the work described above.',
    };

    final delayText = lt.delayPenaltyPercent > 0
        ? 'In the event the Contractor fails to complete the work by the agreed End Date, a penalty of ${lt.delayPenaltyPercent.toStringAsFixed(0)}% of the next unpaid milestone amount shall be deducted for each day of delay, unless the delay is caused by the Client or by circumstances beyond the Contractor\'s reasonable control.'
        : 'No delay penalty clause has been applied to this agreement.';

    final warrantyText = lt.warrantyDays > 0
        ? 'The Contractor shall provide a defect-liability / free-repair warranty period of ${lt.warrantyDays} day(s) from the date of final payment, covering defects directly resulting from the Contractor\'s workmanship.'
        : 'No warranty period has been applied to this agreement.';

    final clauses = <String>[
      materialsText,
      delayText,
      warrantyText,
      'Payments shall be released strictly according to the milestone schedule above. No milestone payment shall be released until the corresponding work has been reviewed and approved by the Client within the app.',
      'Any change to the scope of work, timeline, or payment terms after signing must be agreed to in writing (via the app) by both parties.',
      'In case of a dispute, both parties agree to first attempt resolution through Thekaydaar.pk\'s in-app escalation/support process before pursuing any external legal remedy.',
      'This document, once digitally signed by both parties, constitutes a binding work agreement between the Client and the Contractor named above.',
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _sectionLabel('TERMS & CONDITIONS'),
        pw.SizedBox(height: 6),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
            borderRadius: pw.BorderRadius.circular(4),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: List.generate(clauses.length, (i) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.SizedBox(
                      width: 16,
                      child: pw.Text('${i + 1}.', style: const pw.TextStyle(fontSize: 8.5)),
                    ),
                    pw.Expanded(
                      child: pw.Text(clauses[i], style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 1.4)),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Signature block — shows both signatures with a "verified" style badge.
  // ---------------------------------------------------------------------
  pw.Widget _buildSignatureSection(ContractModel contract) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: kPdfAmber, width: 1.4),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: _signatureBlock('Client', contract.clientSignature)),
          pw.SizedBox(width: 16),
          pw.Expanded(child: _signatureBlock('Contractor', contract.contractorSignature)),
        ],
      ),
    );
  }

  pw.Widget _signatureBlock(String role, ContractSignature sig) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(role.toUpperCase(), style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 4),
        pw.Text(sig.fullName.isNotEmpty ? sig.fullName : '—',
            style: pw.TextStyle(
                fontSize: 14, fontWeight: pw.FontWeight.bold, font: pw.Font.helveticaBoldOblique())),
        pw.SizedBox(height: 4),
        if (sig.agreed)
          pw.Row(
            children: [
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: pw.BoxDecoration(
                  color: PdfColors.green100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text('DIGITALLY SIGNED',
                    style: pw.TextStyle(fontSize: 7, color: PdfColors.green900, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          )
        else
          pw.Text('Not signed', style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        if (sig.timestamp != null)
          pw.Text(_formatDate(sig.timestamp!), style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Footer with a QR code that deep-links to the live contract in the app.
  // ---------------------------------------------------------------------
  pw.Widget _buildFooterVerification(ContractModel contract) {
    final verifyLink = 'https://thekaydaar.pk/verify/${contract.contractId}';

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(
          child: pw.Text(
            'This document was generated electronically by Thekaydaar.pk and reflects the agreement digitally '
            'signed by both parties within the app. Scan the QR code to verify this contract\'s authenticity.',
            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
          ),
        ),
        pw.SizedBox(width: 12),
        pw.BarcodeWidget(barcode: pw.Barcode.qrCode(), data: verifyLink, width: 60, height: 60),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Small reusable style helpers
  // ---------------------------------------------------------------------
  pw.Widget _sectionLabel(String text) => pw.Text(
        text,
        style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: kPdfNavy, letterSpacing: 0.6),
      );

  pw.Widget _tableHeaderCell(String text) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(color: PdfColors.white, fontSize: 9, fontWeight: pw.FontWeight.bold)),
      );

  pw.Widget _tableCell(String text, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.all(6),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 9, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
      );

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  // ---------------------------------------------------------------------
  // Save PDF to device storage and return the File — call this once the
  // contract status becomes "active" (both signatures done), so the saved
  // copy always reflects the fully-signed version.
  // ---------------------------------------------------------------------
  Future<File> generateAndSave(ContractModel contract) async {
    final pdf = await buildPdf(contract);
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/contract_${contract.contractId}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<void> shareOrPrint(File file) async {
    await Printing.sharePdf(bytes: await file.readAsBytes(), filename: file.path.split('/').last);
  }

  Future<void> previewPdf(ContractModel contract) async {
    final pdf = await buildPdf(contract);
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}
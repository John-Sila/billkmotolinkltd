import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class NonVariableDocuments extends StatelessWidget {
  const NonVariableDocuments({super.key});

  Future<Uint8List> loadAssetImage(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  String buildRefCode(String documentTitle) {
    final rawWords = documentTitle.split(RegExp(r'\s+'));

    final letters = <String>[];

    for (final word in rawWords) {
      // split hyphenated words too
      final parts = word.split('-');

      for (final part in parts) {
        if (RegExp(r'^[A-Za-z]').hasMatch(part)) {
          letters.add(part[0].toUpperCase());
        }
      }
    }

    return letters.join().substring(0, letters.length > 3 ? 3 : letters.length);
  }

  Future<void> _generateStandardDocument({
    required String documentTitle,
    required String department,
    required List<pw.Widget> content,
    required List<String> stakeholders, // 'Employer', 'Employee', 'IT', 'Witness'
    String? legalDisclaimer,
  }) async {
    final companyLogo = await loadAssetImage('assets/logo.png');
    final kraLogo = await loadAssetImage('assets/kra.png');
    final sigBytes = await loadAssetImage('assets/primary_signature.png');

    final companyImage = pw.MemoryImage(companyLogo);
    final kraImage = pw.MemoryImage(kraLogo);
    final signatureImage = pw.MemoryImage(sigBytes);

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) {
          if (context.pageNumber == 1) {
            return _buildStandardHeader(companyImage, kraImage, department);
          }
          return pw.SizedBox(); // no header on other pages
        },
        footer: (context) => _buildStandardFooter(context, signatureImage, stakeholders, legalDisclaimer),
        build: (context) => [
          pw.SizedBox(height: 10),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(documentTitle.toUpperCase(), 
                style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey800)),
              pw.Text(
                "Ref: BML/${buildRefCode(documentTitle)}/${DateTime.now().year}",
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.Divider(thickness: 0.5, color: PdfColors.grey300, height: 20),
          ...content,
        ],
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  pw.Widget _buildStandardHeader(pw.MemoryImage logo, pw.MemoryImage kra, String department) {
    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Image(logo, width: 60),
                pw.SizedBox(width: 15),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text("BILLK MOTOLINK LTD", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                    pw.Text(department, style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
                  ],
                ),
              ],
            ),
            // pw.Image(kra, width: 60),
          ],
        ),
        pw.Divider(thickness: 1, height: 20, color: PdfColors.grey300),
      ],
    );
  }

  pw.Widget _buildStandardFooter(pw.Context context, pw.MemoryImage adminSig, List<String> stakeholders, String? disclaimer) {
    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5, color: PdfColors.grey300),
        pw.SizedBox(height: 10),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 180,
              child: pw.Text(
                disclaimer ?? "This document is an official record of BILLK MOTOLINK LTD and is subject to the Laws of Kenya and internal corporate policies.",
                style: pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey600,
                  fontStyle: pw.FontStyle.italic,
                ),
              ),
            ),
            pw.Text(
              "Page ${context.pageNumber} of ${context.pagesCount}",
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.Wrap(
              spacing: 20,
              children: stakeholders.map((s) => _buildSignatureLine(s)).toList(),
            ),
          ],
        ),
      ],
    );
  }

  pw.Widget _buildSignatureLine(String role) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [

        // signature line only
        pw.Container(
          width: 80,
          height: 25,
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(width: 0.6, color: PdfColors.grey800),
            ),
          ),
        ),

        pw.SizedBox(height: 4),

        // role only (no duplication of identity fields)
        pw.Text(
          role,
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey700,
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 15, bottom: 8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          // TEXT
          pw.Text(
            title.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey900,
            ),
          ),

          pw.SizedBox(height: 3),

          // FULL WIDTH UNDERLINE (aligned to text block)
          pw.Container(
            height: 0.7,
            width: double.infinity,
            color: PdfColors.blueGrey200,
          ),
        ],
      ),
    );
  }
    
  // Standardized body text for legal clauses
  pw.Widget _buildBodyText(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.justify,
        style: const pw.TextStyle(fontSize: 9, lineSpacing: 1.5),
      ),
    );
  }

  // For policy bullet points (Code of Conduct, IT Policy)
  pw.Widget _buildBulletPoint(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(left: 8, bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [

          // Bullet (drawn, not text)
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 4),
            width: 4,
            height: 4,
            decoration: const pw.BoxDecoration(
              shape: pw.BoxShape.circle,
              color: PdfColors.black,
            ),
          ),

          pw.SizedBox(width: 8),

          // Text
          pw.Expanded(
            child: pw.Text(
              text,
              style: const pw.TextStyle(
                fontSize: 9,
                lineSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPartyDetails(String title) {
    pw.Widget row(String label) {
      return pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 6),
        child: pw.Row(
          children: [
            pw.SizedBox(
              width: 60,
              child: pw.Text(label,
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
            ),
            pw.Expanded(
              child: pw.Container(
                height: 12,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blueGrey800,
            ),
          ),
          pw.SizedBox(height: 10),

          row("Name"),
          row("ID No."),
          row("Phone"),
          row("Email"),
          row("Date"),

          pw.SizedBox(height: 12),

          // Signature line
          pw.Container(
            height: 25,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(width: 0.5),
              ),
            ),
          ),

          pw.SizedBox(height: 4),

          pw.Text(
            "Signature",
            style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildKeyValue(String key, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 110,
            child: pw.Text(
              key,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(":  "),
          pw.Expanded(
            child: pw.Text(
              value.isEmpty ? "____________________" : value,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    );
  }


  // core
  void generateEmploymentContract() {
    _generateStandardDocument(
      documentTitle: "Employment Contract",
      department: "ERP - Human Resource Management",
      stakeholders: ['Employer', 'Employee'],
      legalDisclaimer:
          "This agreement is governed by the Employment Act CAP 226 (2007) Laws of Kenya. Any disputes arising shall be subject to Kenyan labor regulations.",

      content: [

        // ================= INTRO =================
        _buildSectionTitle("1. Parties to the Agreement"),
        _buildBodyText(
            "This Employment Contract is entered into between BILLK MOTOLINK LTD (hereinafter referred to as 'the Employer') "
            "and the undersigned individual (hereinafter referred to as 'the Employee')."),

        // ================= POSITION =================
        _buildSectionTitle("2. Position and Duties"),
        _buildBodyText(
            "The Employee shall serve in the position of _________________ [Position Name] and shall report directly to _________________ [Supervisor/Manager]."),
        _buildBodyText(
            "The Employee agrees to perform all duties assigned, act in the best interests of the company, and comply with all internal policies and procedures."),

        // ================= START DATE =================
        _buildSectionTitle("3. Commencement Date"),
        _buildBodyText(
            "Employment shall commence on _________________ [Start Date] and shall continue unless terminated in accordance with this agreement."),

        // ================= WORKING HOURS =================
        _buildSectionTitle("4. Working Hours"),
        _buildBodyText(
            "The Employee shall work standard business hours as defined by company policy. "
            "Any additional hours may be required depending on operational demands."),

        // ================= REMUNERATION =================
        _buildSectionTitle("5. Remuneration"),
        _buildBodyText(
            "The Employee shall receive a gross monthly salary of KES _________________ [Amount], payable at the end of each month."),
        _buildBodyText(
            "The salary may be subject to statutory deductions including PAYE, NSSF, and NHIF in accordance with Kenyan law."),
        _buildBodyText(
            "Additional incentives, bonuses, or commissions may be provided at the discretion of the Employer."),

        // ================= PROBATION =================
        _buildSectionTitle("6. Probation Period"),
        _buildBodyText(
            "The Employee shall serve a probationary period of _________________ [Duration], during which performance and suitability will be assessed."),
        _buildBodyText(
            "During probation, either party may terminate the contract with shorter notice as permitted by law."),

        // ================= LEAVE =================
        _buildSectionTitle("7. Leave Entitlement"),
        _buildBodyText(
            "The Employee shall be entitled to annual leave in accordance with company policy and statutory requirements."),
        _buildBodyText(
            "Sick leave, maternity/paternity leave, and other statutory leave shall be granted as per Kenyan labor laws."),

        // ================= CONFIDENTIALITY =================
        _buildSectionTitle("8. Confidentiality"),
        _buildBodyText(
            "The Employee shall not disclose any confidential or proprietary information obtained during the course of employment."),
        _buildBodyText(
            "This obligation shall survive termination of employment."),

        // ================= CONDUCT =================
        _buildSectionTitle("9. Code of Conduct"),
        _buildBodyText(
            "The Employee agrees to adhere to all company policies, including but not limited to code of conduct, IT usage, and safety regulations."),

        // ================= TERMINATION =================
        _buildSectionTitle("10. Termination"),
        _buildBodyText(
            "Either party may terminate this contract by providing written notice in accordance with statutory requirements or company policy."),
        _buildBodyText(
            "The Employer reserves the right to terminate employment without notice in cases of gross misconduct."),

        // ================= LIABILITY =================
        _buildSectionTitle("11. Liability"),
        _buildBodyText(
            "The Employee may be held liable for any damages, losses, or misconduct resulting from negligence or breach of company policies."),

        // ================= GOVERNING LAW =================
        _buildSectionTitle("12. Governing Law"),
        _buildBodyText(
            "This contract shall be governed and interpreted in accordance with the laws of Kenya."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("13. Acknowledgment"),
        _buildBodyText(
            "By signing this document, both parties confirm that they have read, understood, and agreed to the terms and conditions outlined in this contract."),

        // ================= DETAILS BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Employer Details")),
          ],
        ),
      ],
    );
  }

  void generateJobDescription() {
    _generateStandardDocument(
      documentTitle: "Job Description",
      department: "ERP - Human Resource Management",
      stakeholders: ['Employee', 'Employer'],
      legalDisclaimer:
          "This job description defines the minimum expected duties and responsibilities. The Employer reserves the right to modify responsibilities in line with operational requirements.",

      content: [

        // ================= ROLE IDENTIFICATION =================
        _buildSectionTitle("1. Position Overview"),
        _buildBodyText(
            "Underline the applicable fields."),
        _buildBodyText(
            "Position Title: [ Rider | Store Attendant | Customer Service Rep | IT Support | HR Assistant ]"),
        _buildBodyText(
            "Department: [ Logistics/Operations | Human Resources | Store | IT ]"),
        _buildBodyText(
            "Reports To: [ Supervisor | Manager | Department Head ]"),
        _buildBodyText(
            "Employment Type: [ Full-Time | Contractual | Part-Time | Temporary ]"),

        // ================= PURPOSE =================
        _buildSectionTitle("2. Role Purpose"),
        _buildBodyText(
            "The purpose of this role is to ensure efficient execution of assigned operational duties, contribute to organizational performance, and support the achievement of company objectives."),

        // ================= KEY RESPONSIBILITIES =================
        _buildSectionTitle("3. Key Responsibilities"),

        _buildBulletPoint(
            "Execute assigned operational tasks in accordance with company standards."),
        _buildBulletPoint(
            "Ensure timely completion of daily and weekly deliverables."),
        _buildBulletPoint(
            "Maintain accurate records and reports where applicable."),
        _buildBulletPoint(
            "Collaborate with cross-functional teams to achieve operational efficiency."),
        _buildBulletPoint(
            "Adhere to all company policies, procedures, and compliance requirements."),
        _buildBulletPoint(
            "Report anomalies, risks, or operational inefficiencies to management."),
        _buildBulletPoint(
            "Maintain professionalism in internal and external communications."),

        // ================= PERFORMANCE EXPECTATIONS =================
        _buildSectionTitle("4. Performance Expectations"),
        _buildBodyText(
            "The employee is expected to meet defined performance indicators including accuracy, timeliness, productivity, and compliance with operational procedures."),

        _buildBulletPoint(
            "Minimum performance threshold must be consistently maintained."),
        _buildBulletPoint(
            "Errors and deviations must be minimized and reported."),
        _buildBulletPoint(
            "Targets assigned by management must be achieved within set timelines."),

        // ================= AUTHORITY =================
        _buildSectionTitle("5. Decision Authority"),
        _buildBodyText(
            "The employee may make operational decisions within the scope of assigned duties but must escalate matters outside their authority to the appropriate supervisor."),

        // ================= SKILLS REQUIREMENTS =================
        _buildSectionTitle("6. Required Skills and Competencies"),
        _buildBulletPoint("Strong communication and reporting skills."),
        _buildBulletPoint("Basic technical competency relevant to role."),
        _buildBulletPoint("Ability to follow structured procedures."),
        _buildBulletPoint("Problem-solving and analytical thinking."),
        _buildBulletPoint("Time management and task prioritization."),

        // ================= WORKING CONDITIONS =================
        _buildSectionTitle("7. Working Conditions"),
        _buildBodyText(
            "The role may require working under standard office, field, or operational environments depending on assignment. Flexibility may be required based on operational demands."),

        // ================= REPORTING STRUCTURE =================
        _buildSectionTitle("8. Reporting Structure"),
        _buildBodyText(
            "The employee shall report directly to the designated supervisor and may be required to submit periodic performance reports."),

        // ================= REVIEW AND MODIFICATION =================
        _buildSectionTitle("9. Review of Role"),
        _buildBodyText(
            "This job description is subject to periodic review and may be updated to reflect organizational changes, operational needs, or performance requirements."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("10. Acknowledgment"),
        _buildBodyText(
            "By signing this document, the employee acknowledges understanding of the duties, expectations, and responsibilities outlined in this job description."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Employer Details")),
          ],
        ),
      ],
    );
  }

  // confidentialiy
  void generateNDA() {
    _generateStandardDocument(
      documentTitle: "Non-Disclosure Agreement (NDA)",
      department: "ERP - Legal & Compliance",
      stakeholders: ['Employee', 'Employer'],
      legalDisclaimer:
          "This Non-Disclosure Agreement is binding under Kenyan contract law and remains enforceable during and after the term of employment.\nThis document can be produced in a court of law.",

      content: [

        // ================= PARTIES =================
        _buildSectionTitle("1. Parties"),
        _buildBodyText(
            "This Agreement is entered into between BILLK MOTOLINK LTD (the 'Company') and the undersigned Employee."),

        // ================= PURPOSE =================
        _buildSectionTitle("2. Purpose"),
        _buildBodyText(
            "The purpose of this Agreement is to protect confidential information disclosed to the Employee during the course of employment or engagement with the Company."),

        // ================= CONFIDENTIAL INFORMATION =================
        _buildSectionTitle("3. Definition of Confidential Information"),
        _buildBodyText(
            "Confidential Information includes but is not limited to business operations, financial records, customer data, technical systems, software, internal processes, and proprietary methodologies."),

        _buildBulletPoint("Financial and payroll data"),
        _buildBulletPoint("Client and customer databases"),
        _buildBulletPoint("Software source code and system architecture"),
        _buildBulletPoint("Operational workflows and business strategies"),
        _buildBulletPoint("Internal communications and reports"),

        // ================= OBLIGATIONS =================
        _buildSectionTitle("4. Employee Obligations"),
        _buildBodyText(
            "The Employee agrees to maintain strict confidentiality and shall not disclose, reproduce, or distribute confidential information without prior written consent from the Company."),

        _buildBulletPoint("Do not share confidential data with unauthorized parties"),
        _buildBulletPoint("Use information strictly for assigned job duties"),
        _buildBulletPoint("Prevent unauthorized access to company systems"),
        _buildBulletPoint("Report any suspected data breach immediately"),

        // ================= EXCLUSIONS =================
        _buildSectionTitle("5. Exclusions"),
        _buildBodyText(
            "Confidential Information does not include information that is publicly available, independently developed, or legally obtained from third parties without restriction."),

        // ================= TERM =================
        _buildSectionTitle("6. Duration"),
        _buildBodyText(
            "This Agreement remains valid during the term of employment and continues indefinitely after termination unless otherwise agreed in writing."),

        pw.SizedBox(height: 30),

        // ================= OWNERSHIP =================
        _buildSectionTitle("7. Ownership of Information"),
        _buildBodyText(
            "All confidential information remains the exclusive property of BILLK MOTOLINK LTD. No rights or licenses are granted to the Employee except as explicitly stated."),

        // ================= BREACH =================
        _buildSectionTitle("8. Breach of Agreement"),
        _buildBodyText(
            "Any breach of this Agreement may result in disciplinary action, termination of employment, and potential legal proceedings including damages and injunctive relief."),

        // ================= RETURN OF MATERIALS =================
        _buildSectionTitle("9. Return of Materials"),
        _buildBodyText(
            "Upon termination of employment, the Employee must return all company property, documents, and data in their possession."),

        // ================= GOVERNING LAW =================
        _buildSectionTitle("10. Governing Law"),
        _buildBodyText(
            "This Agreement shall be governed by the laws of the Republic of Kenya."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("11. Acknowledgment"),
        _buildBodyText(
            "By signing this document, the Employee acknowledges full understanding and acceptance of the terms of this Non-Disclosure Agreement."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Employer Details")),
          ],
        ),
      ],
    );
  }

  void generateIPAssignment() {
    _generateStandardDocument(
      documentTitle: "Intellectual Property Assignment Agreement",
      department: "Information & Communication Technology",
      stakeholders: ['Employee', 'Executive'],
      legalDisclaimer:
          "This Agreement governs ownership of intellectual property created during employment and is enforceable under the laws of Kenya and applicable international IP frameworks.",

      content: [

        // ================= PARTIES =================
        _buildSectionTitle("1. Parties"),
        _buildBodyText(
            "This Intellectual Property Assignment Agreement is entered into between BILLK MOTOLINK LTD (the 'Company') and the undersigned Employee."),

        // ================= PURPOSE =================
        _buildSectionTitle("2. Purpose"),
        _buildBodyText(
            "The purpose of this Agreement is to define ownership rights over all intellectual property created, developed, or contributed to by the Employee during the course of employment."),

        // ================= DEFINITION =================
        _buildSectionTitle("3. Definition of Intellectual Property"),
        _buildBodyText(
            "Intellectual Property includes all inventions, software, source code, systems, designs, processes, documentation, algorithms, reports, and any other work product created during employment."),

        _buildBulletPoint("Software applications and source code"),
        _buildBulletPoint("System architectures and database designs"),
        _buildBulletPoint("Business processes and operational workflows"),
        _buildBulletPoint("Documentation, reports, and technical specifications"),
        _buildBulletPoint("Any derivative works or improvements"),

        // ================= OWNERSHIP =================
        _buildSectionTitle("4. Ownership Rights"),
        _buildBodyText(
            "All intellectual property created by the Employee during employment, whether individually or jointly, shall be the exclusive property of BILLK MOTOLINK LTD."),

        _buildBodyText(
            "The Employee hereby irrevocably assigns all rights, title, and interest in such intellectual property to the Company."),

        // ================= SCOPE =================
        _buildSectionTitle("5. Scope of Assignment"),
        _buildBodyText(
            "This assignment applies to all work created during working hours, using company resources, or related to company business, whether developed on-site or remotely."),

        // ================= PRE-EXISTING WORK =================
        _buildSectionTitle("6. Pre-Existing Intellectual Property"),
        _buildBodyText(
            "Any intellectual property owned by the Employee prior to employment remains the Employee’s property unless explicitly transferred in writing."),

        // ================= DISCLOSURE =================
        _buildSectionTitle("7. Duty to Disclose"),
        _buildBodyText(
            "The Employee agrees to promptly disclose all inventions, works, or developments that may constitute intellectual property of the Company."),

        // ================= ASSISTANCE =================
        _buildSectionTitle("8. Further Assistance"),
        _buildBodyText(
            "The Employee agrees to assist the Company in securing intellectual property rights, including patents, copyrights, or registrations, even after termination of employment."),

        // ================= MORAL RIGHTS WAIVER =================
        _buildSectionTitle("9. Moral Rights Waiver"),
        _buildBodyText(
            "To the extent permitted by law, the Employee waives any moral rights associated with the intellectual property and consents to its modification and commercial use by the Company."),

        // ================= CONFIDENTIALITY LINK =================
        _buildSectionTitle("10. Confidentiality"),
        _buildBodyText(
            "All intellectual property is subject to the terms of the Non-Disclosure Agreement signed between the parties."),

        // ================= BREACH =================
        _buildSectionTitle("11. Breach of Agreement"),
        _buildBodyText(
            "Any unauthorized use, reproduction, or distribution of company intellectual property shall constitute a material breach of this Agreement."),

        // ================= GOVERNING LAW =================
        _buildSectionTitle("12. Governing Law"),
        _buildBodyText(
            "This Agreement shall be governed by the laws of the Republic of Kenya and applicable international intellectual property laws."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("13. Acknowledgment"),
        _buildBodyText(
            "By signing this document, the Employee acknowledges and agrees that all intellectual property created during employment belongs exclusively to the Company."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Employer Details")),
          ],
        ),
      ],
    );
  }

  void generateDataProtection() {
    _generateStandardDocument(
      documentTitle: "Data Protection & Privacy Policy",
      department: "Information & Communication Technology",
      stakeholders: ['Employee', 'IT Department'],
      legalDisclaimer:
          "This Data Protection Policy is issued in compliance with applicable data protection laws including the Data Protection Act (Kenya, 2019) and internal ICT governance standards.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This policy defines how personal data, company data, and third-party data is collected, processed, stored, and protected within BILLK MOTOLINK LTD systems."),

        // ================= SCOPE =================
        _buildSectionTitle("2. Scope"),
        _buildBodyText(
            "This policy applies to all employees, contractors, IT personnel, and third parties who access or process data on behalf of the Company."),

        // ================= DATA DEFINITION =================
        _buildSectionTitle("3. Definition of Data"),
        _buildBodyText(
            "Data includes any information that can identify an individual or relate to company operations, including personal, financial, operational, and system-generated data."),

        _buildBulletPoint("Employee personal information (name, ID, contacts)"),
        _buildBulletPoint("Payroll and wage evaluation data"),
        _buildBulletPoint("Rider tracking and performance data"),
        _buildBulletPoint("Customer and vendor records"),
        _buildBulletPoint("System logs and operational analytics"),

        // ================= DATA COLLECTION =================
        _buildSectionTitle("4. Data Collection Principles"),
        _buildBodyText(
            "Data shall be collected only for legitimate business purposes and must be relevant, adequate, and limited to what is necessary for operational use."),

        _buildBulletPoint("Data must be collected lawfully and transparently"),
        _buildBulletPoint("Users must be informed of data usage purposes"),
        _buildBulletPoint("No unnecessary or excessive data collection is permitted"),

        // ================= DATA USAGE =================
        _buildSectionTitle("5. Data Usage"),
        _buildBodyText(
            "Data shall only be used for operational, administrative, legal, and business intelligence purposes within the Company."),

        _buildBulletPoint("Payroll processing and wage evaluation"),
        _buildBulletPoint("Operational tracking and performance analysis"),
        _buildBulletPoint("Compliance and auditing purposes"),
        _buildBulletPoint("System optimization and reporting"),

        pw.SizedBox(height: 30),

        // ================= ACCESS CONTROL =================
        _buildSectionTitle("6. Data Access Control"),
        _buildBodyText(
            "Access to data shall be restricted based on role, responsibility, and operational necessity."),

        _buildBulletPoint("Least privilege access must be enforced"),
        _buildBulletPoint("Unauthorized access is strictly prohibited"),
        _buildBulletPoint("Access logs may be monitored and audited"),

        // ================= DATA STORAGE =================
        _buildSectionTitle("7. Data Storage & Security"),
        _buildBodyText(
            "All data shall be securely stored using appropriate technical and organizational measures to prevent unauthorized access, loss, or alteration."),

        _buildBulletPoint("Encrypted storage where applicable"),
        _buildBulletPoint("Secure authentication mechanisms required"),
        _buildBulletPoint("Regular backups and system redundancy"),

        // ================= DATA SHARING =================
        _buildSectionTitle("8. Data Sharing"),
        _buildBodyText(
            "Data shall not be shared with unauthorized third parties unless required by law or approved by authorized management."),

        _buildBulletPoint("No external sharing without written authorization"),
        _buildBulletPoint("Government or regulatory requests must be complied with"),
        _buildBulletPoint("Third-party processors must adhere to same standards"),

        // ================= DATA BREACH =================
        _buildSectionTitle("9. Data Breach Notification"),
        _buildBodyText(
            "Any suspected or confirmed data breach must be reported immediately to the IT Department and management."),

        _buildBulletPoint("Immediate containment of breach required"),
        _buildBulletPoint("Incident must be documented and reviewed"),
        _buildBulletPoint("Affected parties may be notified where necessary"),

        // ================= RETENTION =================
        _buildSectionTitle("10. Data Retention"),
        _buildBodyText(
            "Data shall be retained only for as long as necessary for operational, legal, or regulatory requirements."),

        _buildBulletPoint("Obsolete data must be securely deleted"),
        _buildBulletPoint("Retention schedules must be enforced"),
        _buildBulletPoint("Archival must follow company policy"),

        // ================= EMPLOYEE RESPONSIBILITY =================
        _buildSectionTitle("11. Employee Responsibilities"),
        _buildBodyText(
            "Employees are responsible for ensuring data confidentiality, integrity, and availability within their scope of work."),

        _buildBulletPoint("Do not share credentials or sensitive data"),
        _buildBulletPoint("Report suspicious system activity"),
        _buildBulletPoint("Follow all IT security protocols"),

        // ================= NON-COMPLIANCE =================
        _buildSectionTitle("12. Non-Compliance"),
        _buildBodyText(
            "Violation of this policy may result in disciplinary action, termination, and/or legal consequences."),

        // ================= GOVERNING LAW =================
        _buildSectionTitle("13. Governing Law"),
        _buildBodyText(
            "This policy shall be governed by the laws of the Republic of Kenya, including the Data Protection Act (2019)."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("14. Acknowledgment"),
        _buildBodyText(
            "By signing this document, the Employee acknowledges understanding and acceptance of the Data Protection & Privacy Policy."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("IT Department Details")),
          ],
        ),
      ],
    );
  }

  // payroll
  void generateBankDetails() {
    _generateStandardDocument(
      documentTitle: "Employee Bank Details Declaration Form",
      department: "ERP - Finance & Accounting",
      stakeholders: ['Employee', 'Finance Department'],
      legalDisclaimer:
          "This document is used for payroll processing purposes only. Any falsification of banking information may result in disciplinary action and legal consequences.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This form captures verified employee banking information for the purpose of salary processing and financial disbursement."),

        // ================= EMPLOYEE DETAILS =================
        _buildSectionTitle("2. Employee Identification"),
        _buildBodyText(
            "The employee must ensure all personal details match official identification records."),

        _buildKeyValue("Full Name", ""),
        _buildKeyValue("Employee ID", ""),
        _buildKeyValue("Phone Number", ""),
        _buildKeyValue("Email Address", ""),
        _buildKeyValue("National ID / Passport", ""),

        // ================= BANK DETAILS =================
        _buildSectionTitle("3. Bank Account Information"),
        _buildBodyText(
            "The employee must provide accurate banking details. The company shall not be liable for losses resulting from incorrect information."),

        _buildKeyValue("Bank Name", ""),
        _buildKeyValue("Branch Name", ""),
        _buildKeyValue("Account Holder Name", ""),
        _buildKeyValue("Account Number", ""),
        _buildKeyValue("Swift / Branch Code", ""),

        // ================= PAYMENT INSTRUCTIONS =================
        _buildSectionTitle("4. Payment Instructions"),
        _buildBodyText(
            "Salary payments will be processed to the bank account provided above. Any changes must be submitted in writing and approved by the Payroll Department."),

        _buildBulletPoint("Payments are processed on scheduled payroll dates only."),
        _buildBulletPoint("The employee is responsible for accuracy of bank details."),
        _buildBulletPoint("Unauthorized changes will not be accepted."),

        // ================= VERIFICATION =================
        _buildSectionTitle("5. Verification & Liability"),
        _buildBodyText(
            "The employee confirms that all information provided is accurate and acknowledges responsibility for any errors or omissions."),

        _buildBodyText(
            "The Company reserves the right to verify banking information before processing payments."),

        // ================= DATA SECURITY =================
        _buildSectionTitle("6. Data Protection"),
        _buildBodyText(
            "Banking information is classified as sensitive personal data and will be handled in accordance with the Data Protection Policy."),

        // ================= DECLARATION =================
        _buildSectionTitle("7. Declaration"),
        _buildBodyText(
            "I hereby declare that the information provided is true, complete, and correct to the best of my knowledge."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Payroll Department")),
          ],
        ),
      ],
    );
  }

  void generatePayrollAcknowledgment() {
    _generateStandardDocument(
      documentTitle: "Payroll Acknowledgment Form",
      department: "ERP - Human Resource Management",
      stakeholders: ['Employee', 'Human Resource'],
      legalDisclaimer:
          "This document confirms understanding of payroll calculations, deductions, and salary disbursement procedures. It does not replace statutory employment obligations.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This document serves as formal acknowledgment by the Employee that they understand how their salary is calculated, processed, and disbursed by BILLK MOTOLINK LTD."),

        // ================= EMPLOYEE DETAILS =================
        _buildSectionTitle("2. Employee Information"),

        _buildKeyValue("Full Name", ""),
        _buildKeyValue("Employee ID", ""),
        _buildKeyValue("Department", ""),
        _buildKeyValue("Position", ""),

        // ================= PAYROLL STRUCTURE =================
        _buildSectionTitle("3. Payroll Structure Awareness"),
        _buildBodyText(
            "The Employee acknowledges that salary is computed based on gross earnings, net earnings, performance deviations, and approved deductions or additions."),

        _buildBulletPoint("Gross income represents total earnings before deductions."),
        _buildBulletPoint("Net income represents actual payable amount after deductions."),
        _buildBulletPoint("Deductions may include penalties, advances, or statutory contributions."),
        _buildBulletPoint("Additions may include bonuses, allowances, or incentives."),

        // ================= CALCULATION ACKNOWLEDGMENT =================
        _buildSectionTitle("4. Calculation Transparency"),
        _buildBodyText(
            "The Employee confirms that they understand the calculation methodology used in payroll processing, including performance-based adjustments and daily targets."),

        _buildBulletPoint("Daily targets influence final wage computation."),
        _buildBulletPoint("Performance deviations may increase or reduce earnings."),
        _buildBulletPoint("All adjustments are reflected in the official payroll system."),

        // ================= DISPUTE HANDLING =================
        _buildSectionTitle("5. Payroll Dispute Policy"),
        _buildBodyText(
            "Any discrepancies in payroll must be reported within the designated payroll review window for correction or validation."),

        _buildBulletPoint("Late disputes may not be considered."),
        _buildBulletPoint("All claims must be supported with verifiable records."),
        _buildBulletPoint("Payroll records in the system are considered authoritative."),

        // ================= DATA ACCURACY =================
        _buildSectionTitle("6. Data Accuracy Responsibility"),
        _buildBodyText(
            "The Employee acknowledges responsibility for ensuring that all attendance, task, and operational data used in payroll calculation is accurate."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("7. Formal Acknowledgment"),
        _buildBodyText(
            "By signing this document, the Employee confirms understanding and acceptance of the payroll structure, calculation logic, and disbursement process."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Payroll Department")),
          ],
        ),
      ],
    );
  }

  // policies & compliance
  void generateCodeOfConduct() {
    _generateStandardDocument(
      documentTitle: "Employee Code of Conduct",
      department: "ERP - Human Resource Management",
      stakeholders: ['Employee', 'HR Department'],
      legalDisclaimer:
          "This Code of Conduct defines mandatory behavioral, ethical, and operational standards. Violation may result in disciplinary action including termination.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This Code of Conduct establishes behavioral, ethical, and professional standards required of all employees of BILLK MOTOLINK LTD."),

        // ================= SCOPE =================
        _buildSectionTitle("2. Scope"),
        _buildBodyText(
            "This policy applies to all employees, contractors, and temporary staff across all departments and operational units."),

        // ================= PROFESSIONAL CONDUCT =================
        _buildSectionTitle("3. Professional Conduct"),

        _buildBulletPoint("Employees must act in a professional and respectful manner at all times."),
        _buildBulletPoint("Harassment, discrimination, or abusive behavior is strictly prohibited."),
        _buildBulletPoint("Employees must maintain integrity in all company dealings."),
        _buildBulletPoint("Misrepresentation of company information is prohibited."),

        // ================= WORK ETHICS =================
        _buildSectionTitle("4. Work Ethics"),

        _buildBodyText(
            "Employees are expected to perform duties diligently, honestly, and in accordance with assigned responsibilities."),

        _buildBulletPoint("No falsification of records, attendance, or performance data."),
        _buildBulletPoint("No unauthorized delegation of assigned duties."),
        _buildBulletPoint("All tasks must be completed within required timelines where applicable."),

        // ================= USE OF COMPANY RESOURCES =================
        _buildSectionTitle("5. Use of Company Resources"),

        _buildBodyText(
            "Company resources must be used strictly for business purposes unless explicitly authorized otherwise."),

        _buildBulletPoint("No misuse of vehicles, devices, or systems."),
        _buildBulletPoint("No personal exploitation of company assets."),
        _buildBulletPoint("No unauthorized access to restricted systems."),

        // ================= CONFIDENTIALITY =================
        _buildSectionTitle("6. Confidentiality & Information Handling"),

        _buildBodyText(
            "Employees must protect all confidential company information including operational data, client details, and internal systems."),

        _buildBulletPoint("No sharing of internal data externally."),
        _buildBulletPoint("No unauthorized copying or storage of company data."),
        _buildBulletPoint("Confidentiality obligations extend beyond employment period."),

        pw.SizedBox(height: 30),
        // ================= CONFLICT OF INTEREST =================
        _buildSectionTitle("7. Conflict of Interest"),

        _buildBodyText(
            "Employees must avoid situations where personal interests conflict with company interests."),

        _buildBulletPoint("No engagement in competing business activities."),
        _buildBulletPoint("No misuse of company position for personal gain."),
        _buildBulletPoint("All conflicts must be disclosed immediately."),

        // ================= DIGITAL CONDUCT =================
        _buildSectionTitle("8. Digital & System Usage"),

        _buildBodyText(
            "Employees must use company digital systems responsibly and in accordance with IT policies."),

        _buildBulletPoint("No system tampering or unauthorized access."),
        _buildBulletPoint("No installation of unapproved software."),
        _buildBulletPoint("All system activity may be monitored."),

        // ================= DISCIPLINARY ACTION =================
        _buildSectionTitle("9. Violations & Consequences"),

        _buildBodyText(
            "Violation of this Code of Conduct may result in disciplinary action depending on severity."),

        _buildBulletPoint("Verbal or written warnings"),
        _buildBulletPoint("Salary deductions where applicable"),
        _buildBulletPoint("Suspension or termination"),
        _buildBulletPoint("Legal action in severe cases"),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("10. Acknowledgment"),

        _buildBodyText(
            "The Employee confirms that they have read, understood, and agree to comply with this Code of Conduct."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("HR Department")),
          ],
        ),
      ],
    );
  }

  void generateITPolicy() {
    _generateStandardDocument(
      documentTitle: "IT & Cybersecurity Policy",
      department: "Information & Communication Technology",
      stakeholders: ['Employee', 'IT Department'],
      legalDisclaimer:
          "This policy is issued in accordance with internal ICT governance standards and applicable data protection regulations. Non-compliance may result in disciplinary or legal action.",

      content: [

        // ================= INTRO =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This policy establishes the standards for acceptable use, security, and management of information technology systems within BILLK MOTOLINK LTD. "
            "It aims to protect company assets, ensure operational continuity, and safeguard sensitive data."),

        _buildSectionTitle("2. Scope"),
        _buildBodyText(
            "This policy applies to all employees, contractors, and third parties who access company systems, devices, or data resources."),

        // ================= ACCEPTABLE USE =================
        _buildSectionTitle("3. Acceptable Use of Systems"),
        _buildBodyText(
            "Company IT resources are provided strictly for business operations. Limited personal use may be permitted provided it does not interfere with work responsibilities or compromise system integrity."),

        _buildBulletPoint("Do not share system credentials (usernames, passwords, access tokens)."),
        _buildBulletPoint("Access only systems and data relevant to your role."),
        _buildBulletPoint("Do not install unauthorized software or applications."),
        _buildBulletPoint("Do not bypass security controls or monitoring systems."),
        _buildBulletPoint("Use company email and communication tools professionally."),

       

        // ================= DATA SECURITY =================
        _buildSectionTitle("4. Data Protection & Privacy"),
        _buildBodyText(
            "The Data Protection Act, 2019 (No. 24 of 2019)."),
        _buildBodyText(
            "All data created, stored, or processed using company systems remains the sole property of BILLK MOTOLINK LTD and must be handled in accordance with internal policies and applicable data protection laws."),

        _buildBulletPoint("Do not transfer company data to personal devices without authorization."),
        _buildBulletPoint("Sensitive data must be encrypted during storage and transmission."),
        _buildBulletPoint("Unauthorized disclosure of company or client data is strictly prohibited."),
        _buildBulletPoint("Data access must follow the principle of least privilege."),

        // ================= DEVICE POLICY =================
        _buildSectionTitle("5. Device & Asset Management"),
        _buildBodyText(
            "All company-issued devices remain company property and must be used responsibly."),

        _buildBulletPoint("Devices must be protected with passwords or biometric locks."),
        _buildBulletPoint("Lost or stolen devices must be reported immediately to IT for deactivation."),
        _buildBulletPoint("Unauthorized modification or tampering with devices is prohibited."),
        _buildBulletPoint("Only approved hardware may be connected to company systems."),
        pw.SizedBox(height: 20),

        // ================= NETWORK SECURITY =================
        _buildSectionTitle("6. Network & Connectivity"),
        _buildBodyText(
            "Users must ensure secure connections when accessing company systems."),

        _buildBulletPoint("Use only authorized and secure networks."),
        _buildBulletPoint("Public Wi-Fi must not be used without VPN protection."),
        _buildBulletPoint("Unauthorized network scanning or probing is prohibited."),

        // ================= INCIDENT RESPONSE =================
        _buildSectionTitle("7. Incident Reporting"),
        _buildBodyText(
            "All suspected security incidents must be reported immediately to the IT Department."),

        _buildBulletPoint("Report phishing emails, suspicious links, or unauthorized access."),
        _buildBulletPoint("Do not attempt to investigate or resolve incidents independently."),
        _buildBulletPoint("Preserve evidence and avoid altering affected systems."),

        // ================= MONITORING =================
        _buildSectionTitle("8. Monitoring & Compliance"),
        _buildBodyText(
            "All company systems may be monitored, logged, and audited to ensure compliance with this policy."),

        _buildBulletPoint("Users should have no expectation of privacy on company systems."),
        _buildBulletPoint("System usage logs may be reviewed for security and compliance purposes."),

        // ================= VIOLATIONS =================
        _buildSectionTitle("9. Policy Violations"),
        _buildBodyText(
            "Failure to comply with this policy may result in disciplinary action, including termination of employment and potential legal consequences."),

        _buildBulletPoint("Unauthorized access or data breaches."),
        _buildBulletPoint("Negligence leading to security compromise."),
        _buildBulletPoint("Intentional misuse of company systems."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("10. Acknowledgment"),
        _buildBodyText(
            "By signing this document, the employee acknowledges that they have read, understood, and agreed to comply with this IT & Cybersecurity Policy."),

        pw.SizedBox(height: 10),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("IT Department Details")),
          ],
        ),
      ],
    );
  }

  void generateAttendancePolicy() {
    _generateStandardDocument(
      documentTitle: "Attendance & Time Management Policy",
      department: "Information & Communication Technology",
      stakeholders: ['Employee', 'HR Department'],
      legalDisclaimer:
          "This policy governs attendance tracking, punctuality, and time accountability. Non-compliance may affect payroll eligibility and performance evaluation.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This policy establishes a standardized framework for recording, monitoring, and evaluating employee attendance within BILLK MOTOLINK LTD systems."),

        // ================= SCOPE =================
        _buildSectionTitle("2. Scope"),
        _buildBodyText(
            "This policy applies to all employees, including riders, administrative staff, and operational personnel whose attendance impacts payroll and performance evaluation."),

        // ================= ATTENDANCE DEFINITION =================
        _buildSectionTitle("3. Definition of Attendance"),
        _buildBodyText(
            "Attendance refers to the recorded presence of an employee during assigned working hours, including login, logout, and active operational time where applicable."),

        _buildBulletPoint("Clock-in time marks start of work activity."),
        _buildBulletPoint("Clock-out time marks end of work activity."),
        _buildBulletPoint("Active working time may be system-tracked."),
        _buildBulletPoint("Absence includes any unapproved non-attendance."),

        // ================= PUNCTUALITY =================
        _buildSectionTitle("4. Punctuality Requirements"),
        _buildBodyText(
            "Employees are required to report on time according to their assigned schedules. Repeated lateness may affect performance evaluation and payroll calculations."),

        _buildBulletPoint("Late arrival may be recorded as reduced working time."),
        _buildBulletPoint("Repeated lateness may trigger disciplinary review."),
        _buildBulletPoint("Operational schedules must be strictly followed."),

        // ================= ABSENCE =================
        _buildSectionTitle("5. Absence Management"),
        _buildBodyText(
            "Any absence must be reported and approved according to company procedures. Unauthorized absence may result in deductions or disciplinary action."),

        _buildBulletPoint("Sick leave must be communicated promptly."),
        _buildBulletPoint("Unreported absence is treated as unpaid absence."),
        _buildBulletPoint("Extended absence requires formal approval."),

        // ================= ATTENDANCE TRACKING =================
        _buildSectionTitle("6. Attendance Tracking System"),
        _buildBodyText(
            "Attendance is recorded through the digital systems of the company and may include GPS tracking, login logs, and operational activity monitoring for field staff."),

        _buildBulletPoint("System logs are considered official records."),
        _buildBulletPoint("Manual adjustments require authorization."),
        _buildBulletPoint("Any tampering with records is a serious violation."),

        // ================= IMPACT ON PAYROLL =================
        _buildSectionTitle("7. Payroll Implications"),
        _buildBodyText(
            "Attendance directly affects payroll computation, including daily targets, gross income, and net earnings as defined in the wage evaluation system."),

        _buildBulletPoint("Unattended days reduce payable income."),
        _buildBulletPoint("Attendance compliance may influence performance bonuses."),
        _buildBulletPoint("System-generated data is final for payroll processing."),

        // ================= DISCIPLINARY ACTION =================
        _buildSectionTitle("8. Non-Compliance"),
        _buildBodyText(
            "Violation of attendance rules may result in disciplinary action including warnings, deductions, suspension, or termination depending on severity."),

        // ================= EMPLOYEE RESPONSIBILITY =================
        _buildSectionTitle("9. Employee Responsibility"),
        _buildBodyText(
            "Employees are responsible for ensuring accurate attendance logging and compliance with scheduled working hours."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("10. Acknowledgment"),
        _buildBodyText(
            "By signing this document, the Employee acknowledges understanding and acceptance of the Attendance & Time Management Policy."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("HR Department")),
          ],
        ),
      ],
    );
  }

  // liability
  void generateLiabilityAgreement() {
    _generateStandardDocument(
      documentTitle: "Employee Liability Agreement",
      department: "ERP - Human Resource Management",
      stakeholders: ['Employee', 'HR Department'],
      legalDisclaimer:
          "This agreement defines liability responsibilities for company assets, operations, and conduct. It is enforceable under Kenyan contract and employment law.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This Agreement establishes the liability responsibilities of the Employee in relation to company property, operations, and third-party interactions during the course of employment."),

        // ================= SCOPE =================
        _buildSectionTitle("2. Scope"),
        _buildBodyText(
            "This Agreement applies to all employees who handle company assets, systems, vehicles, cash, or any operational resources."),

        // ================= COMPANY ASSETS =================
        _buildSectionTitle("3. Company Property"),
        _buildBodyText(
            "All company property entrusted to the Employee remains the sole property of BILLK MOTOLINK LTD and must be used responsibly and solely for authorized business purposes."),

        _buildBulletPoint("Motorbikes, vehicles, or delivery equipment"),
        _buildBulletPoint("Mobile devices and communication tools"),
        _buildBulletPoint("Cash, invoices, or financial instruments"),
        _buildBulletPoint("Digital systems and login credentials"),

        // ================= LIABILITY CONDITIONS =================
        _buildSectionTitle("4. Employee Liability"),
        _buildBodyText(
            "The Employee may be held financially or disciplinarily liable for loss, damage, or misuse of company property resulting from negligence, misconduct, or unauthorized use."),

        _buildBulletPoint("Loss due to negligence or carelessness"),
        _buildBulletPoint("Unauthorized transfer or use of assets"),
        _buildBulletPoint("Failure to follow operational procedures"),
        _buildBulletPoint("Intentional damage or misuse"),

        // ================= FINANCIAL LIABILITY =================
        _buildSectionTitle("5. Financial Responsibility"),
        _buildBodyText(
            "Where financial loss is directly attributable to employee actions or negligence, the Company reserves the right to recover reasonable costs in accordance with applicable labor laws."),

        _buildBulletPoint("Loss of cash or mismanaged transactions"),
        _buildBulletPoint("Damage to company equipment"),
        _buildBulletPoint("Unaccounted operational discrepancies"),

        // ================= RISK ACKNOWLEDGMENT =================
        _buildSectionTitle("6. Operational Risk"),
        _buildBodyText(
            "The Employee acknowledges that certain roles involve inherent operational risks and agrees to exercise due care at all times."),

        _buildBulletPoint("Safe handling of equipment and systems"),
        _buildBulletPoint("Compliance with safety procedures"),
        _buildBulletPoint("Immediate reporting of incidents"),

        // ================= THIRD PARTY LIABILITY =================
        _buildSectionTitle("7. Third-Party Interactions"),
        _buildBodyText(
            "The Employee is responsible for maintaining professional conduct when interacting with clients, vendors, and external stakeholders."),

        _buildBulletPoint("No unauthorized commitments on behalf of the Company"),
        _buildBulletPoint("Professional handling of disputes"),
        _buildBulletPoint("Accurate representation of services"),

        // ================= INCIDENT REPORTING =================
        _buildSectionTitle("8. Incident Reporting"),
        _buildBodyText(
            "All incidents involving loss, damage, or security breaches must be reported immediately to the relevant department."),

        _buildBulletPoint("Immediate notification to supervisor or IT"),
        _buildBulletPoint("Documentation of incident details"),
        _buildBulletPoint("Cooperation in investigations"),

        // ================= LIMITATION =================
        _buildSectionTitle("9. Limitation of Liability"),
        _buildBodyText(
            "The Employee shall not be held liable for losses resulting from system failures, external factors, or instructions given by authorized management personnel."),

        // ================= TERMINATION IMPACT =================
        _buildSectionTitle("10. Termination Impact"),
        _buildBodyText(
            "Liability obligations survive termination of employment for any unresolved incidents or outstanding obligations."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("11. Acknowledgment"),
        _buildBodyText(
            "By signing this document, the Employee acknowledges understanding and acceptance of liability responsibilities as outlined herein."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Employer Details")),
          ],
        ),
      ],
    );
  }

  void generateNonSolicitation() {
    _generateStandardDocument(
      documentTitle: "Non-Solicitation Agreement",
      department: "Human Resource Management",
      stakeholders: ['Employee', 'HR Department'],
      legalDisclaimer:
          "This agreement is enforceable under applicable employment and commercial laws. It protects legitimate business interests including clients, employees, and operational relationships.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This Agreement prevents the Employee from directly or indirectly soliciting clients, employees, contractors, or business partners of BILLK MOTOLINK LTD during and after employment."),

        // ================= SCOPE =================
        _buildSectionTitle("2. Scope"),
        _buildBodyText(
            "This Agreement applies to all employees regardless of role, including riders, administrative staff, IT personnel, and management."),

        // ================= NON-SOLICITATION OF CLIENTS =================
        _buildSectionTitle("3. Client Protection"),
        _buildBodyText(
            "The Employee agrees not to solicit, contact, or attempt to divert any client or customer of the Company for personal or third-party benefit."),

        _buildBulletPoint("No direct or indirect engagement with company clients for competing services."),
        _buildBulletPoint("No use of internal client lists for external purposes."),
        _buildBulletPoint("No encouragement of client migration to competing businesses."),

        // ================= NON-SOLICITATION OF EMPLOYEES =================
        _buildSectionTitle("4. Employee Non-Solicitation"),
        _buildBodyText(
            "The Employee shall not attempt to recruit, influence, or induce other employees or contractors to leave the Company."),

        _buildBulletPoint("No recruitment of riders or staff for external operations."),
        _buildBulletPoint("No encouragement of resignation for competitive employment."),
        _buildBulletPoint("No formation of competing operational groups."),

        // ================= NON-COMPETE ALIGNMENT =================
        _buildSectionTitle("5. Competitive Restrictions"),
        _buildBodyText(
            "While not a full non-compete clause, the Employee agrees not to use insider knowledge to create or support competing services targeting the Company’s operational market."),

        _buildBulletPoint("No replication of internal systems or processes."),
        _buildBulletPoint("No exploitation of pricing or wage structures."),
        _buildBulletPoint("No use of proprietary operational strategies."),

        // ================= CONFIDENTIALITY LINK =================
        _buildSectionTitle("6. Relationship with Confidentiality"),
        _buildBodyText(
            "This Agreement works in conjunction with the NDA and Data Protection Policy to ensure full protection of company information and relationships."),

        // ================= DURATION =================
        _buildSectionTitle("7. Duration"),
        _buildBodyText(
            "These obligations apply during employment and remain in effect for a defined post-employment period as per company policy or applicable law."),

        // ================= BREACH CONSEQUENCES =================
        _buildSectionTitle("8. Breach of Agreement"),
        _buildBodyText(
            "Any violation of this Agreement may result in disciplinary action, termination, legal proceedings, and financial claims for damages."),

        _buildBulletPoint("Termination of employment"),
        _buildBulletPoint("Legal injunction or claims"),
        _buildBulletPoint("Recovery of damages and losses"),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("9. Acknowledgment"),
        _buildBodyText(
            "The Employee confirms that they understand and accept the terms of this Non-Solicitation Agreement."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Employer Details")),
          ],
        ),
      ],
    );
  }

  // operations
  void generateEquipmentForm() {
    _generateStandardDocument(
      documentTitle: "Equipment Assignment & Responsibility Form",
      department: 'Warehouse',
      stakeholders: ['Employee', 'Store Keeper'],
      legalDisclaimer:
          "This document confirms assignment of company property to the Employee. All equipment remains the property of BILLK MOTOLINK LTD and must be returned upon request or termination of employment.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This form documents the issuance of company equipment to an employee for operational use and defines responsibility for its care and return."),

        // ================= EMPLOYEE DETAILS =================
        _buildSectionTitle("2. Employee Information"),

        _buildKeyValue("Full Name", ""),
        _buildKeyValue("Employee ID", ""),
        _buildKeyValue("Department", ""),
        _buildKeyValue("Position", ""),
        _buildKeyValue("Phone Number", ""),

        // ================= EQUIPMENT DETAILS =================
        _buildSectionTitle("3. Assigned Equipment"),

        _buildBulletPoint("Item Type: ____________________________________"),
        _buildBulletPoint("Asset Tag / Serial No: ________________________"),
        _buildBulletPoint("Condition at Issue: ___________________________"),
        _buildBulletPoint("Date Issued: _________________________________"),

        pw.SizedBox(height: 10),

        _buildBodyText(
            "The Employee acknowledges receipt of the above-listed equipment in good working condition unless otherwise stated."),

        // ================= RESPONSIBILITIES =================
        _buildSectionTitle("4. Employee Responsibilities"),

        _buildBulletPoint("Use equipment strictly for official company purposes."),
        _buildBulletPoint("Protect equipment from loss, theft, or damage."),
        _buildBulletPoint("Do not modify or tamper with equipment."),
        _buildBulletPoint("Report any faults or damage immediately."),

        // ================= LIABILITY =================
        _buildSectionTitle("5. Loss or Damage"),

        _buildBodyText(
            "The Employee may be held financially responsible for loss or damage resulting from negligence, misuse, or unauthorized handling of assigned equipment."),

        _buildBulletPoint("Negligent damage or misuse"),
        _buildBulletPoint("Loss due to failure to secure equipment"),
        _buildBulletPoint("Unauthorized transfer to third parties"),

        // ================= RETURN POLICY =================
        _buildSectionTitle("6. Return of Equipment"),

        _buildBodyText(
            "All equipment must be returned in good condition upon termination of employment or upon official request from the Company."),

        _buildBulletPoint("Equipment must be returned within specified timelines."),
        _buildBulletPoint("Failure to return may result in deductions or legal action."),
        _buildBulletPoint("All accessories must be returned together."),

        // ================= INSPECTION =================
        _buildSectionTitle("7. Inspection & Verification"),

        _buildBodyText(
            "The Company reserves the right to inspect issued equipment at any time for compliance and condition verification."),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("8. Acknowledgment"),

        _buildBodyText(
            "The Employee acknowledges receipt of the listed equipment and accepts full responsibility for its safekeeping."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Operations Department")),
          ],
        ),
      ]
    );
  }

  void generateSafetyForm() {
    _generateStandardDocument(
      documentTitle: "Occupational Safety & Health Declaration",
      department: 'Operations Management',
      stakeholders: ['Employee', 'Safety Officer'],
      legalDisclaimer:
          "This document establishes safety obligations under workplace health and safety standards. Non-compliance may result in disciplinary action and liability where applicable.\nThis document is administered under the OSHA(US)/OSH Act of 1970",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This form ensures that employees acknowledge workplace safety procedures, risks associated with their role, and preventive measures required to maintain a safe working environment."),

        // ================= EMPLOYEE DETAILS =================
        _buildSectionTitle("2. Employee Information"),

        _buildKeyValue("Full Name", ""),
        _buildKeyValue("Employee ID", ""),
        _buildKeyValue("Department", ""),
        _buildKeyValue("Position", ""),
        _buildKeyValue("Phone Number", ""),

        // ================= GENERAL SAFETY RULES =================
        _buildSectionTitle("3. General Safety Requirements"),

        _buildBulletPoint("Always comply with company safety procedures and instructions."),
        _buildBulletPoint("Report unsafe conditions immediately to the supervisor."),
        _buildBulletPoint("Use provided protective equipment where applicable."),
        _buildBulletPoint("Do not operate equipment without proper authorization."),

        // ================= FIELD / RIDER SAFETY =================
        _buildSectionTitle("4. Field Operations Safety"),

        _buildBodyText(
            "Employees engaged in field operations (e.g., riders, drivers) must adhere to road safety and operational risk guidelines."),

        _buildBulletPoint("Wear protective gear at all times while on duty."),
        _buildBulletPoint("Obey all traffic laws and regulations."),
        _buildBulletPoint("Do not use mobile devices while operating vehicles."),
        _buildBulletPoint("Report accidents or incidents immediately."),

        // ================= WORKPLACE HAZARDS =================
        _buildSectionTitle("5. Hazard Awareness"),

        _buildBodyText(
            "Employees must remain aware of potential hazards in their work environment and take proactive measures to mitigate risk."),

        _buildBulletPoint("Slippery or unsafe surfaces must be reported."),
        _buildBulletPoint("Electrical equipment must not be tampered with."),
        _buildBulletPoint("Unauthorized access to restricted areas is prohibited."),

        pw.SizedBox(height: 30),
        // ================= INCIDENT REPORTING =================
        _buildSectionTitle("6. Incident Reporting Procedure"),

        _buildBodyText(
            "All incidents, regardless of severity, must be reported immediately to the Safety Officer or Supervisor."),

        _buildBulletPoint("Report injuries immediately."),
        _buildBulletPoint("Document incident details accurately."),
        _buildBulletPoint("Do not alter or remove evidence from incident sites."),

        // ================= EMPLOYEE RESPONSIBILITY =================
        _buildSectionTitle("7. Employee Responsibility"),

        _buildBodyText(
            "Employees are responsible for ensuring their own safety and the safety of those around them while performing assigned duties."),

        // ================= NON-COMPLIANCE =================
        _buildSectionTitle("8. Non-Compliance"),

        _buildBodyText(
            "Failure to comply with safety procedures may result in disciplinary action, suspension, or termination depending on severity."),

        _buildBulletPoint("Negligence in safety practices"),
        _buildBulletPoint("Failure to report incidents"),
        _buildBulletPoint("Violation of safety instructions"),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("9. Acknowledgment"),

        _buildBodyText(
            "The Employee confirms that they have read, understood, and agree to comply with all safety and health requirements outlined in this document."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Safety Department")),
          ],
        ),
      ],
    );
  }

  // exit
  void generateExitClearance() {
    _generateStandardDocument(
      documentTitle: "Employee Exit Clearance Form",
      department: 'Executive Management',
      stakeholders: ['Employee', 'HR Department'],
      legalDisclaimer:
          "This document confirms completion of exit procedures including asset return, financial reconciliation, and system access deactivation. It is required for final settlement processing.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This form ensures that all obligations between the Employee and BILLK MOTOLINK LTD are properly concluded upon termination of employment."),

        // ================= EMPLOYEE DETAILS =================
        _buildSectionTitle("2. Employee Information"),

        _buildKeyValue("Full Name", ""),
        _buildKeyValue("Employee ID", ""),
        _buildKeyValue("Department", ""),
        _buildKeyValue("Position", ""),
        _buildKeyValue("Last Working Day", ""),

        // ================= REASON FOR EXIT =================
        _buildSectionTitle("3. Reason for Exit"),

        _buildBulletPoint("Resignation"),
        _buildBulletPoint("Contract Completion"),
        _buildBulletPoint("Termination"),
        _buildBulletPoint("Mutual Separation"),

        pw.SizedBox(height: 8),

        _buildBodyText(
            "The Employee acknowledges that the reason for exit may affect final settlement timelines and entitlements."),

        // ================= COMPANY ASSET CLEARANCE =================
        _buildSectionTitle("4. Asset Return Clearance"),

        _buildBodyText(
            "All company property must be returned in acceptable condition before final clearance is approved."),

        _buildBulletPoint("Mobile devices, laptops, or equipment returned"),
        _buildBulletPoint("Company ID cards surrendered"),
        _buildBulletPoint("Vehicles or operational tools returned"),
        _buildBulletPoint("System access credentials revoked"),

        // ================= FINANCIAL CLEARANCE =================
        _buildSectionTitle("5. Financial Settlement"),

        _buildBodyText(
            "Final payroll settlement will be processed after verification of all outstanding obligations."),

        _buildBulletPoint("Outstanding salary or unpaid dues"),
        _buildBulletPoint("Deductions for damages or liabilities"),
        _buildBulletPoint("Reconciliation of advances or loans"),
        _buildBulletPoint("Final wage evaluation adjustments"),

        // ================= IT CLEARANCE =================
        _buildSectionTitle("6. IT Department Clearance"),

        _buildBodyText(
            "All digital access, accounts, and system permissions will be revoked upon clearance approval."),

        _buildBulletPoint("Email account deactivation"),
        _buildBulletPoint("System login removal"),
        _buildBulletPoint("Data backup and transfer completed"),
        _buildBulletPoint("Device wiping where applicable"),

        // ================= HR CLEARANCE =================
        _buildSectionTitle("7. HR Clearance"),

        _buildBodyText(
            "HR confirms completion of exit documentation, policy compliance review, and personnel record update."),

        // ================= NON-COMPETE / CONTINUING OBLIGATIONS =================
        _buildSectionTitle("8. Continuing Obligations"),

        _buildBodyText(
            "The Employee acknowledges that certain obligations including NDA, Non-Solicitation, and Liability Agreements remain enforceable after exit."),

        // ================= FINAL DECLARATION =================
        _buildSectionTitle("9. Final Declaration"),

        _buildBodyText(
            "The Employee confirms that all company property has been returned and that no outstanding obligations remain unresolved."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("HR / Operations")),
          ],
        ),
      ],
    );
  }

  void generateFinalDues() {
    _generateStandardDocument(
      documentTitle: "Final Dues Settlement Statement",
      department: 'ERP - Finance & Accounting',
      stakeholders: ['Employee', 'Finance Dept', 'HR Department'],
      legalDisclaimer:
          "This document represents the final financial settlement between the Company and the Employee upon exit. It is subject to verification of clearance status and company records.",

      content: [

        // ================= PURPOSE =================
        _buildSectionTitle("1. Purpose"),
        _buildBodyText(
            "This document summarizes all financial entitlements and obligations due to the Employee upon termination of employment."),

        // ================= EMPLOYEE DETAILS =================
        _buildSectionTitle("2. Employee Information"),

        _buildKeyValue("Full Name", ""),
        _buildKeyValue("Employee ID", ""),
        _buildKeyValue("Department", ""),
        _buildKeyValue("Position", ""),
        _buildKeyValue("Last Working Day", ""),

        // ================= FINAL PAY COMPONENTS =================
        _buildSectionTitle("3. Final Pay Components"),

        _buildBodyText(
            "The final settlement is computed based on gross earnings, net earnings, and all applicable adjustments recorded in the system."),

        _buildBulletPoint("Outstanding salary (if any)"),
        _buildBulletPoint("Pending performance-based earnings"),
        _buildBulletPoint("Approved allowances or bonuses"),
        _buildBulletPoint("Leave days (if monetized)"),

        // ================= DEDUCTIONS =================
        _buildSectionTitle("4. Deductions"),

        _buildBodyText(
            "The following deductions may be applied to the final settlement based on company policies, liabilities, and outstanding obligations."),

        _buildBulletPoint("Equipment loss or damage"),
        _buildBulletPoint("Unsettled advances or loans"),
        _buildBulletPoint("Policy violations or penalties"),
        _buildBulletPoint("Unreturned company assets"),

        // ================= LIABILITY LINK =================
        _buildSectionTitle("5. Liability Adjustments"),

        _buildBodyText(
            "Any liability established under the Employee Liability Agreement will be reconciled before final payment is processed."),

        // ================= WAGE EVALUATION REFERENCE =================
        _buildSectionTitle("6. Wage Evaluation Reference"),

        _buildBodyText(
            "Final dues are calculated using system-generated wage evaluation data, including gross income, net income, and deviation metrics."),

        _buildBulletPoint("Gross income totals from operational records"),
        _buildBulletPoint("Net income after performance adjustments"),
        _buildBulletPoint("Daily target deductions applied"),
        _buildBulletPoint("Additional earnings and withdrawals"),

        // ================= NET FINAL AMOUNT =================
        _buildSectionTitle("7. Net Payable Amount"),

        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey200),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "FINAL SETTLEMENT AMOUNT",
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blueGrey800,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                "KES __________________________",
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        // ================= ACKNOWLEDGMENT =================
        _buildSectionTitle("8. Employee Acknowledgment"),

        _buildBodyText(
            "The Employee confirms that they understand and accept the final settlement calculation as complete and accurate based on company records."),

        _buildBodyText(
            "Upon payment, all financial obligations between the Employee and Company are considered fully settled, subject to any post-exit liabilities defined in signed agreements."),

        // ================= SIGNATURE BLOCK =================
        pw.SizedBox(height: 30),

        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(child: _buildPartyDetails("Employee Details")),
            pw.SizedBox(width: 15),
            pw.Expanded(child: _buildPartyDetails("Finance Department")),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Non Variable Documents', style: TextStyle(fontWeight: FontWeight.w700),),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [

          // ================= HEADER =================
          const Text(
            'Document Production Center',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const Text(
            'This section is used to produce documents to be printed and administered to employees effectively.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),

          const SizedBox(height: 30),

          // ================= CORE DOCUMENTS =================
          const SectionTitle(title: "Core Employment Documents"),

          buildCard(
            context,
            icon: Icons.description,
            title: 'Employment Contract',
            subtitle: 'Generate standard employment agreement.',
            onTap: generateEmploymentContract,
          ),

          buildCard(
            context,
            icon: Icons.work,
            title: 'Job Description',
            subtitle: 'Define role and responsibilities.',
            onTap: generateJobDescription,
          ),

          // ================= CONFIDENTIALITY =================
          const SectionTitle(title: "Confidentiality & IP"),

          buildCard(
            context,
            icon: Icons.lock,
            title: 'Non-Disclosure Agreement (NDA)',
            subtitle: 'Protect company confidential information.',
            onTap: generateNDA,
          ),

          buildCard(
            context,
            icon: Icons.gavel,
            title: 'IP Assignment Agreement',
            subtitle: 'Assign intellectual property rights.',
            onTap: generateIPAssignment,
          ),

          buildCard(
            context,
            icon: Icons.privacy_tip,
            title: 'Data Protection Agreement',
            subtitle: 'Ensure proper handling of sensitive data.',
            onTap: generateDataProtection,
          ),

          // ================= PAYROLL & FINANCE =================
          const SectionTitle(title: "Payroll & Financial Documents"),

          buildCard(
            context,
            icon: Icons.account_balance,
            title: 'Bank Details Form',
            subtitle: 'Capture employee payment information.',
            onTap: generateBankDetails,
          ),

          buildCard(
            context,
            icon: Icons.receipt_long,
            title: 'Payroll Acknowledgment',
            subtitle: 'Confirm employee pay acceptance.',
            onTap: generatePayrollAcknowledgment,
          ),

          // ================= POLICIES =================
          const SectionTitle(title: "Policies & Compliance"),

          buildCard(
            context,
            icon: Icons.rule,
            title: 'Code of Conduct',
            subtitle: 'Define expected employee behavior.',
            onTap: generateCodeOfConduct,
          ),

          buildCard(
            context,
            icon: Icons.computer,
            title: 'IT & Systems Usage Policy',
            subtitle: 'Control system and device usage.',
            onTap: generateITPolicy,
          ),

          buildCard(
            context,
            icon: Icons.schedule,
            title: 'Attendance & Work Policy',
            subtitle: 'Define attendance and work expectations.',
            onTap: generateAttendancePolicy,
          ),

          // ================= LIABILITY =================
          const SectionTitle(title: "Liability & Risk"),

          buildCard(
            context,
            icon: Icons.warning,
            title: 'Liability Agreement',
            subtitle: 'Define responsibility for losses and damages.',
            onTap: generateLiabilityAgreement,
          ),

          buildCard(
            context,
            icon: Icons.people_alt,
            title: 'Non-Solicitation Agreement',
            subtitle: 'Restrict employee poaching of clients/staff.',
            onTap: generateNonSolicitation,
          ),

          // ================= OPERATIONS =================
          const SectionTitle(title: "Operational Documents"),

          buildCard(
            context,
            icon: Icons.inventory,
            title: 'Equipment Issuance Form',
            subtitle: 'Track assigned company assets.',
            onTap: generateEquipmentForm,
          ),

          buildCard(
            context,
            icon: Icons.health_and_safety,
            title: 'Safety Compliance Form',
            subtitle: 'Confirm safety procedure understanding.',
            onTap: generateSafetyForm,
          ),

          // ================= EXIT =================
          const SectionTitle(title: "Exit Documents"),

          buildCard(
            context,
            icon: Icons.exit_to_app,
            title: 'Exit Clearance Form',
            subtitle: 'Ensure proper exit procedures.',
            onTap: generateExitClearance,
          ),

          buildCard(
            context,
            icon: Icons.payments,
            title: 'Final Dues Acknowledgment',
            subtitle: 'Confirm final payment settlement.',
            onTap: generateFinalDues,
          ),

        ],
      ),
    );
  }

  // ================= REUSABLE CARD =================
  Widget buildCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: Icon(icon, color: Colors.teal),
        title: Text(title),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }

}

// ================= SECTION TITLE =================
class SectionTitle extends StatelessWidget {
  final String title;

  const SectionTitle({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 20),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.teal,
        ),
      ),
    );
  }
}

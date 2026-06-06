import 'package:flutter/material.dart';

class TermsAndConditions extends StatelessWidget {
  const TermsAndConditions({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.primary.withValues(alpha: 0.1),
                          theme.colorScheme.primaryContainer ?? theme.colorScheme.primary.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Icon(
                                Icons.description,
                                color: theme.colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'BILLK MOTOLINK LTD',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  Text(
                                    'Terms and Conditions',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Effective Date: Upon Registration',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Sections
                  ..._buildSections(theme),
                  
                  // Footer
                  const SizedBox(height: 40),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer?.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.outlineVariant!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.gavel,
                          size: 48,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'By using the BILLK MOTOLINK LTD platform, you acknowledge that you have read, understood, and agreed to these Terms and Conditions.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSections(ThemeData theme) {
    final sections = [
      {
        'title': '1. Nature of Engagement',
        'body': 'BILLK MOTOLINK LTD operates a delivery and logistics platform. Riders are engaged as independent operators unless otherwise stated in writing. Nothing herein constitutes an employer–employee relationship.',
      },
      {
        'title': '2. Eligibility',
        'body': 'To operate under the Company, you must:\n\n• Be legally eligible to work\n• Hold valid identification and licensing\n• Provide accurate personal and operational data\n• Maintain roadworthy equipment',
      },
      {
        'title': '3. Duties and Responsibilities',
        'body': 'Riders agree to:\n\n• Perform deliveries professionally and promptly\n• Safeguard goods entrusted to them\n• Use company assets responsibly\n• Accurately report mileage, income, incidents, and clock-ins\n• Comply with traffic laws and safety standards',
      },
      {
        'title': '4. Company Assets',
        'body': 'All batteries, bikes, tracking systems, and accessories issued remain Company property. Any loss, misuse, or damage attributable to negligence may be recovered from the Rider.',
      },
      {
        'title': '5. Financial Matters',
        'body': '• Earnings are calculated based on recorded activity\n• Pending amounts may be settled periodically\n• The Company reserves the right to offset damages, fines, or liabilities\n• In-app balances are records, not cash guarantees',
      },
      {
        'title': '6. Clock-In and Reporting',
        'body': 'All Riders must clock in and out using the approved system. False reporting, manipulation of data, or failure to report accurately constitutes misconduct.',
      },
      {
        'title': '7. Conduct and Compliance',
        'body': 'The following are strictly prohibited:\n\n• Fraud or misrepresentation\n• Abuse of customers, staff, or systems\n• Unauthorized asset transfer\n• Operating under the influence of alcohol or drugs',
      },
      {
        'title': '8. Suspension and Termination',
        'body': 'The Company may suspend or terminate access immediately for:\n\n• Breach of these Terms\n• Safety risks\n• Reputational harm\n• Legal or regulatory exposure',
      },
      {
        'title': '9. Liability',
        'body': 'Riders operate at their own risk. The Company is not liable for:\n\n• Accidents or injuries past insurance scope\n• Loss of personal property\n• Third-party claims arising from Rider conduct',
      },
      {
        'title': '10. Data and Monitoring',
        'body': 'Operational data including location, activity logs, and usage metrics may be collected for security, optimization, and compliance purposes.',
      },
      {
        'title': '11. Amendments',
        'body': 'These Terms may be updated at any time. Continued use of the platform constitutes acceptance of changes.',
      },
      {
        'title': '12. Governing Law',
        'body': 'These Terms are governed by the laws applicable in the Company\'s jurisdiction of operation.',
      },
    ];

    return sections.map((section) => _buildSection(theme, section['title']!, section['body']!)).toList();
  }

  Widget _buildSection(ThemeData theme, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ) ?? const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Section Body
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ) ?? const TextStyle(height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

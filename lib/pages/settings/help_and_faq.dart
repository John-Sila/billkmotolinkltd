import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpAndFAQ extends StatelessWidget {
  const HelpAndFAQ({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void _openWhatsAppStore(BuildContext context) async {
      final String appStoreUrl = Platform.isIOS
          ? 'https://apps.apple.com/app/whatsapp-messenger/id310633997'
          : 'https://play.google.com/store/apps/details?id=com.whatsapp';

      try {
        await launchUrl(
          Uri.parse(appStoreUrl),
          mode: LaunchMode.externalApplication,
        );
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open app store'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }

    Future<void> _showWhatsAppErrorDialog(BuildContext context, String error) async {
      return showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('WhatsApp Not Available'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Could not open WhatsApp. Possible reasons:'),
              const SizedBox(height: 10),
              Text('• WhatsApp not installed', style: TextStyle(color: Colors.grey[700])),
              Text('• Invalid phone number format', style: TextStyle(color: Colors.grey[700])),
              Text('• Device restrictions', style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 10),
              Text('Error: ${error.substring(0, 50)}...', style: const TextStyle(fontSize: 12)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _openWhatsAppStore(context);
              },
              child: const Text('Install WhatsApp'),
            ),
          ],
        ),
      );
    }

    Future<void> _launchWhatsApp(BuildContext context) async {
      // Format: Country code + number without + or 0
      const String phoneNumber = '254717405109'; // Kenya: 254 is country code
      
      // Simple test message
      const String message = 'Hello Billk Motolink Support!';
      
      // Construct URL
      final String encodedMessage = Uri.encodeComponent(message);
      final String url = 'https://wa.me/$phoneNumber?text=$encodedMessage';
      
      debugPrint('WhatsApp URL: $url'); // Debug log
      
      try {
        final bool launched = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        
        if (!launched) {
          throw Exception('Failed to launch WhatsApp');
        }
      } catch (e) {
        debugPrint('WhatsApp launch error: $e');
        
        if (context.mounted) {
          await _showWhatsAppErrorDialog(context, e.toString());
        }
      }
    }
    
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Help & FAQ',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.onSurface,
        centerTitle: true,



        actions: [
          GestureDetector(
            onTap: () => _launchWhatsApp(context),
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.15),
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.support_agent, color: theme.colorScheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Contact IT',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),


              




            ),
          ),
        ],
      
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hero Header
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.secondary.withValues(alpha: 0.1),
                          theme.colorScheme.secondaryContainer,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: theme.colorScheme.secondary.withValues(alpha: 0.2),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.secondary.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.secondary,
                                    theme.colorScheme.secondary.withValues(alpha: 0.8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                Icons.help_outline,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Help Center',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    'Find answers to common questions',
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Most issues can be resolved here without escalation.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // FAQ Sections
                  ..._buildFAQSections(theme),
                  
                  // Operational Note
                  const SizedBox(height: 32),
                  _buildOperationalNote(theme),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );

  }

  List<Widget> _buildFAQSections(ThemeData theme) {
    final faqs = [
      {
        'title': '1. I cannot clock in',
        'body': 'Ensure you:\n\n• Have selected a bike\n• Have scanned at least one battery\n• Have entered valid mileage\n• Have an active and verified account\n\nClock-in is automatically blocked if any requirement fails.',
      },
      {
        'title': '2. My clock-in or clock-out data is incorrect',
        'body': 'Data is system-recorded at the time of action. If an error occurs due to system failure, report it immediately through management. Late disputes may not be honored.',
      },
      {
        'title': '3. Why is my account inactive or restricted?',
        'body': 'Accounts may be restricted due to:\n\n• Incomplete verification\n• Policy violations\n• Pending investigations\n• Administrative suspension\n\nContact management only if the restriction persists without explanation.',
      },
      {
        'title': '4. How is my income calculated?',
        'body': 'Income is calculated based on recorded deliveries, clock-ins, and system logs. The in-app balance is a tracking tool and not an immediate cash entitlement.',
      },
      {
        'title': '5. What is pending amount?',
        'body': 'Pending amount represents unsettled earnings. It may be cleared periodically based on company policy, deductions, or reconciliations.',
      },
      {
        'title': '6. Why was a battery or bike reassigned?',
        'body': 'Assets are dynamically managed for operational efficiency. Reassignments may occur due to charging cycles, availability, or system optimization.',
      },
      {
        'title': '7. I see an event or poll notification',
        'body': 'Events are mandatory or informational activities. Polls require participation within the specified deadline. Failure to engage may affect operational decisions.',
      },
      {
        'title': '8. My notification count is incorrect',
        'body': 'Notification counts reflect unread items. Reading notifications updates the count automatically. Manual resets are administrative-only.',
      },
      {
        'title': '9. I forgot to clock out',
        'body': 'Failure to clock out must be reported immediately. Repeated incidents may be treated as misconduct.',
      },
      {
        'title': '10. How do I get support?',
        'body': 'Escalate only after reviewing this section. Provide clear details: date, time, issue, and supporting evidence. Incomplete reports delay resolution.',
      },
    ];

    return faqs.map((faq) => _buildFAQCard(theme, faq['title']!, faq['body']!)).toList();
  }

  Widget _buildFAQCard(ThemeData theme, String title, String body) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border.all(color: theme.colorScheme.outlineVariant),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.surfaceTint.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary.withValues(alpha: 0.2),
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.help_outline,
                color: theme.colorScheme.primary,
                size: 20,
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
            collapsedBackgroundColor: theme.colorScheme.surface,
            backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  body,
                  softWrap: true,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.6,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperationalNote(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.errorContainer.withValues(alpha: 0.2),
            theme.colorScheme.errorContainer.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
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
                  color: theme.colorScheme.error.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.info_outline,
                  color: theme.colorScheme.error,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Operational Note',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'The platform enforces process integrity by design. Most issues are caused by missed steps, not system failure.',
            style: theme.textTheme.bodyLarge?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onErrorContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Terms of Service',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Acceptance of Terms',
              'By accessing and using Fixr, you accept and agree to be bound by these terms.',
            ),
            _buildSection(
              'Service Terms',
              '• Services are provided "as is" without warranty\n'
              '• We reserve the right to modify or discontinue services\n'
              '• Service availability may vary by location\n'
              '• Response times are estimates, not guarantees',
            ),
            _buildSection(
              'User Responsibilities',
              '• Provide accurate information\n'
              '• Maintain account security\n'
              '• Ensure safe work environment\n'
              '• Report issues promptly\n'
              '• Pay for services as agreed',
            ),
            _buildSection(
              'Booking & Cancellation',
              '• Bookings are subject to provider availability\n'
              '• Free cancellation up to 2 hours before service\n'
              '• Cancellation fee applies within 2 hours\n'
              '• No-shows will be charged full amount',
            ),
            _buildSection(
              'Payment Terms',
              '• Prices are inclusive of taxes\n'
              '• Additional charges for extra work\n'
              '• Payment required before service completion\n'
              '• Multiple payment methods accepted',
            ),
            _buildSection(
              'Liability',
              '• Limited liability for damages\n'
              '• No responsibility for third-party actions\n'
              '• Insurance coverage details\n'
              '• Force majeure conditions',
            ),
            _buildSection(
              'Dispute Resolution',
              '• Attempt amicable resolution first\n'
              '• Mandatory mediation process\n'
              '• Arbitration procedures\n'
              '• Jurisdiction and venue',
            ),
            _buildSection(
              'Updates to Terms',
              '• Terms may be updated periodically\n'
              '• Notice will be provided for major changes\n'
              '• Continued use implies acceptance\n'
              '• Latest version always applicable',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

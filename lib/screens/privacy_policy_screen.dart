import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        backgroundColor: AppTheme.primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(
              'Information We Collect',
              '• Personal Information: Name, email, phone number, and address\n'
              '• Device Information: Device ID, IP address, and location\n'
              '• Usage Data: App interactions and service usage patterns\n'
              '• Payment Information: Transaction records and payment details',
            ),
            _buildSection(
              'How We Use Your Information',
              '• Provide and improve our services\n'
              '• Process your bookings and payments\n'
              '• Send service updates and notifications\n'
              '• Analyze usage patterns and optimize performance\n'
              '• Comply with legal obligations',
            ),
            _buildSection(
              'Information Sharing',
              '• Service Providers: Share with authorized technicians\n'
              '• Payment Processors: For secure transaction handling\n'
              '• Legal Requirements: When required by law\n'
              '• Business Transfers: In case of merger or acquisition',
            ),
            _buildSection(
              'Your Rights',
              '• Access your personal information\n'
              '• Request data correction or deletion\n'
              '• Opt-out of marketing communications\n'
              '• File a complaint with authorities',
            ),
            _buildSection(
              'Data Security',
              '• Encryption of sensitive information\n'
              '• Regular security audits and updates\n'
              '• Secure data storage and transmission\n'
              '• Employee confidentiality agreements',
            ),
            _buildSection(
              'Contact Us',
              'For privacy-related inquiries:\n'
              'Email: privacy@fixr.com\n'
              'Phone: +1-800-FIXR\n'
              'Address: Fixr Headquarters, Tech Street, Digital City',
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

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../models/user_model.dart';
import '../theme/app_theme.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'change_password_screen.dart';
import 'help_screen.dart';
import 'refund_screen.dart';
import 'about_screen.dart';
import '../services/theme_service.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;

  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final UserService _userService = UserService();
  final DatabaseReference _userRef = FirebaseDatabase.instance.ref().child('users');
  UserModel? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      if (!mounted) return;

      setState(() => _userData = null);

      // First try to get data from Realtime Database
      final dbSnapshot = await _userRef.child(widget.uid).get();
      if (dbSnapshot.exists) {
        final data = Map<String, dynamic>.from(dbSnapshot.value as Map);
        final DateTime createdAt = DateTime.tryParse(data['createdAt'] ?? '') ?? DateTime.now();

        if (mounted) {
          setState(() {
            _userData = UserModel(
              uid: widget.uid,
              name: data['name'] ?? 'Guest User',
              email: data['email'] ?? '',
              phone: data['phone'] ?? '',
              address: data['address'] ?? '',
              doornum: data['doornum'] ?? '',
              landmark: data['landmark'] ?? '',
              createdAt: createdAt,
            );
          });
        }
      }

      // Then get data from Firestore to ensure sync
      final userData = await _userService.getUserData(widget.uid);

      if (!mounted) return;

      if (userData != null) {
        setState(() => _userData = userData);

        // Update realtime database to ensure consistency
        await _userRef.child(widget.uid).update(userData.toJson());
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load user data')),
      );
    }
  }

  Future<void> _showEditNameDialog() async {
    final TextEditingController nameController = TextEditingController(
      text: _userData?.name ?? '',
    );

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Name'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final newName = nameController.text.trim();
      if (newName.isNotEmpty && newName != _userData?.name) {
        try {
          final success = await _userService.updateUserName(widget.uid, newName);
          await _userRef.child(widget.uid).update({'name': newName});

          if (!success && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update name')),
            );
          }
        } catch (e) {
          if (kDebugMode) {
            print('Error updating name: $e');
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Failed to update name')),
            );
          }
        }
      }
    }
  }

  Future<void> _showEditAddressDialog() async {
    final TextEditingController doornumController = TextEditingController(
      text: _userData?.doornum ?? '',
    );
    final TextEditingController addressController = TextEditingController(
      text: _userData?.address ?? '',
    );
    final TextEditingController landmarkController = TextEditingController(
      text: _userData?.landmark ?? '',
    );

    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Address Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: doornumController,
              decoration: const InputDecoration(
                labelText: 'Door Number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                labelText: 'Address',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: landmarkController,
              decoration: const InputDecoration(
                labelText: 'Landmark',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final updates = {
        'doornum': doornumController.text.trim(),
        'address': addressController.text.trim(),
        'landmark': landmarkController.text.trim(),
      };

      final success = await _userService.updateUserProfile(widget.uid, updates);
      if (success) {
        _loadUserData();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update address details')),
          );
        }
      }
    }
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: theme.textTheme.bodyLarge?.color,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.iconTheme.color?.withOpacity(0.5),
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    bool initiallyExpanded = false,
  }) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          backgroundColor: Colors.transparent,
          collapsedBackgroundColor: Colors.transparent,
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withAlpha(25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 20),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: theme.textTheme.titleMedium?.color,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSupportButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: const TextStyle(color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return SwitchListTile(
          title: Text(
            'Dark Mode',
            style: TextStyle(
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          secondary: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              themeService.isDarkMode ? Icons.dark_mode : Icons.light_mode,
              color: Colors.orange[700],
              size: 20,
            ),
          ),
          activeColor: Colors.orange[700],
          activeTrackColor: Colors.orange[200],
          inactiveThumbColor: Colors.grey[400],
          inactiveTrackColor: Colors.grey[200],
          value: themeService.isDarkMode,
          onChanged: (bool value) {
            themeService.toggleTheme();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_userData == null) {
      return Scaffold(
        body: RefreshIndicator(
          color: AppTheme.primaryColor,
          onRefresh: () async {
            await _loadUserData();
          },
          child: Center(
            child: ListView(
              shrinkWrap: true,
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Could not load profile',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: _loadUserData,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                            ),
                            child: const Text('Retry'),
                          ),
                          const SizedBox(width: 16),
                          OutlinedButton.icon(
                            onPressed: () => _showLogoutDialog(context),
                            icon: Icon(Icons.logout, color: Colors.red[400]),
                            label: Text(
                              'Logout',
                              style: TextStyle(color: Colors.red[400]),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.red[400]!),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: () async {
        await _loadUserData();
      },
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 80, // Add padding to avoid overlap with logout button
            ),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppTheme.primaryColor.withAlpha(25),
                      child: Text(
                        _userData?.name.substring(0, 1).toUpperCase() ?? '',
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: InkWell(
                        onTap: _showEditNameDialog,
                        child: const Icon(Icons.edit, size: 16, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _userData?.name ?? 'Loading...',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Member since ${_userData?.createdAt.year ?? ''}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),

                // Contact Information Section
                _buildExpandableSection(
                  title: 'Contact Information',
                  icon: Icons.contact_mail_outlined,
                  children: [
                    _buildProfileItem(
                      icon: Icons.email_outlined,
                      title: 'Email',
                      value: _userData?.email ?? 'Loading...',
                    ),
                    const SizedBox(height: 8),
                    _buildProfileItem(
                      icon: Icons.phone_outlined,
                      title: 'Phone',
                      value: _userData?.phone ?? 'Not set',
                    ),
                  ],
                ),

                // Address Information Section
                _buildExpandableSection(
                  title: 'Address Information',
                  icon: Icons.location_on_outlined,
                  children: [
                    _buildProfileItem(
                      icon: Icons.door_front_door_outlined,
                      title: 'Door Number',
                      value: _userData?.doornum ?? 'Not set',
                    ),
                    const SizedBox(height: 8),
                    _buildProfileItem(
                      icon: Icons.location_on_outlined,
                      title: 'Address',
                      value: _userData?.address ?? 'Not set',
                    ),
                    const SizedBox(height: 8),
                    _buildProfileItem(
                      icon: Icons.landscape_outlined,
                      title: 'Landmark',
                      value: _userData?.landmark ?? 'Not set',
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _showEditAddressDialog,
                        icon: const Icon(Icons.edit_location, color: Colors.white),
                        label: const Text(
                          'Update Address Details',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Support & Help Section
                _buildExpandableSection(
                  title: 'Support & Help',
                  icon: Icons.help_outline,
                  children: [
                    _buildSupportButton(
                      icon: Icons.headset_mic_outlined,
                      label: 'Help & Support',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const HelpScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSupportButton(
                      icon: Icons.receipt_long_outlined,
                      label: 'Refund Service',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const RefundScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildSupportButton(
                      icon: Icons.info_outline,
                      label: 'About App',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AboutScreen()),
                      ),
                    ),
                  ],
                ),

                // Account Settings Section
                _buildExpandableSection(
                  title: 'Account Settings',
                  icon: Icons.settings_outlined,
                  children: [
                    _buildThemeToggle(),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const ChangePasswordScreen()),
                        ),
                        icon: const Icon(Icons.lock_outline, color: Colors.white),
                        label: const Text(
                          'Change Password',
                          style: TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Logout button positioned at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: OutlinedButton.icon(
                onPressed: () => _showLogoutDialog(context),
                icon: Icon(Icons.logout, color: Colors.red[400]),
                label: Text(
                  'Logout',
                  style: TextStyle(color: Colors.red[400]),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  side: BorderSide(color: Colors.red[400]!),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.logout, color: Colors.red[400], size: 24),
            ),
            const SizedBox(width: 12),
            const Text('Logout'),
          ],
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      if (!mounted) return;

      final AuthService authService = AuthService();
      await authService.signOut();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/login');
    }
  }
}

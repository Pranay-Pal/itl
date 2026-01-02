import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/features/profile/models/marketing_profile_model.dart';
import 'package:itl/src/features/profile/screens/personal_ledger_screen.dart';
import 'package:itl/src/services/marketing_service.dart';

class ProfileScreen extends StatefulWidget {
  final String userCode;

  const ProfileScreen({super.key, required this.userCode});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final MarketingService _marketingService = MarketingService();
  bool _isLoading = true;
  MarketingProfileData? _data;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final response =
          await _marketingService.getProfile(userCode: widget.userCode);
      if (mounted) {
        setState(() {
          _data = response.data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Profile'),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _data == null
                ? const Center(child: Text('Failed to load profile'))
                : _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    final profile = _data!.profile;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppPalette.electricBlue, width: 2),
              ),
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _data!.avatar != null
                    ? NetworkImage(_data!.avatar!)
                    : null,
                backgroundColor: Colors.grey.shade800,
                child: _data!.avatar == null
                    ? const Icon(Icons.person, size: 50, color: Colors.white)
                    : null,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
            const SizedBox(height: 16),

            // Name & Code
            Text(profile.name ?? 'Unknown User',
                style: AppTypography.headlineMedium),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppPalette.electricBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                profile.userCode ?? '',
                style: AppTypography.labelLarge
                    .copyWith(color: AppPalette.electricBlue),
              ),
            ),
            const SizedBox(height: 40),

            // Menu Options
            _buildMenuTile(
              icon: Icons.analytics_outlined,
              title: 'Personal Ledger',
              subtitle: 'View bookings, invoices & expense stats',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        PersonalLedgerScreen(userCode: widget.userCode),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
             _buildMenuTile(
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'App preferences',
              onTap: () {
                 // Placeholder
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Settings coming soon')));
              },
            ),
             const SizedBox(height: 16),
             _buildMenuTile(
              icon: Icons.logout,
              title: 'Logout',
              subtitle: 'Sign out of your account',
              isDestructive: true,
              onTap: () {
                 // Trigger logout logic (inherited from wherever this would be placed)
                 // For now just show message
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logout logic here')));
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      elevation: 0,
      color: Theme.of(context).cardColor.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDestructive ? Colors.red.withValues(alpha:0.1) : AppPalette.electricBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: isDestructive ? Colors.red : AppPalette.electricBlue),
        ),
        title: Text(title, style: AppTypography.labelLarge.copyWith(
          color: isDestructive ? Colors.red : null
        )),
        subtitle: Text(subtitle, style: AppTypography.bodySmall.copyWith(color: Colors.grey)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      ),
    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
  }
}

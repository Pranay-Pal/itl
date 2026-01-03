import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:itl/src/common/widgets/design_system/aurora_background.dart';
import 'package:itl/src/config/app_layout.dart';
import 'package:itl/src/config/app_palette.dart';
import 'package:itl/src/config/typography.dart';
import 'package:itl/src/services/theme_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeService = ThemeService(); // Singleton

    return AuroraBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Settings', style: AppTypography.headlineMedium),
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppLayout.gapL),
          children: [
            _buildSectionHeader('Appearance'),
            const SizedBox(height: 12),
            _buildThemeCard(context, themeService),
          ]
              .animate(interval: 50.ms)
              .fadeIn(duration: 300.ms)
              .slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: AppTypography.labelSmall.copyWith(
        color: AppPalette.electricBlue,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildThemeCard(BuildContext context, ThemeService themeService) {
    // Listen to changes
    return AnimatedBuilder(
      animation: themeService,
      builder: (context, _) {
        final currentMode = themeService.themeMode;

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            children: [
              _buildRadioTile(
                context,
                title: 'Light Mode',
                icon: Icons.light_mode,
                value: ThemeMode.light,
                groupValue: currentMode,
                onChanged: (val) => themeService.updateTheme(val!),
              ),
              Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              _buildRadioTile(
                context,
                title: 'Dark Mode',
                icon: Icons.dark_mode,
                value: ThemeMode.dark,
                groupValue: currentMode,
                onChanged: (val) => themeService.updateTheme(val!),
              ),
              Divider(
                  height: 1,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
              _buildRadioTile(
                context,
                title: 'System Default',
                icon: Icons.settings_system_daydream,
                value: ThemeMode.system,
                groupValue: currentMode,
                onChanged: (val) => themeService.updateTheme(val!),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRadioTile(
    BuildContext context, {
    required String title,
    required IconData icon,
    required ThemeMode value,
    required ThemeMode groupValue,
    required ValueChanged<ThemeMode?> onChanged,
  }) {
    final isSelected = value == groupValue;

    return RadioListTile<ThemeMode>(
      value: value,
      // ignore: deprecated_member_use
      groupValue: groupValue,
      // ignore: deprecated_member_use
      onChanged: onChanged,
      activeColor: AppPalette.electricBlue,
      title: Row(
        children: [
          Icon(icon,
              color: isSelected ? AppPalette.electricBlue : Colors.grey,
              size: 20),
          const SizedBox(width: 12),
          Text(title,
              style: AppTypography.bodyMedium.copyWith(
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
      controlAffinity: ListTileControlAffinity.trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}

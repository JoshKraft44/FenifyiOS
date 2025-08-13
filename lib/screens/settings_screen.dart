import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../providers/theme_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    
    return Scaffold(
      backgroundColor: context.backgroundColor,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: context.isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Text(
          'Settings',
          style: TextStyle(
            color: context.primaryTextColor,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: context.iconColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              const SizedBox(height: 20),
              Text(
                'Settings',
                style: TextStyle(
                  fontSize: context.isDarkMode ? 32 : 28,
                  fontWeight: context.isDarkMode ? FontWeight.w300 : FontWeight.w700,
                  color: context.primaryTextColor,
                  letterSpacing: context.isDarkMode ? 1 : 0,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Customize your Fenify experience',
                style: TextStyle(
                  fontSize: 16,
                  color: context.secondaryTextColor,
                ),
              ),
              const SizedBox(height: 40),
              
              // Settings sections
              _buildSettingsSection(
                'Appearance',
                [
                  _buildThemeToggleTile(themeProvider),
                ],
              ),
              
              const SizedBox(height: 32),
              
              _buildSettingsSection(
                'General',
                [
                  _buildSettingsTile(
                    Icons.notifications_outlined,
                    'Notifications',
                    'Manage your notification preferences',
                    () {},
                  ),
                  _buildSettingsTile(
                    Icons.language_outlined,
                    'Language',
                    'Choose your preferred language',
                    () {},
                  ),
                  _buildSettingsTile(
                    Icons.palette_outlined,
                    'Display',
                    'Customize app appearance',
                    () {},
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              _buildSettingsSection(
                'Analysis',
                [
                  _buildSettingsTile(
                    Icons.tune_outlined,
                    'Engine Settings',
                    'Configure Stockfish analysis depth',
                    () {},
                  ),
                  _buildSettingsTile(
                    Icons.speed_outlined,
                    'Analysis Speed',
                    'Adjust analysis performance',
                    () {},
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              _buildSettingsSection(
                'Support',
                [
                  _buildSettingsTile(
                    Icons.info_outline,
                    'About Fenify',
                    'Version and app information',
                    () {},
                  ),
                  _buildSettingsTile(
                    Icons.help_outline,
                    'Help & Support',
                    'Get help using Fenify',
                    () {},
                  ),
                  _buildSettingsTile(
                    Icons.feedback_outlined,
                    'Send Feedback',
                    'Help us improve Fenify',
                    () {},
                  ),
                ],
              ),
              
              const SizedBox(height: 40), // Add padding at bottom
            ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: context.primaryTextColor.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: context.surfaceColor,
            borderRadius: BorderRadius.circular(context.isDarkMode ? 20 : 16),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
  
  Widget _buildThemeToggleTile(ThemeProvider themeProvider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.isDarkMode ? 16 : 12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.columbiaBlue.withOpacity(0.2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            themeProvider.isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded, 
            color: context.isDarkMode ? Colors.white : AppColors.deepNavy, 
            size: 24
          ),
        ),
        title: Text(
          'Theme Mode',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.primaryTextColor,
            fontSize: 17,
          ),
        ),
        subtitle: Text(
          themeProvider.isDarkMode ? 'Dark mode active' : 'Light mode active',
          style: TextStyle(
            color: context.secondaryTextColor,
            fontSize: 14,
          ),
        ),
        trailing: Switch.adaptive(
          value: themeProvider.isDarkMode,
          onChanged: (value) {
            HapticFeedback.lightImpact();
            themeProvider.toggleTheme();
          },
          activeColor: AppColors.columbiaBlue,
          inactiveTrackColor: context.isDarkMode 
            ? Colors.grey.shade700 
            : Colors.grey.shade300,
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return Colors.white;
            }
            return null;
          }),
        ),
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.isDarkMode 
            ? AppColors.columbiaBlue.withOpacity(0.2)
            : AppColors.lightBlue.withOpacity(0.15),
          borderRadius: BorderRadius.circular(context.isDarkMode ? 14 : 12),
        ),
        child: Icon(
          icon, 
          color: context.isDarkMode ? Colors.white : AppColors.columbiaBlue, 
          size: 22
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: context.primaryTextColor,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          color: context.secondaryTextColor,
          fontSize: 14,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded, 
        size: 16, 
        color: context.secondaryTextColor
      ),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
    );
  }
}
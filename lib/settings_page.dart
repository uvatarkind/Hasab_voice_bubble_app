import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SettingsTile(
            title: 'Language',
            subtitle: 'Choose the app language',
            icon: Icons.language,
          ),
          _SettingsTile(
            title: 'Permissions',
            subtitle: 'Manage required permissions',
            icon: Icons.security,
          ),
          _SettingsTile(
            title: 'Theme',
            subtitle: 'Light or dark mode',
            icon: Icons.color_lens,
          ),
          _SettingsTile(
            title: 'About',
            subtitle: 'App version and credits',
            icon: Icons.info_outline,
          ),
          _SettingsTile(
            title: 'Help',
            subtitle: 'FAQs and support',
            icon: Icons.help_outline,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF15151F),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.white),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.white54),
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$title settings coming soon')),
          );
        },
      ),
    );
  }
}

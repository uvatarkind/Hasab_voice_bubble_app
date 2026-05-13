import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'about_settings_page.dart';
import 'help_settings_page.dart';
import 'language_settings_page.dart';
import 'permissions_settings_page.dart';
import 'theme_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const _languageKey = 'settings_language';

  bool _loading = true;
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_languageKey);
    if (!mounted) return;
    setState(() {
      _language = stored?.trim().isNotEmpty == true ? stored! : 'English';
      _loading = false;
    });
  }

  Future<void> _saveLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
  }

  Future<void> _showLanguagePicker() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LanguageSettingsPage()),
    );
    await _loadSettings();
  }

  void _toggleTheme(bool isDark) {
    final mode = isDark ? ThemeMode.dark : ThemeMode.light;
    widget.onThemeModeChanged(mode);
  }

  Future<void> _openPermissions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PermissionsSettingsPage()),
    );
  }

  Future<void> _openTheme() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThemeSettingsPage(
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        ),
      ),
    );
  }

  Future<void> _openAbout() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutSettingsPage()),
    );
  }

  Future<void> _openHelp() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const HelpSettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.themeMode == ThemeMode.dark;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0C0F1E), Color(0xFF121C2C), Color(0xFF151A2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                  children: [
                    _SettingsSection(
                      title: 'Preferences',
                      children: [
                        _SettingsTile(
                          title: 'Language',
                          subtitle: _language,
                          icon: Icons.language,
                          onTap: _showLanguagePicker,
                        ),
                        _SettingsSwitchTile(
                          title: 'Dark mode',
                          subtitle: isDark ? 'Enabled' : 'Disabled',
                          icon: Icons.color_lens,
                          value: isDark,
                          onChanged: _toggleTheme,
                        ),
                        _SettingsTile(
                          title: 'Theme',
                          subtitle: 'Choose light or dark',
                          icon: Icons.palette_outlined,
                          onTap: _openTheme,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'Access',
                      children: [
                        _SettingsTile(
                          title: 'Permissions',
                          subtitle: 'Manage required access',
                          icon: Icons.security,
                          onTap: _openPermissions,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _SettingsSection(
                      title: 'Support',
                      children: [
                        _SettingsTile(
                          title: 'About',
                          subtitle: 'App version and credits',
                          icon: Icons.info_outline,
                          onTap: _openAbout,
                        ),
                        _SettingsTile(
                          title: 'Help',
                          subtitle: 'FAQs and support',
                          icon: Icons.help_outline,
                          onTap: _openHelp,
                        ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        for (final child in children) ...[
          child,
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFF15151F),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
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
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  const _SettingsSwitchTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF15151F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SwitchListTile(
        secondary: Icon(icon, color: Colors.white),
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
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF6B4DFF),
      ),
    );
  }
}

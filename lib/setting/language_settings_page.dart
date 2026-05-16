import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageSettingsPage extends StatefulWidget {
  const LanguageSettingsPage({super.key});

  @override
  State<LanguageSettingsPage> createState() => _LanguageSettingsPageState();
}

class _LanguageSettingsPageState extends State<LanguageSettingsPage> {
  static const _languageKey = 'settings_language';
  static const _options = ['English', 'Amharic', 'Afan Oromo', 'Tigrigna'];

  bool _loading = true;
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_languageKey);
    if (!mounted) return;
    setState(() {
      _language = stored?.trim().isNotEmpty == true ? stored! : 'English';
      _loading = false;
    });
  }

  Future<void> _setLanguage(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, value);
    if (!mounted) return;
    setState(() {
      _language = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Language',
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
                    const Text(
                      'Choose app language',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final option in _options)
                      _LanguageOptionTile(
                        value: option,
                        groupValue: _language,
                        onChanged: _setLanguage,
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LanguageOptionTile extends StatelessWidget {
  const _LanguageOptionTile({
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: RadioListTile<String>(
        value: value,
        groupValue: groupValue,
        onChanged: (next) {
          if (next != null) onChanged(next);
        },
        activeColor: const Color(0xFF6B4DFF),
        title: Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

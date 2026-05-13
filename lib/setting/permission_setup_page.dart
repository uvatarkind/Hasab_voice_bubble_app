import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shimmer/shimmer.dart';

class PermissionSetupPage extends StatefulWidget {
  const PermissionSetupPage({super.key});

  @override
  State<PermissionSetupPage> createState() => _PermissionSetupPageState();
}

class _PermissionSetupPageState extends State<PermissionSetupPage> {
  static const _textChannel = MethodChannel('com.hasabkey.voicebubble/text');

  bool _micGranted = false;
  bool _overlayGranted = false;
  bool _accessibilityEnabled = false;
  bool _notificationGranted = false;
  bool _navigated = false;
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    await _checkAll();
    if (mounted) {
      setState(() {
        _isInit = false;
      });
    }
  }

  bool get _allGranted =>
      _micGranted && _overlayGranted && _accessibilityEnabled && _notificationGranted;

  Future<void> _checkAll() async {
    final mic = await Permission.microphone.isGranted;
    final notification = await Permission.notification.isGranted;
    final overlay = await FlutterOverlayWindow.isPermissionGranted();
    final accessibility = await _checkAccessibility();

    if (!mounted) return;
    setState(() {
      _micGranted = mic;
      _notificationGranted = notification;
      _overlayGranted = overlay;
      _accessibilityEnabled = accessibility;
    });

    if (_allGranted) {
      _goNext();
    }
  }

  Future<bool> _checkAccessibility() async {
    try {
      final result = await _textChannel.invokeMethod('isAccessibilityEnabled');
      return result as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  void _goNext() {
    if (_navigated || !mounted) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0E1224), Color(0xFF1A1A2E)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: _isInit
              ? Shimmer.fromColors(
                  baseColor: Colors.white.withOpacity(0.1),
                  highlightColor: Colors.white.withOpacity(0.2),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Container(width: 200, height: 32, color: Colors.white),
                        const SizedBox(height: 12),
                        Container(width: 280, height: 16, color: Colors.white),
                        const SizedBox(height: 32),
                        for (int i = 0; i < 4; i++) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            width: double.infinity,
                            height: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      const Text(
                        'Permissions setup',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'We need a few permissions to run the voice bubble and insert text.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                const SizedBox(height: 20),
                _buildPermissionCard(),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _allGranted ? _goNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Continue'),
                  ),
                ),
                const SizedBox(height: 8),
                if (!_allGranted)
                  const Text(
                    'Grant all permissions to continue.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF15151F),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required permissions',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildPermissionTile(
            title: 'Display over apps',
            granted: _overlayGranted,
            onTap: () async {
              await FlutterOverlayWindow.requestPermission();
              await _checkAll();
            },
          ),
          const Divider(height: 24, color: Colors.white24),
          _buildPermissionTile(
            title: 'Accessibility Service',
            granted: _accessibilityEnabled,
            onTap: () async {
              try {
                await _textChannel.invokeMethod('openAccessibilitySettings');
              } catch (_) {}
            },
          ),
          const Divider(height: 24, color: Colors.white24),
          _buildPermissionTile(
            title: 'Microphone',
            granted: _micGranted,
            onTap: () async {
              await Permission.microphone.request();
              await _checkAll();
            },
          ),
          const Divider(height: 24, color: Colors.white24),
          _buildPermissionTile(
            title: 'Notifications',
            granted: _notificationGranted,
            onTap: () async {
              await Permission.notification.request();
              await _checkAll();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required bool granted,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.check,
                        size: 14,
                        color: granted ? Colors.greenAccent : Colors.grey,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        granted ? 'Granted' : 'Not granted',
                        style: TextStyle(
                          fontSize: 12,
                          color: granted ? Colors.greenAccent : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

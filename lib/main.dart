import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'overlay.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const HasabkeyApp());
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  debugPrint('[Hasabkey][overlay] overlayMain start');
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: BubbleOverlay(),
  ));
}

class HasabkeyApp extends StatelessWidget {
  const HasabkeyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hasabkey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2196F3),
          surface: Color(0xFF1A1A2E),
        ),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  static const _textChannel = MethodChannel('com.hasabkey.voicebubble/text');

  bool _overlayActive = false;
  bool _micGranted = false;
  bool _overlayGranted = false;
  bool _accessibilityEnabled = false;
  bool _notificationGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkAll();
    _listenOverlay();
    debugPrint('[Hasabkey] initState complete');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkAll();
    }
  }

  /// Listens for messages from the overlay (text insertion requests).
  void _listenOverlay() {
    FlutterOverlayWindow.overlayListener.listen((data) async {
      debugPrint('[Hasabkey] overlay message: $data');
      if (data is Map) {
        if (data['action'] == 'insertText') {
          try {
            await _textChannel.invokeMethod('insertText', {'text': data['text']});
            debugPrint('[Hasabkey] accessibility insertText invoked');
          } catch (_) {
            debugPrint('[Hasabkey] insertText failed');
          }
        } else if (data['action'] == 'insertInterim') {
          try {
            await _textChannel.invokeMethod('insertInterim', {'text': data['text']});
          } catch (_) {}
        }
      }
    });
  }

  Future<void> _checkAll() async {
    final mic = await Permission.microphone.isGranted;
    final notification = await Permission.notification.isGranted;
    final overlay = await FlutterOverlayWindow.isPermissionGranted();
    final accessibility = await _checkAccessibility();
    final active = await FlutterOverlayWindow.isActive();

    setState(() {
      _micGranted = mic;
      _notificationGranted = notification;
      _overlayGranted = overlay;
      _accessibilityEnabled = accessibility;
      _overlayActive = active;
    });

    debugPrint(
      '[Hasabkey] permissions mic=$mic notification=$notification overlay=$overlay accessibility=$accessibility active=$active',
    );
  }

  Future<bool> _checkAccessibility() async {
    try {
      final result = await _textChannel.invokeMethod('isAccessibilityEnabled');
      debugPrint('[Hasabkey] accessibility check result: $result');
      return result as bool? ?? false;
    } catch (_) {
      debugPrint('[Hasabkey] accessibility check failed');
      return false;
    }
  }

  Future<void> _toggleBubble() async {
    debugPrint('[Hasabkey] toggle bubble (active=$_overlayActive)');
    if (_overlayActive) {
      await FlutterOverlayWindow.closeOverlay();
      debugPrint('[Hasabkey] overlay close requested');
    } else {
      // Check permissions first
      if (!_micGranted) {
        final status = await Permission.microphone.request();
        debugPrint('[Hasabkey] microphone request result: $status');
        if (!status.isGranted) {
          _showSnack('Microphone permission required');
          return;
        }
      }

      // Android 13+ notification permission is required for Foreground Services
      final notificationStatus = await Permission.notification.request();
      debugPrint('[Hasabkey] notification request result: $notificationStatus');

      if (!_overlayGranted) {
        final granted = await FlutterOverlayWindow.requestPermission();
        debugPrint('[Hasabkey] overlay permission request result: $granted');
        if (granted != true) {
          _showSnack('Overlay permission required');
          return;
        }
      }

      if (!_accessibilityEnabled) {
        _showSnack('Please enable Hasabkey in Accessibility settings');
        try {
          await _textChannel.invokeMethod('openAccessibilitySettings');
          debugPrint('[Hasabkey] opened accessibility settings');
        } catch (_) {}
        return;
      }

      await FlutterOverlayWindow.showOverlay(
        enableDrag: true,
        overlayTitle: 'Hasabkey',
        overlayContent: 'Dictation active',
        flag: OverlayFlag.defaultFlag,
        visibility: NotificationVisibility.visibilityPublic,
        positionGravity: PositionGravity.none,
        height: 120,
        width: 120,
        alignment: OverlayAlignment.centerRight,
        startPosition: const OverlayPosition(0, 0),
      );
      debugPrint('[Hasabkey] overlay show requested');
    }

    await _checkAll();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              _buildPermissionCard(),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _toggleBubble,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _overlayActive ? Colors.red : Colors.green,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(_overlayActive ? 'Stop Bubble' : 'Start Bubble'),
                ),
              ),
            ],
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
            'Permissions',
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
          const SizedBox(height: 12),
          Text(
            'Bubble: ${_overlayActive ? "Active" : "Inactive"}',
            style: TextStyle(
              fontSize: 13,
              color: _overlayActive ? Colors.greenAccent : Colors.grey,
            ),
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

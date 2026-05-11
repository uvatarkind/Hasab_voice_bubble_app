import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'overlay.dart';
import 'notes_page.dart';
import 'permission_setup_page.dart';
import 'settings_page.dart';
import 'splash_screen.dart';

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
      initialRoute: '/splash',
      routes: {
        '/splash': (_) => const SplashScreen(),
        '/permissions': (_) => const PermissionSetupPage(),
        '/home': (_) => const HomePage(),
        '/notes': (_) => const NotesPage(),
        '/settings': (_) => const SettingsPage(),
      },
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
  static Stream<dynamic>? _overlayStream;

  StreamSubscription<dynamic>? _overlaySub;

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
    _overlaySub?.cancel();
    _overlaySub = null;
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
    if (_overlaySub != null) return;
    _overlayStream ??= FlutterOverlayWindow.overlayListener.asBroadcastStream();
    _overlaySub = _overlayStream!.listen((data) async {
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
      appBar: AppBar(
        title: const Text('Hasab Bubble'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/notes'),
            icon: const Icon(Icons.note_alt_outlined),
            tooltip: 'Notes',
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: _toggleBubble,
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _overlayActive ? Colors.red : Colors.green,
                        boxShadow: [
                          BoxShadow(
                            color: (_overlayActive ? Colors.red : Colors.green)
                                .withOpacity(0.35),
                            blurRadius: 24,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _overlayActive ? Icons.stop : Icons.mic,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _overlayActive ? 'Stop' : 'Start',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
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
          ),
        ),
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:permission_handler/permission_handler.dart';
import 'bubble/overlay.dart';
import 'note/notes_page.dart';
import 'setting/permission_setup_page.dart';
import 'setting/settings_page.dart';
import 'splash_screen.dart';
import 'widget/bubble_toggle_button.dart';

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
  Timer? _overlayPoller;
  bool _overlayPollInFlight = false;

  int _forceInactiveUntilMs = 0;
  bool _forceInactive = false;

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
    _startOverlayPolling();
    debugPrint('[Hasabkey] initState complete');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlaySub?.cancel();
    _overlaySub = null;
    _overlayPoller?.cancel();
    _overlayPoller = null;
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
        } else if (data['action'] == 'overlayClosed') {
          debugPrint('[Hasabkey] overlay closed by user');
          if (mounted) {
            setState(() {
              _overlayActive = false;
            });
          }
          _forceInactive = true;
          _forceInactiveUntilMs =
              DateTime.now().millisecondsSinceEpoch + 5000;
          Future.delayed(const Duration(milliseconds: 300), _checkAll);
        }
      }
    });
  }

  void _startOverlayPolling() {
    _overlayPoller ??= Timer.periodic(
      const Duration(milliseconds: 500),
      (_) async {
        if (_overlayPollInFlight || !mounted) return;
        _overlayPollInFlight = true;
        try {
          final active = await FlutterOverlayWindow.isActive();
          if (!mounted) return;
          if (!active && _forceInactive) {
            _forceInactive = false;
            _forceInactiveUntilMs = 0;
          }
          if (!_forceInactive && _overlayActive != active) {
            setState(() {
              _overlayActive = active;
            });
          }
        } finally {
          _overlayPollInFlight = false;
        }
      },
    );
  }

  Future<void> _checkAll() async {
    final mic = await Permission.microphone.isGranted;
    final notification = await Permission.notification.isGranted;
    final overlay = await FlutterOverlayWindow.isPermissionGranted();
    final accessibility = await _checkAccessibility();
    final active = await FlutterOverlayWindow.isActive();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final effectiveActive =
      _forceInactive || nowMs < _forceInactiveUntilMs ? false : active;

    setState(() {
      _micGranted = mic;
      _notificationGranted = notification;
      _overlayGranted = overlay;
      _accessibilityEnabled = accessibility;
      _overlayActive = effectiveActive;
    });

    debugPrint(
      '[Hasabkey] permissions mic=$mic notification=$notification overlay=$overlay accessibility=$accessibility active=$effectiveActive',
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
      if (mounted) {
        setState(() {
          _overlayActive = false;
        });
      }
      _forceInactive = true;
      _forceInactiveUntilMs =
          DateTime.now().millisecondsSinceEpoch + 5000;
      await FlutterOverlayWindow.closeOverlay();
      debugPrint('[Hasabkey] overlay close requested');
      Future.delayed(const Duration(milliseconds: 300), _checkAll);
      return;
    } else {
      _forceInactive = false;
      _forceInactiveUntilMs = 0;
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
                    BubbleToggleButton(
                      isActive: _overlayActive,
                      onTap: _toggleBubble,
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

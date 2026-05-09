import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:record/record.dart';

import 'asr_client.dart';

/// 500ms of 16-bit mono at 16kHz = 16000 bytes
const _chunkSize = 16000;

class BubbleOverlay extends StatefulWidget {
  const BubbleOverlay({super.key});

  @override
  State<BubbleOverlay> createState() => _BubbleOverlayState();
}

class _BubbleOverlayState extends State<BubbleOverlay>
    with SingleTickerProviderStateMixin {
  static const _textChannel = MethodChannel('com.hasabkey.voicebubble/text');

  bool _isRecording = false;
  bool _showCloseArea = false;
  AsrClient? _asr;
  AudioRecorder? _recorder;
  StreamSubscription? _audioSub;
  final _audioBuffer = BytesBuilder(copy: false);

  final List<String> _finalSegments = [];
  String _currentInterim = '';
  String _displayText = '';

  AnimationController? _orbController;

  @override
  void dispose() {
    _orbController?.dispose();
    _stopRecording();
    super.dispose();
  }

  void _toggle() {
    debugPrint('[Hasabkey][overlay] bubble tapped (isRecording=$_isRecording)');
    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  @override
  void initState() {
    super.initState();
    _ensureOrbController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureOrbController();
  }

  void _ensureOrbController() {
    if (_orbController != null) return;
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  void _handleLongPress() {
    debugPrint('[Hasabkey][overlay] Long press detected');
    // Vibrate to give feedback
    HapticFeedback.heavyImpact();
    
    setState(() {
      _showCloseArea = true;
    });
    // Increase window size to ensure the "Close" pill is clickable
    FlutterOverlayWindow.resizeOverlay(120, 160, true);
    
    // Hide close area after 4 seconds if not used
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted && _showCloseArea) {
        setState(() {
          _showCloseArea = false;
        });
        if (!_isRecording) {
          FlutterOverlayWindow.resizeOverlay(120, 120, true);
        }
      }
    });
  }

  Future<void> _closeBubble() async {
    await _stopRecording();
    await FlutterOverlayWindow.closeOverlay();
  }

  Future<void> _startRecording() async {
    debugPrint('[Hasabkey][overlay] start recording');
    setState(() {
      _isRecording = true;
      _finalSegments.clear();
      _currentInterim = '';
      _displayText = 'Listening\u2026';
    });

    await FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 120, false);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.flagNotFocusable);

    _asr = AsrClient();
    _asr!.onInterimResult = (text) {
      debugPrint('[Hasabkey][overlay] interim: $text');
      _currentInterim = text;
      _updateDisplay();
      // Send interim text for real-time insertion
      _textChannel
          .invokeMethod('insertInterim', {'text': text})
          .catchError((_) {});
      FlutterOverlayWindow.shareData({'action': 'insertInterim', 'text': text});
    };
    _asr!.onFinalResult = (text) {
      debugPrint('[Hasabkey][overlay] final: $text');
      _finalSegments.add(text);
      _currentInterim = '';
      _updateDisplay();
      _textChannel.invokeMethod('insertText', {'text': text}).catchError((_) {});
      FlutterOverlayWindow.shareData({'action': 'insertText', 'text': text});
    };
    _asr!.onError = (error) {
      debugPrint('[Hasabkey][overlay] error: $error');
      setState(() {
        _displayText = 'Error: $error';
      });
      _stopRecording();
    };
    _asr!.onReady = () async {
      debugPrint('[Hasabkey][overlay] asr ready, starting mic stream');
      _recorder = AudioRecorder();
      final stream = await _recorder!.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      _audioBuffer.clear();
      _audioSub = stream.listen((data) {
        _audioBuffer.add(data);
        while (_audioBuffer.length >= _chunkSize) {
          final bytes = _audioBuffer.takeBytes();
          _asr?.sendAudio(Uint8List.fromList(bytes.sublist(0, _chunkSize)));
          if (bytes.length > _chunkSize) {
            _audioBuffer.add(bytes.sublist(_chunkSize));
          }
        }
      });
    };

    _asr!.connect();
  }

  Future<void> _stopRecording() async {
    debugPrint('[Hasabkey][overlay] _stopRecording CALLED');
    if (!_isRecording && _asr == null) {
      debugPrint('[Hasabkey][overlay] _stopRecording early return: not recording');
      return;
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _showCloseArea = false;
        _displayText = '';
      });
    }

    await FlutterOverlayWindow.resizeOverlay(120, 120, true);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);

    _audioSub?.cancel();
    _audioSub = null;

    try {
      // Flush remaining buffered audio
      if (_audioBuffer.length > 0) {
        _asr?.sendAudio(Uint8List.fromList(_audioBuffer.takeBytes()));
      }
      await _recorder?.stop();
      await _recorder?.dispose();
    } catch (e) {
      debugPrint('[Hasabkey][overlay] Error stopping recorder: $e');
    }

    _recorder = null;
    _asr?.close();
    _asr = null;

    final text = _finalSegments.join(' ').trim();
    if (text.isNotEmpty) {
      debugPrint('[Hasabkey][overlay] inserting text (${text.length} chars)');

      // Step 1: Write pending file FIRST (guaranteed fallback)
      try {
        final dir = Directory('/data/data/com.hasabkey.voicebubble/files');
        final file = File('${dir.path}/pending_insert.txt');
        await file.writeAsString(text);
        debugPrint('[Hasabkey][overlay] pending file written');
      } catch (e) {
        debugPrint('[Hasabkey][overlay] pending file failed: $e');
      }

      // Always copy to clipboard as safety net
      await Clipboard.setData(ClipboardData(text: text));
    }

    // Give Android a moment to return focus to the underlying app
    await Future.delayed(const Duration(milliseconds: 300));

    // Step 3: Now try active insertion (text field may have focus again)
    if (text.isNotEmpty) {
      // Try direct MethodChannel (works if HasabkeyPlugin is registered in this engine)
      try {
        await _textChannel.invokeMethod('insertText', {'text': text});
        debugPrint('[Hasabkey][overlay] MethodChannel insertText succeeded');
      } catch (e) {
        debugPrint('[Hasabkey][overlay] MethodChannel failed: $e');
      }

      // Send to main app (triggers plugin which tries static call + scheduled checks)
      FlutterOverlayWindow.shareData({'action': 'insertText', 'text': text});
      debugPrint('[Hasabkey][overlay] shareData sent');
    }
  }

  void _updateDisplay() {
    final parts = List<String>.from(_finalSegments);
    if (_currentInterim.isNotEmpty) parts.add(_currentInterim);
    setState(() {
      _displayText = parts.join(' ');
      if (_displayText.isEmpty) _displayText = 'Listening\u2026';
    });
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[Hasabkey][overlay] build called (isRecording=$_isRecording)');
    return Material(
      type: MaterialType.canvas,
      color: Colors.transparent,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          if (_showCloseArea)
            Positioned(
              top: 0,
              child: GestureDetector(
                onTap: () {
                  debugPrint('[Hasabkey][overlay] Close button tapped');
                  _closeBubble();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.close, color: Colors.white, size: 20),
                      SizedBox(width: 6),
                      Text(
                        'Remove Bubble',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Positioned(
            top: _showCloseArea ? 60 : 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: _buildContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (!_isRecording) {
      return GestureDetector(
        key: const ValueKey('mic_bubble'),
        onTap: _toggle,
        onLongPress: _handleLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 80,
          height: 80,
          alignment: Alignment.center,
          child: _buildOrb(),
        ),
      );
    }

    return GestureDetector(
      key: const ValueKey('stop_bar'),
      onTap: () {
        debugPrint('[Hasabkey][overlay] Stop Bar Tapped');
        _stopRecording();
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 70,
        margin: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.85),
          borderRadius: BorderRadius.circular(35),
          border: Border.all(color: Colors.red.withOpacity(0.5), width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red.withOpacity(0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    spreadRadius: 2,
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.stop, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Text(
                  _displayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrb() {
    final controller = _orbController;
    if (controller == null) {
      return const _StaticOrb();
    }
    return _AnimatedOrb(controller: controller);
  }
}

class _StaticOrb extends StatelessWidget {
  const _StaticOrb();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(64, 64),
      painter: _OrbPainter(progress: 0.0),
      child: const SizedBox(
        width: 64,
        height: 64,
        child: Icon(Icons.mic, color: Colors.white, size: 28),
      ),
    );
  }
}

class _AnimatedOrb extends StatelessWidget {
  const _AnimatedOrb({required this.controller});

  final Animation<double> controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(64, 64),
          painter: _OrbPainter(progress: controller.value),
          child: const SizedBox(
            width: 64,
            height: 64,
            child: Icon(Icons.mic, color: Colors.white, size: 28),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF9A6BFF).withOpacity(0.9),
          const Color(0xFF5B2BFF).withOpacity(0.55),
          const Color(0xFF1A0B2E).withOpacity(0.0),
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.2));
    canvas.drawCircle(center, radius * 1.05, glowPaint);

    final basePaint = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: 6.283185307179586,
        colors: [
          const Color(0xFFB67BFF),
          const Color(0xFF6A35FF),
          const Color(0xFF2A124F),
          const Color(0xFFB67BFF),
        ],
        stops: const [0.0, 0.45, 0.75, 1.0],
        transform: GradientRotation(progress * 6.283185307179586),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    final blurPaint = Paint()
      ..color = const Color(0xFF7B4CFF).withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    canvas.drawCircle(center, radius, blurPaint);
    canvas.drawCircle(center, radius * 0.95, basePaint);

    final wavePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFFFFFFFF).withOpacity(0.0),
          const Color(0xFFFFFFFF).withOpacity(0.35),
          const Color(0xFFFFFFFF).withOpacity(0.0),
        ],
        stops: const [0.2, 0.5, 0.8],
        begin: Alignment(-1 + (progress * 2), -1),
        end: Alignment(1 + (progress * 2), 1),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius * 0.75, wavePaint);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

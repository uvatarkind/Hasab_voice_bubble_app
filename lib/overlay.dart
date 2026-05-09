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

class _BubbleOverlayState extends State<BubbleOverlay> {
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

  @override
  void dispose() {
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
      // Send interim text to main app for real-time insertion
      FlutterOverlayWindow.shareData({'action': 'insertInterim', 'text': text});
    };
    _asr!.onFinalResult = (text) {
      debugPrint('[Hasabkey][overlay] final: $text');
      _finalSegments.add(text);
      _currentInterim = '';
      _updateDisplay();
      // Send final segment to main app
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
    
    _audioSub?.cancel();
    _audioSub = null;

    setState(() {
      _displayText = 'Closing...';
    });

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

    // Step 2: Shrink overlay BEFORE trying insertion
    // This lets the underlying text field regain focus
    if (mounted) {
      setState(() {
        _isRecording = false;
        _displayText = '';
      });
    }

    debugPrint('[Hasabkey][overlay] UI reset, resizing to 120x120');
    await FlutterOverlayWindow.resizeOverlay(120, 120, true);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);

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
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.blue.withOpacity(0.9),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.mic, color: Colors.white, size: 30),
          ),
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
}

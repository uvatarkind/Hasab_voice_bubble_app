import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hasabkey/bubble/asr_client.dart';
import 'package:rive/rive.dart' hide LinearGradient;
import 'package:record/record.dart';

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
  bool _showLanguageSheet = false;
  String _selectedLanguage = 'Amharic';
  AsrClient? _asr;
  AudioRecorder? _recorder;
  StreamSubscription? _audioSub;
  final _audioBuffer = BytesBuilder(copy: false);

  final List<String> _finalSegments = [];
  String _currentInterim = '';
  String _displayText = '';
  final ScrollController _transcriptScroll = ScrollController();

  @override
  void dispose() {
    _transcriptScroll.dispose();
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
    _showLanguageSheet = false;
  }

  void _handleLongPress() {
    debugPrint('[Hasabkey][overlay] Long press detected');
    // Vibrate to give feedback
    HapticFeedback.heavyImpact();
    
    setState(() {
      _showLanguageSheet = true;
    });
    // Increase window size to show the language selector card
    FlutterOverlayWindow.resizeOverlay(320, 160, true);
  }

  Future<void> _applyOverlaySize() async {
    if (_isRecording) {
      await FlutterOverlayWindow.resizeOverlay(120, 180, false);
      return;
    }

    if (_showLanguageSheet) {
      await FlutterOverlayWindow.resizeOverlay(320, 160, true);
      return;
    }

    await FlutterOverlayWindow.resizeOverlay(120, 120, true);
  }

  void _selectLanguage(String label) {
    if (!mounted) return;
    setState(() {
      _selectedLanguage = label;
      _showLanguageSheet = false;
    });
    _applyOverlaySize();
  }

  Future<void> _closeBubble() async {
    if (mounted) {
      setState(() {
        _showLanguageSheet = false;
      });
    }
    await _stopRecording();
    FlutterOverlayWindow.shareData({'action': 'overlayClosed'});
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

    await FlutterOverlayWindow.resizeOverlay(120, 180, false);
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
    _asr!.onStatus = (message) {
      debugPrint('[Hasabkey][overlay] status: $message');
      if (!mounted) return;
      setState(() {
        _displayText = message;
      });
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
      if (mounted) {
        setState(() {
          _showLanguageSheet = false;
          _displayText = '';
        });
      }
      debugPrint('[Hasabkey][overlay] _stopRecording early return: not recording');
      return;
    }

    if (mounted) {
      setState(() {
        _isRecording = false;
        _showLanguageSheet = false;
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
    _scrollTranscriptToBottom();
  }

  void _scrollTranscriptToBottom() {
    if (!_transcriptScroll.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_transcriptScroll.hasClients) return;
      _transcriptScroll.animateTo(
        _transcriptScroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
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
          Center(
            child: _showLanguageSheet
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _buildLanguageSelectorCard(),
                    ),
                  )
                : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (!_isRecording) {
      final bubble = GestureDetector(
        key: const ValueKey('mic_bubble'),
        onTap: _toggle,
        onLongPress: _handleLongPress,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: 88,
          height: 88,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF1A2138), Color(0xFF0F1529)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B4DFF).withOpacity(0.28),
                blurRadius: 16,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: _buildOrb(),
        ),
      );

      if (_showLanguageSheet) {
        return const SizedBox.shrink();
      }

      if (!_showLanguageSheet) {
        return bubble;
      }
    }

    return GestureDetector(
      key: const ValueKey('stop_bar'),
      onTap: () {
        debugPrint('[Hasabkey][overlay] Stop Bar Tapped');
        _stopRecording();
      },
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxHeight < 170 ||
              constraints.maxWidth < 140 ||
              !constraints.hasBoundedHeight;
            final width = constraints.hasBoundedWidth
              ? (constraints.maxWidth < 148.0
                ? constraints.maxWidth
                : 148.0)
              : 148.0;
          final verticalPadding = isCompact ? 8.0 : 12.0;

          return Container(
            width: width,
            padding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: verticalPadding,
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1C2135), Color(0xFF12172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.6),
                  blurRadius: 16,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: _buildStopBarContent(isCompact: isCompact),
          );
        },
      ),
    );
  }

  Widget _buildStopBarContent({required bool isCompact}) {
    final buttonSize = isCompact ? 40.0 : 52.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 8 : 10,
            vertical: isCompact ? 3 : 4,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF2A173E),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFF6B4DFF)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFF6B6B),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Recording',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isCompact ? 10 : 11,
                  decoration: TextDecoration.none,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        SizedBox(
          height: isCompact ? 36 : 66,
          child: SingleChildScrollView(
            controller: _transcriptScroll,
            child: Text(
              _displayText,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: isCompact ? 10.5 : 12.5,
                decoration: TextDecoration.none,
                fontWeight: FontWeight.w600,
              ),
              softWrap: true,
            ),
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        Container(
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5A79), Color(0xFFFF2E5C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFF2E5C).withOpacity(0.4),
                blurRadius: 12,
              ),
            ],
          ),
          child: Icon(
            Icons.stop,
            color: Colors.white,
            size: isCompact ? 22 : 26,
          ),
        ),
      ],
    );
  }

  Widget _buildOrb() {
    return SizedBox(
      width: 64,
      height: 64,
      child: RiveAnimation.asset(
        'assets/orbe.riv',
        fit: BoxFit.contain,
        onInit: _onRiveInit,
      ),
    );
  }

  static void _onRiveInit(Artboard artboard) {
    const backgroundHints = ['background', 'bg', 'backdrop'];
    artboard.forEachComponent((component) {
      final name = component.name.toLowerCase();
      if (backgroundHints.any(name.contains)) {
        final dynamic dyn = component;
        try {
          dyn.isHidden = true;
          return;
        } catch (_) {}
        try {
          dyn.opacity = 0.0;
        } catch (_) {}
      }
    });
  }

  Widget _buildLanguageSelectorCard() {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.65),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.45),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current: $_selectedLanguage',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _buildLanguageChip('Amharic'),
              _buildLanguageChip('Afan Oromo'),
              _buildLanguageChip('Tigrigna'),
            ],
          ),
          const SizedBox(height: 5),
          Divider(color: Colors.white.withOpacity(0.12), height: 1),
          const SizedBox(height: 5),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _closeBubble,
              icon: const Icon(Icons.close, size: 10),
              label: const Text('Remove bubble'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
  
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String label) {
    final selected = _selectedLanguage == label;
    return GestureDetector(
      onTap: () => _selectLanguage(label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFA78BFF)
              : Colors.white.withOpacity(0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white70,
            fontSize: 12,
            decoration: TextDecoration.none,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}


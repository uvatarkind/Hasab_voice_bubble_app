import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

class AsrClient {
  final String host;
  final String lang;
  final int maxRetries;
  final Duration baseRetryDelay;

  WebSocketChannel? _channel;
  Timer? _reconnectTimer;
  bool _closed = false;
  int _retryCount = 0;

  void Function(String text)? onInterimResult;
  void Function(String text)? onFinalResult;
  void Function(String error)? onError;
  void Function()? onReady;
  void Function(String message)? onStatus;

  AsrClient({
    this.host = '18.224.41.27',
    this.lang = 'amh',
    this.maxRetries = 4,
    this.baseRetryDelay = const Duration(milliseconds: 600),
  });

  void connect() {
    _closed = false;
    _retryCount = 0;
    _connectInternal();
  }

  void _connectInternal() {
    final uri = Uri.parse(
      'ws://$host/api/v1/ws/transcribe?lang=$lang&number_to_digit=true&interim_results=true',
    );

    onStatus?.call('Connecting to ASR...');
    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        if (message is String) _handleMessage(message);
      },
      onError: (error) {
        _scheduleReconnect(error.toString());
      },
      onDone: () {
        if (!_closed) {
          _scheduleReconnect('Connection closed');
        }
      },
    );
  }

  void _handleMessage(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final type = json['type'] as String?;

    switch (type) {
      case 'Metadata':
        _retryCount = 0;
        onStatus?.call('ASR connected');
        onReady?.call();
        break;

      case 'Results':
        final isFinal = json['is_final'] as bool;
        final speechFinal = json['speech_final'] as bool;
        final channel = json['channel'] as Map<String, dynamic>;
        final alternatives = channel['alternatives'] as List;
        final transcript = alternatives[0]['transcript'] as String;

        if (transcript.trim().isNotEmpty) {
          if (isFinal && speechFinal) {
            onFinalResult?.call(transcript);
          } else {
            onInterimResult?.call(transcript);
          }
        }
        break;

      case 'Error':
        _scheduleReconnect(json['message'] as String? ?? 'Unknown error');
        break;
    }
  }

  void _scheduleReconnect(String error) {
    if (_closed) return;
    if (_retryCount >= maxRetries) {
      onError?.call('ASR connection failed: $error');
      return;
    }

    _retryCount += 1;
    final delayMs = (baseRetryDelay.inMilliseconds * (1 << (_retryCount - 1)))
        .clamp(600, 8000);
    onStatus?.call('ASR error. Retrying in ${delayMs ~/ 1000}s...');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(milliseconds: delayMs), () {
      if (_closed) return;
      _connectInternal();
    });
  }

  void sendAudio(Uint8List data) {
    _channel?.sink.add(data);
  }

  void close() {
    _closed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _channel?.sink.add(jsonEncode({'type': 'CloseStream'}));
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}

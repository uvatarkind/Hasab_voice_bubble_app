import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/web_socket_channel.dart';

class AsrClient {
  final String host;
  final String lang;

  WebSocketChannel? _channel;

  void Function(String text)? onInterimResult;
  void Function(String text)? onFinalResult;
  void Function(String error)? onError;
  void Function()? onReady;

  AsrClient({this.host = '18.224.41.27', this.lang = 'amh'});

  void connect() {
    final uri = Uri.parse(
      'ws://$host/api/v1/ws/transcribe?lang=$lang&number_to_digit=true&interim_results=true',
    );

    _channel = WebSocketChannel.connect(uri);

    _channel!.stream.listen(
      (message) {
        if (message is String) _handleMessage(message);
      },
      onError: (error) => onError?.call(error.toString()),
      onDone: () {},
    );
  }

  void _handleMessage(String raw) {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final type = json['type'] as String?;

    switch (type) {
      case 'Metadata':
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
        onError?.call(json['message'] as String? ?? 'Unknown error');
        break;
    }
  }

  void sendAudio(Uint8List data) {
    _channel?.sink.add(data);
  }

  void close() {
    try {
      _channel?.sink.add(jsonEncode({'type': 'CloseStream'}));
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }
}

# Hasabkey (Flutter)

Voice dictation floating bubble for Android. Almost entirely Dart — only the accessibility service (text insertion) is native Kotlin.

## Architecture

```
lib/
├── main.dart        → Settings UI, permissions, overlay control
├── overlay.dart     → Bubble overlay (recording, WebSocket, transcript) — all Dart
└── asr_client.dart  → WebSocket ASR client — pure Dart

android/.../kotlin/  (only 2 files, ~80 lines total — do not need to modify)
├── MainActivity.kt                    → Bridges text insertion to Flutter
└── TextInsertionAccessibilityService.kt → Inserts text into focused fields
```

### What's in Dart vs Kotlin

| Feature | Language | Package |
|---------|----------|---------|
| Settings UI | Dart | Flutter |
| Floating bubble overlay | Dart | `flutter_overlay_window` |
| Audio recording (16kHz PCM) | Dart | `record` |
| WebSocket ASR streaming | Dart | `web_socket_channel` |
| Permissions | Dart | `permission_handler` |
| Text insertion into other apps | Kotlin | Android AccessibilityService (no Dart API exists) |

## How it works

1. Launch app — permissions screen shows status
2. Tap **Start Bubble** — a draggable blue circle appears over all apps
3. Tap the bubble — it turns red, starts recording, shows live transcription
4. Tap again — stops recording, inserts finalized text into the focused text field
5. Text is also copied to clipboard as fallback

## Build & Run

```bash
flutter pub get
flutter run
```

## Required permissions

| Permission | Why |
|---|---|
| Microphone | Voice capture |
| Display over other apps | Floating bubble |
| Accessibility | Insert text into any app's text field |

## ASR Server

Streams audio via WebSocket to:

```
ws://18.224.41.27/api/v1/ws/transcribe?lang=amh&number_to_digit=true&interim_results=true
```

The server host and language are configured in `lib/asr_client.dart` (defaults: `18.224.41.27`, `amh`).

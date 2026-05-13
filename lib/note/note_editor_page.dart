import 'package:flutter/material.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.note});

  final Note? note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    _saveAndPop();
    return false;
  }

  void _saveAndPop() {
    final content = _controller.text.trimRight();
    if (content.trim().isEmpty) {
      Navigator.of(context).pop(null);
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final note = (widget.note ?? Note.newNote())
        .copyWith(content: content, updatedAt: now);
    Navigator.of(context).pop(note);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _handleBack,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text(
            'Write note',
            style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
          ),
          actions: [
            IconButton(
              onPressed: _saveAndPop,
              icon: const Icon(Icons.save),
              tooltip: 'Save',
            ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0C0F1E), Color(0xFF121C2C), Color(0xFF151A2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                cursorColor: Colors.white70,
                decoration: InputDecoration(
                  hintText: 'Write your notes here...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF141928),
                  contentPadding: const EdgeInsets.all(16),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
                style: const TextStyle(color: Colors.white, height: 1.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Note {
  const Note({
    required this.id,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String content;
  final int updatedAt;

  static Note newNote() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Note(id: now.toString(), content: '', updatedAt: now);
  }

  Note copyWith({String? content, int? updatedAt}) {
    return Note(
      id: id,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'updatedAt': updatedAt,
    };
  }

  static Note fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      content: json['content'] as String? ?? '',
      updatedAt: json['updatedAt'] as int? ?? 0,
    );
  }
}

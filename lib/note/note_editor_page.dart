import 'package:flutter/material.dart';

class NoteEditorPage extends StatefulWidget {
  const NoteEditorPage({super.key, this.note});

  final Note? note;

  @override
  State<NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<NoteEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _controller;
  late final String _defaultTitle;

  @override
  void initState() {
    super.initState();
    _defaultTitle = _formatDate(
      widget.note?.updatedAt ?? DateTime.now().millisecondsSinceEpoch,
    );
    final initialTitle = widget.note?.title?.trim();
    _titleController = TextEditingController(
      text: (initialTitle == null || initialTitle.isEmpty)
          ? _defaultTitle
          : initialTitle,
    );
    _controller = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _handleBack() async {
    _saveAndPop();
    return false;
  }

  void _saveAndPop() {
    final content = _controller.text.trimRight();
    final title = _titleController.text.trim();
    if (content.trim().isEmpty) {
      Navigator.of(context).pop(const NoteEditorResult.deleted());
      return;
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final note = (widget.note ?? Note.newNote())
        .copyWith(
          title: title.isEmpty ? _defaultTitle : title,
          content: content,
          updatedAt: now,
        );
    Navigator.of(context).pop(NoteEditorResult.saved(note));
  }

  void _confirmDelete() {
    if (widget.note == null) {
      Navigator.of(context).pop(const NoteEditorResult.deleted());
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete note?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context)
                  .pop(const NoteEditorResult.deleted());
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
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
              onPressed: _confirmDelete,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
            ),
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
              child: Column(
                children: [
                  TextField(
                    controller: _titleController,
                    textInputAction: TextInputAction.next,
                    cursorColor: Colors.white70,
                    decoration: InputDecoration(
                      hintText: 'Title',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF141928),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    onSubmitted: (_) => FocusScope.of(context).nextFocus(),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NoteEditorResult {
  const NoteEditorResult._({required this.saved, this.note});

  const NoteEditorResult.saved(Note note) : this._(saved: true, note: note);

  const NoteEditorResult.deleted() : this._(saved: false);

  final bool saved;
  final Note? note;
}

class Note {
  const Note({
    required this.id,
    this.title,
    required this.content,
    required this.updatedAt,
  });

  final String id;
  final String? title;
  final String content;
  final int updatedAt;

  static Note newNote() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Note(id: now.toString(), content: '', updatedAt: now);
  }

  Note copyWith({String? title, String? content, int? updatedAt}) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'updatedAt': updatedAt,
    };
  }

  static Note fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String?,
      content: json['content'] as String? ?? '',
      updatedAt: json['updatedAt'] as int? ?? 0,
    );
  }
}

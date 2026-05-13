import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'note_editor_page.dart';

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  static const _storageKey = 'notes_v1';

  List<Note> _notes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    final notes = <Note>[];

    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as List<dynamic>;
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            notes.add(Note.fromJson(item));
          } else if (item is Map) {
            notes.add(Note.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      } catch (_) {}
    }

    notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (!mounted) return;
    setState(() {
      _notes = notes;
      _loading = false;
    });
  }

  Future<void> _saveNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final payload = jsonEncode(_notes.map((n) => n.toJson()).toList());
    await prefs.setString(_storageKey, payload);
  }

  Future<void> _openEditor({Note? note}) async {
    final result = await Navigator.of(context).push<NoteEditorResult?>(
      MaterialPageRoute(builder: (_) => NoteEditorPage(note: note)),
    );

    if (result == null) return;

    if (!result.saved) {
      if (note == null) return;
      setState(() {
        _notes.removeWhere((n) => n.id == note.id);
      });
      await _saveNotes();
      return;
    }

    final savedNote = result.note;
    if (savedNote == null) return;

    final index = _notes.indexWhere((n) => n.id == savedNote.id);
    setState(() {
      if (index >= 0) {
        _notes[index] = savedNote;
      } else {
        _notes.insert(0, savedNote);
      }
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });

    await _saveNotes();
  }

  String _noteTitle(Note note) {
    final title = note.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    return _formatDate(note.updatedAt);
  }

  String _notePreview(Note note) {
    final clean = note.content.replaceAll('\n', ' ').trim();
    if (clean.length <= 90) return clean;
    return '${clean.substring(0, 90)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Notes',
          style: TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        actions: [
          IconButton(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.edit_note),
            tooltip: 'New note',
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
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _notes.isEmpty
                  ? _buildEmptyState()
                  : _buildNotesGrid(),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.06),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: const Icon(
              Icons.note_alt_outlined,
              size: 40,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No notes yet',
            style: TextStyle(fontSize: 18, color: Colors.white),
          ),
          const SizedBox(height: 6),
          const Text(
            'Create your first note to get started',
            style: TextStyle(fontSize: 13, color: Colors.white60),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.edit),
            label: const Text('Write a note'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00A8FF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 420;
        final horizontalPadding = isNarrow ? 10.0 : 16.0;
        final spacing = isNarrow ? 10.0 : 14.0;
        final childAspectRatio = isNarrow ? 0.6 : 0.85;
        final tilePadding = isNarrow ? 12.0 : 16.0;
        final titleFontSize = isNarrow ? 13.5 : 15.0;
        final previewLines = isNarrow ? 4 : 5;
        final previewFontSize = isNarrow ? 11.5 : 12.5;
        const crossAxisCount = 3;
        return Padding(
          padding: EdgeInsets.all(horizontalPadding),
          child: GridView.builder(
            itemCount: _notes.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              childAspectRatio: childAspectRatio,
            ),
            itemBuilder: (context, index) {
              final note = _notes[index];
              return InkWell(
                onTap: () => _openEditor(note: note),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: EdgeInsets.all(tilePadding),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF141928), Color(0xFF101724)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white.withOpacity(0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _noteTitle(note),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: titleFontSize,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: isNarrow ? 8 : 10),
                      Text(
                        _notePreview(note),
                        maxLines: previewLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: previewFontSize,
                          height: 1.4,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(note.updatedAt),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

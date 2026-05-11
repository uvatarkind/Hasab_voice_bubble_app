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
    final result = await Navigator.of(context).push<Note?>(
      MaterialPageRoute(builder: (_) => NoteEditorPage(note: note)),
    );

    if (result == null) return;

    final index = _notes.indexWhere((n) => n.id == result.id);
    setState(() {
      if (index >= 0) {
        _notes[index] = result;
      } else {
        _notes.insert(0, result);
      }
      _notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    });

    await _saveNotes();
  }

  String _noteTitle(Note note) {
    final lines = note.content.trim().split('\n');
    final first = lines.isNotEmpty ? lines.first.trim() : '';
    return first.isEmpty ? 'Untitled' : first;
  }

  String _notePreview(Note note) {
    final clean = note.content.replaceAll('\n', ' ').trim();
    if (clean.length <= 90) return clean;
    return '${clean.substring(0, 90)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notes'),
        actions: [
          IconButton(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.edit_note),
            tooltip: 'New note',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? _buildEmptyState()
              : _buildNotesGrid(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.note_alt_outlined, size: 64, color: Colors.white70),
          const SizedBox(height: 12),
          const Text(
            'No notes yet, create one',
            style: TextStyle(fontSize: 16, color: Colors.white70),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => _openEditor(),
            icon: const Icon(Icons.edit),
            label: const Text('Write'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: _notes.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.95,
        ),
        itemBuilder: (context, index) {
          final note = _notes[index];
          return InkWell(
            onTap: () => _openEditor(note: note),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF15151F),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _noteTitle(note),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _notePreview(note),
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
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
  }

  String _formatDate(int millis) {
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final two = (int value) => value.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)}';
  }
}

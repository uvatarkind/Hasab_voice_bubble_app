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
        final crossAxisCount = width >= 900
            ? 3
            : width >= 620
                ? 2
                : 1;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            itemCount: _notes.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              childAspectRatio: crossAxisCount == 1 ? 1.8 : 0.95,
            ),
            itemBuilder: (context, index) {
              final note = _notes[index];
              return InkWell(
                onTap: () => _openEditor(note: note),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
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
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _notePreview(note),
                        maxLines: crossAxisCount == 1 ? 3 : 5,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12.5,
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

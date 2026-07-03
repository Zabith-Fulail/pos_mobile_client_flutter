import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../data/data_sources/local_data_sources.dart';


class ManageVideosScreen extends StatefulWidget {
  const ManageVideosScreen({super.key});

  @override
  State<ManageVideosScreen> createState() => _ManageVideosScreenState();
}

class _ManageVideosScreenState extends State<ManageVideosScreen> {
  List<String> _paths = [];
  bool _loading = true;
  final LocalDataSource _localDataSource = sl<LocalDataSource>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _localDataSource.getVideoPaths();
    if (mounted) setState(() { _paths = list; _loading = false; });
  }

  Future<void> _addVideos() async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final current = await _localDataSource.getVideoPaths();
    for (final f in result.files) {
      if (f.path != null && !current.contains(f.path)) {
        current.add(f.path!);
      }
    }
    await _localDataSource.saveVideoPaths(current);
    await _load();
  }

  Future<void> _delete(String path) async {
    final confirmed = await _confirmDelete(context, 'Remove this video?');
    if (!confirmed) return;
    final current = await _localDataSource.getVideoPaths();
    current.remove(path);
    await _localDataSource.saveVideoPaths(current);
    await _load();
  }

  Future<bool> _confirmDelete(BuildContext ctx, String message) async {
    return await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1C30),
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm',
            style: TextStyle(color: Colors.white, fontSize: 16)),
        content: Text(message,
            style: const TextStyle(color: Color(0xFFB0B0C8))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6A6D8A))),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove',
                style: TextStyle(color: Color(0xFFC8973A))),
          ),
        ],
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12141F),
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Videos',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: const Color(0xFF1E2035)),
        ),
        actions: [
          IconButton(
            onPressed: _addVideos,
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFFC8973A)),
            tooltip: 'Add Videos',
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFC8973A)),
      )
          : _paths.isEmpty
          ? _buildEmpty()
          : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVideos,
        backgroundColor: const Color(0xFFC8973A),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.video_library_outlined),
        label: const Text('Add Videos',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.video_library_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          const Text('No videos added yet',
              style: TextStyle(color: Color(0xFF4A4D6A), fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Tap the button below to pick videos from your device',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF2E3050), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _paths.length,
      proxyDecorator: (Widget child, int index, Animation<double> animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (BuildContext context, Widget? child) {
            final double scale = lerpDouble(1, 1.03, animation.value)!;

            return Transform.scale(
              scale: scale,
              child: Material(
                elevation: 6,
                shadowColor: Colors.black.withValues(alpha: 0.5),
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                child: child,
              ),
            );
          },
          child: child,
        );
      },
      onReorderStart: (index) {
        HapticFeedback.mediumImpact();
      },
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _paths.removeAt(oldIndex);
          _paths.insert(newIndex, item);
        });
        await _localDataSource.saveVideoPaths(_paths);
      },
      itemBuilder: (context, index) {
        final path = _paths[index];
        final name = path.split('/').last;

        return Container(
          key: ValueKey(path),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF141628),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E2035), width: 1),
          ),
          child: ListTile(
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            leading: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1C30),
                borderRadius: BorderRadius.circular(10),
                border:
                Border.all(color: const Color(0xFF2A2D48), width: 1),
              ),
              child: const Icon(
                Icons.play_circle_outline_rounded,
                color: Color(0xFFC8973A),
                size: 26,
              ),
            ),
            title: Text(
              name,
              style: const TextStyle(
                color: Color(0xFFD0D0E8),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: _FileSize(path: path),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Color(0xFF6A3A3A), size: 20),
                  onPressed: () => _delete(path),
                ),
                const Icon(Icons.drag_handle_rounded,
                    color: Color(0xFF2E3050), size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}


class _FileSize extends StatelessWidget {
  final String path;
  const _FileSize({required this.path});

  String _sizeStr() {
    try {
      final bytes = File(path).lengthSync();
      if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return 'Unknown size';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _sizeStr(),
      style: const TextStyle(color: Color(0xFF4A4D6A), fontSize: 11),
    );
  }
}
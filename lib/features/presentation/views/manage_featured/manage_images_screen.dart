import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/service/dependency_injection.dart';
import '../../../data/data_sources/local_data_sources.dart';


class ManageImagesScreen extends StatefulWidget {
  const ManageImagesScreen({super.key});

  @override
  State<ManageImagesScreen> createState() => _ManageImagesScreenState();
}

class _ManageImagesScreenState extends State<ManageImagesScreen> {
  List<String> _paths = [];
  bool _loading = true;
  bool _gridView = true;
  final LocalDataSource _localDataSource = sl<LocalDataSource>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await _localDataSource.getImagePaths();
    if (mounted) setState(() { _paths = list; _loading = false; });
  }

  Future<void> _addImages() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'heic', 'heif'],
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;

    final current = await _localDataSource.getImagePaths();
    for (final f in result.files) {
      if (f.path != null && !current.contains(f.path)) {
        current.add(f.path!);
      }
    }
    await _localDataSource.saveImagePaths(current);
    await _load();
  }

  Future<void> _delete(String path) async {
    final confirmed = await _confirmDelete(context, 'Remove this image?');
    if (!confirmed) return;
    final current = await _localDataSource.getImagePaths();
    current.remove(path);
    await _localDataSource.saveImagePaths(current);
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

  void _showFullImage(BuildContext ctx, int index) {
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => _FullImageView(
          paths: _paths,
          initialIndex: index,
          onDelete: (path) async {
            Navigator.pop(ctx);
            final current = await _localDataSource.getImagePaths();
            current.remove(path);
            await _localDataSource.saveImagePaths(current);
            await _load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F1C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF12141F),
        foregroundColor: Colors.white,
        title: const Text(
          'Manage Images',
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
            onPressed: () => setState(() => _gridView = !_gridView),
            icon: Icon(
              _gridView ? Icons.view_list_outlined : Icons.grid_view_outlined,
              color: const Color(0xFFC8973A),
            ),
          ),
          IconButton(
            onPressed: _addImages,
            icon:
            const Icon(Icons.add_circle_outline, color: Color(0xFFC8973A)),
            tooltip: 'Add Images',
          ),
        ],
      ),
      body: _loading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFFC8973A)),
      )
          : _paths.isEmpty
          ? _buildEmpty()
          : _gridView
          ? _buildGrid()
          : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addImages,
        backgroundColor: const Color(0xFFC8973A),
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_photo_alternate_outlined),
        label: const Text('Add Images',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 64, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          const Text('No images added yet',
              style: TextStyle(color: Color(0xFF4A4D6A), fontSize: 15)),
          const SizedBox(height: 8),
          const Text('Tap the button below to pick images from your device',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF2E3050), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: _paths.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _showFullImage(context, index),
          onLongPress: () => _delete(_paths[index]),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  File(_paths[index]),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1A1C30),
                    child: const Icon(Icons.broken_image_outlined,
                        color: Color(0xFF4A4D6A)),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _delete(_paths[index]),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        color: Colors.white70, size: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _paths.length,
      onReorder: (oldIndex, newIndex) async {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _paths.removeAt(oldIndex);
          _paths.insert(newIndex, item);
        });
        await _localDataSource.saveImagePaths(_paths);
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
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 48,
                height: 48,
                child: Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF1A1C30),
                    child: const Icon(Icons.broken_image_outlined,
                        color: Color(0xFF4A4D6A)),
                  ),
                ),
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
            onTap: () => _showFullImage(context, index),
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


class _FullImageView extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  final void Function(String path) onDelete;

  const _FullImageView({
    required this.paths,
    required this.initialIndex,
    required this.onDelete,
  });

  @override
  State<_FullImageView> createState() => _FullImageViewState();
}

class _FullImageViewState extends State<_FullImageView> {
  late PageController _ctrl;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _ctrl = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_index + 1} / ${widget.paths.length}',
          style: const TextStyle(fontSize: 14, color: Colors.white54),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Color(0xFFC8973A)),
            onPressed: () => widget.onDelete(widget.paths[_index]),
          ),
        ],
      ),
      body: PageView.builder(
        controller: _ctrl,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, index) {
          return InteractiveViewer(
            child: Center(
              child: Image.file(
                File(widget.paths[index]),
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.broken_image_outlined,
                  color: Color(0xFF4A4D6A),
                  size: 64,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
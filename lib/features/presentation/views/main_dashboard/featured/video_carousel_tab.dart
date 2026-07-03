import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../../../core/service/dependency_injection.dart';
import '../../../../data/data_sources/local_data_sources.dart';


class VideoCarouselTab extends StatefulWidget {
  const VideoCarouselTab({super.key});

  @override
  State<VideoCarouselTab> createState() => _VideoCarouselTabState();
}

class _VideoCarouselTabState extends State<VideoCarouselTab> {
  List<String> _videoPaths = [];
  List<String> _imagePaths = [];
  final _localDataSource = sl<LocalDataSource>();
  late PageController _videoPageController;
  late PageController _imagePageController;

  int _currentVideoIndex = 0;
  int _currentImageIndex = 0;
  bool _isAutoAdvancing = false;
  static const int _kVirtualPageOffset = 10000;

  @override
  void initState() {
    super.initState();
    _videoPageController = PageController(
      initialPage: _kVirtualPageOffset,
    );
    _imagePageController = PageController(viewportFraction: 0.88);
    _loadMedia();
  }

  Future<void> _loadMedia() async {
    final videos = await _localDataSource.getVideoPaths();
    final images = await _localDataSource.getImagePaths();
    if (mounted) {
      setState(() {
        _videoPaths = videos;
        _imagePaths = images;
        if (_currentVideoIndex >= _videoPaths.length) _currentVideoIndex = 0;
        if (_currentImageIndex >= _imagePaths.length) _currentImageIndex = 0;
      });
    }
  }

  Future<void> reload() => _loadMedia();

  void _onVideoFinished() {
    if (_isAutoAdvancing || !mounted || _videoPaths.isEmpty) return;
    _isAutoAdvancing = true;
    
    final currentPage = _videoPageController.page?.toInt() ?? _kVirtualPageOffset;
    final nextPage = currentPage + 1;
    
    _videoPageController
        .animateToPage(nextPage,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut)
        .then((_) => _isAutoAdvancing = false);
  }

  @override
  void dispose() {
    _videoPageController.dispose();
    _imagePageController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0E0F1C),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: _videoPaths.isEmpty
                ? _buildEmptyVideo()
                : _buildVideoPageView(),
          ),

          if (_videoPaths.length > 1) _buildVideoDots(),

          _buildGalleryLabel(),

          Expanded(
            child: _imagePaths.isEmpty
                ? _buildEmptyImages()
                : _buildImagePageView(),
          ),

          if (_imagePaths.length > 1) _buildImageDots(),

          const SizedBox(height: 10),
        ],
      ),
    );
  }


  Widget _buildVideoPageView() {
    if (_videoPaths.isEmpty) return const SizedBox();
    
    return PageView.builder(
      controller: _videoPageController,
      itemCount: 100000,
      onPageChanged: (i) => setState(() => _currentVideoIndex = i % _videoPaths.length),
      itemBuilder: (context, virtualIndex) {
        final actualIndex = virtualIndex % _videoPaths.length;
        
        return Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: _VideoPlayerCard(
              key: ValueKey('${_videoPaths[actualIndex]}_$virtualIndex'),
              file: File(_videoPaths[actualIndex]),
              isActive: actualIndex == _currentVideoIndex,
              onFinished: _onVideoFinished,
            ),
          ),
        );
      },
    );
  }


  Widget _buildImagePageView() {
    return PageView.builder(
      controller: _imagePageController,
      itemCount: _imagePaths.length,
      onPageChanged: (i) => setState(() => _currentImageIndex = i),
      itemBuilder: (context, index) {
        final isActive = index == _currentImageIndex;
        return AnimatedScale(
          scale: isActive ? 1.0 : 0.93,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: GestureDetector(
              onTap: () => _showImagePopup(context, index),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(_imagePaths[index]),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFF141628),
                    child: const Icon(Icons.broken_image_outlined,
                        color: Color(0xFF4A4D6A), size: 40),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }


  void _showImagePopup(BuildContext context, int index) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'dismiss',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => const SizedBox.shrink(),
      transitionBuilder: (ctx, animation, _, __) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: _ImagePopup(
            paths: _imagePaths,
            initialIndex: index,
            scaleAnimation: curved,
          ),
        );
      },
    );
  }


  Widget _buildVideoDots() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_videoPaths.length, (i) {
          final active = i == _currentVideoIndex;
          return GestureDetector(
            onTap: () {
              final currentPage = _videoPageController.page?.toInt() ?? _kVirtualPageOffset;
              final currentModulo = currentPage % _videoPaths.length;
              
              int targetPage = currentPage + (i - currentModulo);
              if (targetPage < 0) targetPage += _videoPaths.length;
              
              _videoPageController.animateToPage(targetPage,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                gradient: active
                    ? const LinearGradient(
                    colors: [Color(0xFFC8973A), Color(0xFFE8C870)])
                    : null,
                color: active ? null : const Color(0xFF2A2D48),
              ),
            ),
          );
        }),
      ),
    );
  }


  Widget _buildImageDots() {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(_imagePaths.length, (i) {
          final active = i == _currentImageIndex;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: active ? 14 : 5,
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: active
                  ? const Color(0xFFC8973A)
                  : const Color(0xFF2A2D48),
            ),
          );
        }),
      ),
    );
  }


  Widget _buildGalleryLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 2),
      child: Row(
        children: [
          const Text(
            'GALLERY',
            style: TextStyle(
              color: Color(0xFF5A5D7A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Container(height: 1, color: const Color(0xFF1A1C30))),
          const SizedBox(width: 10),
          Text(
            '${_imagePaths.length}',
            style: const TextStyle(
              color: Color(0xFF3A3D58),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildEmptyVideo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141628),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFF1E2035)),
        ),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.video_library_outlined,
                  size: 52, color: Color(0xFF2A2D48)),
              SizedBox(height: 12),
              Text('No videos added',
                  style:
                  TextStyle(color: Color(0xFF4A4D6A), fontSize: 14)),
              SizedBox(height: 4),
              Text('Add videos from the menu',
                  style:
                  TextStyle(color: Color(0xFF2E3050), fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyImages() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.photo_library_outlined,
              size: 36, color: Color(0xFF2A2D48)),
          SizedBox(height: 8),
          Text('No images added',
              style: TextStyle(color: Color(0xFF4A4D6A), fontSize: 12)),
        ],
      ),
    );
  }
}


class _ImagePopup extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  final Animation<double> scaleAnimation;

  const _ImagePopup({
    required this.paths,
    required this.initialIndex,
    required this.scaleAnimation,
  });

  @override
  State<_ImagePopup> createState() => _ImagePopupState();
}

class _ImagePopupState extends State<_ImagePopup> {
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
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: [
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              color: Colors.black.withValues(alpha: 0.55),
            ),
          ),

          ScaleTransition(
            scale: Tween<double>(begin: 0.88, end: 1.0).animate(
              CurvedAnimation(
                parent: widget.scaleAnimation,
                curve: Curves.easeOutBack,
              ),
            ),
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: GestureDetector(
                      onTap: () {},
                      child: PageView.builder(
                        controller: _ctrl,
                        itemCount: widget.paths.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: InteractiveViewer(
                              minScale: 0.8,
                              maxScale: 4.0,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
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
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (widget.paths.length > 1)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(widget.paths.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: active ? 16 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: active
                                ? const Color(0xFFC8973A)
                                : Colors.white24,
                          ),
                        );
                      }),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _VideoPlayerCard extends StatefulWidget {
  final File file;
  final bool isActive;
  final VoidCallback onFinished;

  const _VideoPlayerCard({
    super.key,
    required this.file,
    required this.isActive,
    required this.onFinished,
  });

  @override
  State<_VideoPlayerCard> createState() => _VideoPlayerCardState();
}

class _VideoPlayerCardState extends State<_VideoPlayerCard> {
  VideoPlayerController? _controller;
  bool _initialized = false;
  bool _showControls = false;
  bool _finishedFired = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    try {
      final ctrl = VideoPlayerController.file(widget.file);
      _controller = ctrl;
      await ctrl.initialize();
      ctrl.setLooping(false);
      ctrl.addListener(_onVideoEvent);
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() => _initialized = true);
      if (widget.isActive) ctrl.play();
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  void _onVideoEvent() {
    if (!mounted || _controller == null) return;
    final pos = _controller!.value.position;
    final dur = _controller!.value.duration;
    if (!_finishedFired &&
        dur.inMilliseconds > 0 &&
        pos.inMilliseconds >= dur.inMilliseconds - 200) {
      _finishedFired = true;
      widget.onFinished();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(_VideoPlayerCard old) {
    super.didUpdateWidget(old);
    if (_controller == null || !_initialized) return;
    if (widget.isActive && !old.isActive) {
      _finishedFired = false;
      _controller!.seekTo(Duration.zero);
      _controller!.play();
    } else if (!widget.isActive && old.isActive) {
      _controller!.pause();
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoEvent);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (_controller == null || !_initialized) return;
    _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
    setState(() => _showControls = !_showControls);
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: _hasError
          ? const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                color: Color(0xFFC8973A), size: 40),
            SizedBox(height: 8),
            Text('Unable to load video',
                style:
                TextStyle(color: Colors.white54, fontSize: 13)),
          ],
        ),
      )
          : !_initialized
          ? const Center(
        child: CircularProgressIndicator(
            color: Color(0xFFC8973A), strokeWidth: 2),
      )
          : GestureDetector(
        onTap: _togglePlay,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FittedBox(
              fit: BoxFit.cover,
              clipBehavior: Clip.hardEdge,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),

            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                    stops: const [0.0, 0.48, 1.0],
                  ),
                ),
              ),
            ),

            Center(
              child: AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                        Colors.white.withValues(alpha: 0.4),
                        width: 1.5),
                  ),
                  child: Icon(
                    _controller!.value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildProgressBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ValueListenableBuilder<VideoPlayerValue>(
        valueListenable: _controller!,
        builder: (_, value, __) {
          final total = value.duration.inMilliseconds.toDouble();
          final current = value.position.inMilliseconds.toDouble();
          final progress =
          total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(value.position),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                  Text(_fmt(value.duration),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) {
                  final box =
                  context.findRenderObject() as RenderBox?;
                  if (box == null) return;
                  final x =
                  d.localPosition.dx.clamp(0.0, box.size.width);
                  _controller!
                      .seekTo(value.duration * (x / box.size.width));
                },
                child: SizedBox(
                  height: 20,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFFC8973A),
                                  Color(0xFFFFE4A0),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment:
                        Alignment((progress * 2.0) - 1.0, 0.0),
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: const BoxDecoration(
                            color: Color(0xFFE8C870),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
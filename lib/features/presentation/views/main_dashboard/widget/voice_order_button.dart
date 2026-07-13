import 'package:flutter/material.dart';

import '../../../../../core/service/voice_command_service.dart';
import '../../../../../utils/app_theme.dart';

class VoiceCaptureButton extends StatefulWidget {
  final void Function(String finalText) onResult;
  final bool mini;

  const VoiceCaptureButton({
    super.key,
    required this.onResult,
    this.mini = false,
  });

  @override
  State<VoiceCaptureButton> createState() => _VoiceCaptureButtonState();
}

class _VoiceCaptureButtonState extends State<VoiceCaptureButton> {
  final _voiceService = VoiceCommandService();
  final _liveText = ValueNotifier<String>('');
  OverlayEntry? _overlayEntry;
  bool _listening = false;
  Future<void> _stop() async {
    await _voiceService.stop();
    _finish(_liveText.value);
  }
  void _insertOverlay() {
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: ValueListenableBuilder<String>(
              valueListenable: _liveText,
              builder: (context, text, _) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.bgCardElevated,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(color: Colors.black38, blurRadius: 10, offset: Offset(0, 3)),
                  ],
                ),
                child: Text(
                  text.isEmpty ? 'Listening...' : text,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _start() async {
    if (_listening) return;
    setState(() => _listening = true);
    _liveText.value = '';
    _insertOverlay();
    await _voiceService.listen(
      onResult: (text, isFinal) {
        _liveText.value = text;
        if (isFinal) _finish(text);
      },
    );
  }


  void _finish(String text) {
    if (!mounted) return;
    setState(() => _listening = false);
    _removeOverlay();
    if (text.isNotEmpty) widget.onResult(text);
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(_listening ? Icons.stop : Icons.mic, color: AppTheme.textOnGold);
    final color = _listening ? AppTheme.red : AppTheme.gold;
    final onTap = _listening ? _stop : _start;

    return widget.mini
        ? FloatingActionButton.small(
      heroTag: UniqueKey(),
      backgroundColor: color,
      onPressed: onTap,
      child: icon,
    )
        : FloatingActionButton(
      heroTag: UniqueKey(),
      backgroundColor: color,
      onPressed: onTap,
      child: icon,
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _voiceService.cancel();
    _liveText.dispose();
    super.dispose();
  }
}
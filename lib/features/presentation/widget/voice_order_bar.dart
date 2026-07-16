import 'package:flutter/material.dart';

import '../../../core/service/voice_command_service.dart';
import '../../../utils/app_theme.dart';

class VoiceOrderBar extends StatefulWidget {
  final Future<void> Function(String confirmedText) onConfirm;
  const VoiceOrderBar({super.key, required this.onConfirm});

  @override
  State<VoiceOrderBar> createState() => _VoiceOrderBarState();
}

class _VoiceOrderBarState extends State<VoiceOrderBar> {
  final _voiceService = VoiceCommandService();
  final _controller = TextEditingController();
  bool _recording = false;
  bool _submitting = false;

  Future<void> _startRecording() async {
    setState(() {
      _recording = true;
      _controller.clear();
    });
    await _voiceService.listen(
      onResult: (text, isFinal) {
        _controller.text = text;
        _controller.selection =
            TextSelection.collapsed(offset: _controller.text.length);
      },
    );
  }

  Future<void> _stopRecording() async {
    await _voiceService.stop();
    if (mounted) setState(() => _recording = false);
  }

  Future<void> _confirm() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await widget.onConfirm(text);
      _controller.clear();
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _voiceService.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        decoration: const BoxDecoration(
          color: AppTheme.bgSurface,
          border: Border(top: BorderSide(color: AppTheme.bgBorder)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _controller,
                enabled: !_recording,
                maxLines: 3,
                minLines: 1,
                style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  hintText: _recording
                      ? 'Listening...'
                      : 'Hold the mic to speak, then edit and confirm',
                  filled: true,
                  fillColor: AppTheme.bgCard,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTapDown: (_) => _startRecording(),
                      onTapUp: (_) => _stopRecording(),
                      onTapCancel: () => _stopRecording(),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _recording ? AppTheme.red : AppTheme.gold,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          _recording ? Icons.mic : Icons.mic_none_rounded,
                          color: AppTheme.textOnGold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: _submitting ? null : _confirm,
                    icon: _submitting
                        ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle, color: AppTheme.green, size: 32),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
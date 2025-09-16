import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String mediaUrl;
  final bool isMe;

  const VoiceMessagePlayer({
    super.key,
    required this.mediaUrl,
    required this.isMe,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateChangeSubscription;

  @override
  void initState() {
    super.initState();
    _audioPlayer.setSourceUrl(widget.mediaUrl);
    _playerStateChangeSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _durationSubscription = _audioPlayer.onDurationChanged.listen((
      newDuration,
    ) {
      if (mounted) setState(() => _duration = newDuration);
    });
    _positionSubscription = _audioPlayer.onPositionChanged.listen((
      newPosition,
    ) {
      if (mounted) setState(() => _position = newPosition);
    });
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) setState(() => _position = Duration.zero);
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateChangeSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.white : const Color(0xFF6D5BFF);
    final inactiveColor = widget.isMe ? Colors.white.withOpacity(0.7) : Colors.grey.shade400;

    return Stack(
      children: [
        Container(
          padding: const EdgeInsets.only(right: 32), // Space for download icon
          constraints: const BoxConstraints(maxWidth: 200), // Limit width
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      if (_isPlaying) {
                        await _audioPlayer.pause();
                      } else {
                        if (_position >= _duration && _duration > Duration.zero) {
                          await _audioPlayer.seek(Duration.zero);
                        }
                        await _audioPlayer.play(UrlSource(widget.mediaUrl));
                      }
                    },
                    icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled, color: color, size: 32),
                  ),
                  const SizedBox(width: 8),
                  if (_duration > Duration.zero)
                    Flexible(
                      child: Slider(
                        value: _position.inSeconds.toDouble(),
                        max: _duration.inSeconds.toDouble(),
                        onChanged: (value) async {
                          final position = Duration(seconds: value.toInt());
                          await _audioPlayer.seek(position);
                        },
                        activeColor: color,
                        inactiveColor: inactiveColor,
                      ),
                    ),
                ],
              ),
              if (_duration > Duration.zero)
                Text(
                  '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                  style: TextStyle(fontSize: 12, color: color.withOpacity(0.9)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
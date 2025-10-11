import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

class VoiceMessagePlayerWidget extends StatefulWidget {
  final String url;
  const VoiceMessagePlayerWidget({required this.url, super.key});

  @override
  State<VoiceMessagePlayerWidget> createState() =>
      _VoiceMessagePlayerWidgetState();
}

class _VoiceMessagePlayerWidgetState extends State<VoiceMessagePlayerWidget> {
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription? _playerSubscription;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    await _audioPlayer.openPlayer();
    _playerSubscription = _audioPlayer.onProgress!.listen((e) {
      setState(() {
        _position = e.position;
        _duration = e.duration;
      });
    });
  }

  @override
  void dispose() {
    _playerSubscription?.cancel();
    _audioPlayer.closePlayer();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_audioPlayer.isStopped) {
      await _audioPlayer.startPlayer(
        fromURI: widget.url,
        whenFinished: () => setState(() => _isPlaying = false),
      );
    } else if (_audioPlayer.isPlaying) {
      await _audioPlayer.pausePlayer();
    } else {
      await _audioPlayer.resumePlayer();
    }
    setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: _togglePlay,
        ),
        Expanded(
          child: Slider(
            value: _position.inMilliseconds.toDouble(),
            max: _duration.inMilliseconds.toDouble() > 0
                ? _duration.inMilliseconds.toDouble()
                : 1,
            onChanged: (value) async {
              final pos = Duration(milliseconds: value.toInt());
              await _audioPlayer.seekToPlayer(pos);
            },
          ),
        ),
        Text(_formatDuration(_position)),
      ],
    );
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

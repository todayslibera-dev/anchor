import 'package:flutter/material.dart';

import '../data.dart';
import '../playback.dart';
import '../utils.dart';
import 'timeline_track.dart';

class TimelineDemoControls extends StatelessWidget {
  const TimelineDemoControls({
    super.key,
    required this.duration,
    required this.position,
    required this.status,
    required this.checks,
    required this.onSeek,
    required this.onMarkerTap,
    required this.onTogglePlayPause,
    required this.onSeekBackward,
    required this.onSeekForward,
  });

  final Duration duration;
  final Duration position;
  final PlaybackStatus status;
  final List<DemoCheck> checks;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<DemoCheck> onMarkerTap;
  final Future<void> Function() onTogglePlayPause;
  final Future<void> Function() onSeekBackward;
  final Future<void> Function() onSeekForward;

  bool get _isPlaying => status == PlaybackStatus.playing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = duration.inMilliseconds == 0
        ? 0.0
        : position.inMilliseconds / duration.inMilliseconds;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TimelineTrack(
              duration: duration,
              position: position,
              progress: progress.clamp(0.0, 1.0),
              checks: checks,
              onSeek: onSeek,
              onMarkerTap: onMarkerTap,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(formatTimestamp(position),
                    style: theme.textTheme.labelSmall),
                const Spacer(),
                Text(formatTimestamp(duration),
                    style: theme.textTheme.labelSmall),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildButton(
                  icon: Icons.rotate_left,
                  label: '-2초',
                  callback: onSeekBackward,
                ),
                _buildButton(
                  icon: _isPlaying
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_filled,
                  label: _isPlaying ? '일시정지' : '재생',
                  callback: onTogglePlayPause,
                ),
                _buildButton(
                  icon: Icons.rotate_right,
                  label: '+2초',
                  callback: onSeekForward,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildButton({
    required IconData icon,
    required String label,
    required Future<void> Function() callback,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          iconSize: 36,
          onPressed: () => callback(),
          icon: Icon(icon),
        ),
        Text(label),
      ],
    );
  }
}

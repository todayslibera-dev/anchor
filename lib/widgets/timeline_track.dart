import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data.dart';
import '../utils.dart';

class TimelineTrack extends StatelessWidget {
  const TimelineTrack({
    super.key,
    required this.duration,
    required this.position,
    required this.progress,
    required this.checks,
    required this.onSeek,
    required this.onMarkerTap,
  });

  final Duration duration;
  final Duration position;
  final double progress;
  final List<DemoCheck> checks;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<DemoCheck> onMarkerTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durationMs =
        math.max(duration.inMilliseconds, 1); // avoid division by zero

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const trackHeight = 10.0;
        const handleSize = 18.0;
        const markerSize = 14.0;
        const trackTop = markerSize / 2;

        Duration dxToDuration(double dx) {
          final clampedDx = dx.clamp(0, width);
          final ratio = width == 0 ? 0.0 : clampedDx / width;
          final targetMs = (durationMs * ratio).round();
          return Duration(milliseconds: targetMs);
        }

        final handleLeft = (width - handleSize) * progress;

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapDown: (details) => onSeek(dxToDuration(details.localPosition.dx)),
          onHorizontalDragUpdate: (details) =>
              onSeek(dxToDuration(details.localPosition.dx)),
          child: SizedBox(
            height: markerSize + handleSize,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 0,
                  top: trackTop,
                  child: Container(
                    width: width,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  top: trackTop,
                  child: Container(
                    width: width * progress,
                    height: trackHeight,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(trackHeight / 2),
                    ),
                  ),
                ),
                for (final check in checks)
                  Positioned(
                    left: (width - markerSize) *
                        (check.start.inMilliseconds / durationMs).clamp(0.0, 1.0),
                    top: trackTop - markerSize,
                    child: Tooltip(
                      message:
                          '${check.categoryLabel} · ${formatTimestamp(check.start)}',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(markerSize / 2),
                        onTap: () => onMarkerTap(check),
                        child: Container(
                          width: markerSize,
                          height: markerSize,
                          decoration: BoxDecoration(
                            color: check.color,
                            borderRadius: BorderRadius.circular(markerSize / 2),
                            border: Border.all(
                              color: theme.colorScheme.onPrimary
                                  .withValues(alpha: 0.5),
                              width: 1.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: handleLeft,
                  top: trackTop - (handleSize - trackHeight) / 2,
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.onPrimary
                                  .withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

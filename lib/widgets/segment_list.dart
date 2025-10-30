import 'package:flutter/material.dart';

import '../data.dart';
import 'segment_tile.dart';

class SegmentList extends StatelessWidget {
  const SegmentList({
    super.key,
    required this.segments,
    required this.currentPosition,
    required this.onTapSegment,
    required this.segmentKeys,
  });

  final List<DemoSegment> segments;
  final Duration currentPosition;
  final ValueChanged<DemoSegment> onTapSegment;
  final Map<String, GlobalKey> segmentKeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          SegmentTile(
            key: segmentKeys[segments[i].id],
            segment: segments[i],
            currentPosition: currentPosition,
            onTapSegment: () => onTapSegment(segments[i]),
            theme: theme,
          ),
          if (i < segments.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

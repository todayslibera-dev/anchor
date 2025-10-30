import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

enum PlaybackStatus { ready, playing, paused, completed }

void main() {
  runApp(const AnchorDemoApp());
}

class AnchorDemoApp extends StatelessWidget {
  const AnchorDemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Anchor Scroll Demo',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const AnchorDemoPage(),
    );
  }
}

class AnchorDemoPage extends StatefulWidget {
  const AnchorDemoPage({super.key});

  @override
  State<AnchorDemoPage> createState() => _AnchorDemoPageState();
}

class _AnchorDemoPageState extends State<AnchorDemoPage> {
  static const Duration _scrollAnchorOffset = Duration(seconds: 10);
  static const Duration _pauseScrollThreshold = Duration(seconds: 1);

  late final PlaybackSimulator _player;
  late final SegmentScrollCoordinator _scrollCoordinator;
  final ScrollController _scrollController = ScrollController();

  late final List<DemoSegment> _segments;
  late final List<DemoCheck> _checks;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlaybackStatus>? _statusSub;

  Duration _currentPosition = Duration.zero;
  PlaybackStatus _status = PlaybackStatus.ready;

  @override
  void initState() {
    super.initState();
    final data = buildDemoData();
    _segments = data.segments;
    _checks = data.checks;

    _player = PlaybackSimulator(duration: data.duration);
    _scrollCoordinator = SegmentScrollCoordinator(
      scrollController: _scrollController,
      isMounted: () => mounted,
    )..updateSegments(_segments);

    _scrollCoordinator.registerScrollHandler((callback) {
      _scrollToTimestamp = callback;
    });

    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _currentPosition = position);
    });
    _statusSub = _player.statusStream.listen((status) {
      if (!mounted) return;
      setState(() => _status = status);
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _statusSub?.cancel();
    _player.dispose();
    _scrollCoordinator.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> Function(Duration timestamp)? _scrollToTimestamp;

  Future<void> _handleSeek(Duration target, {bool forcePlay = false}) async {
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > _player.duration) clamped = _player.duration;

    await _player.seek(clamped);
    if (forcePlay || _status == PlaybackStatus.playing) {
      await _player.play();
    }

    setState(() => _currentPosition = clamped);
    await _scrollToAnchor(clamped);
  }

  Future<void> _handlePauseOrPlay() async {
    if (_status == PlaybackStatus.playing) {
      await _player.pause();
      final actual = _player.currentPosition;
      if (!mounted) return;
      final difference = _difference(actual, _currentPosition);
      setState(() => _currentPosition = actual);
      if (difference >= _pauseScrollThreshold) {
        await _scrollToAnchor(actual);
      }
    } else {
      if (_status == PlaybackStatus.completed) {
        await _player.seek(Duration.zero);
        setState(() => _currentPosition = Duration.zero);
      }
      await _player.play();
    }
  }

  Future<void> _scrollToAnchor(Duration center) async {
    final anchor = _anchorTimestamp(center);
    final scroller = _scrollToTimestamp;
    if (scroller != null) {
      await scroller(anchor);
    }
  }

  Duration _anchorTimestamp(Duration center) {
    final anchor = center - _scrollAnchorOffset;
    if (anchor < Duration.zero) return Duration.zero;
    return anchor;
  }

  Duration _difference(Duration a, Duration b) {
    final diff = a - b;
    return diff.isNegative ? -diff : diff;
  }

  Map<String, List<HighlightRange>> _buildHighlights() {
    final map = <String, List<HighlightRange>>{};
    for (final check in _checks) {
      final segment = _findSegmentFor(check.start);
      final segStart = segment.timestamp;
      final segEnd = segment.endTimestamp;
      var start = _anchorTimestamp(check.start);
      var end = check.start;
      if (start < segStart) start = segStart;
      if (end > segEnd) end = segEnd;
      if (end <= start) {
        end = start + const Duration(milliseconds: 300);
        if (end > segEnd) end = segEnd;
      }
      final range = HighlightRange(
        start: start,
        end: end,
        color: check.color.withValues(alpha: 0.3),
      );
      map.putIfAbsent(segment.id, () => []).add(range);
    }
    return map;
  }

  DemoSegment _findSegmentFor(Duration timestamp) {
    DemoSegment? candidate;
    for (final segment in _segments) {
      final start = segment.timestamp;
      final end = segment.endTimestamp;
      if (timestamp >= start && timestamp <= end) {
        return segment;
      }
      if (timestamp > end) {
        candidate = segment;
      }
    }
    return candidate ?? _segments.last;
  }

  @override
  Widget build(BuildContext context) {
    final highlightMap = _buildHighlights();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Timeline ↔ Text Anchor Demo'),
      ),
      body: Column(
        children: [
          Expanded(
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      '마커·슬라이더·텍스트를 조작해 n-10초 기준의 스크롤 앵커가 어떻게 동작하는지 확인해 보세요.',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverToBoxAdapter(
                    child: _SegmentList(
                      segments: _segments,
                      currentPosition: _currentPosition,
                      highlights: highlightMap,
                      onTapSegment: (segment) =>
                          _handleSeek(segment.timestamp, forcePlay: true),
                      onTapWord: (timestamp) =>
                          _handleSeek(timestamp, forcePlay: true),
                      segmentKeys: _scrollCoordinator.segmentKeys,
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 80)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: TimelineDemoControls(
                duration: _player.duration,
                position: _currentPosition,
                status: _status,
                checks: _checks,
                onSeek: (position) => _handleSeek(position),
                onMarkerTap: (check) => _handleSeek(check.start),
                onTogglePlayPause: _handlePauseOrPlay,
                onSeekBackward: () => _handleSeek(
                  _currentPosition - const Duration(seconds: 2),
                ),
                onSeekForward: () => _handleSeek(
                  _currentPosition + const Duration(seconds: 2),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentList extends StatelessWidget {
  const _SegmentList({
    required this.segments,
    required this.currentPosition,
    required this.highlights,
    required this.onTapSegment,
    required this.onTapWord,
    required this.segmentKeys,
  });

  final List<DemoSegment> segments;
  final Duration currentPosition;
  final Map<String, List<HighlightRange>> highlights;
  final ValueChanged<DemoSegment> onTapSegment;
  final ValueChanged<Duration> onTapWord;
  final Map<String, GlobalKey> segmentKeys;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < segments.length; i++) ...[
          _SegmentTile(
            key: segmentKeys[segments[i].id],
            segment: segments[i],
            currentPosition: currentPosition,
            highlights: highlights[segments[i].id] ?? const [],
            onTapSegment: () => onTapSegment(segments[i]),
            onTapWord: onTapWord,
            theme: theme,
          ),
          if (i < segments.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SegmentTile extends StatelessWidget {
  const _SegmentTile({
    super.key,
    required this.segment,
    required this.currentPosition,
    required this.highlights,
    required this.onTapSegment,
    required this.onTapWord,
    required this.theme,
  });

  final DemoSegment segment;
  final Duration currentPosition;
  final List<HighlightRange> highlights;
  final VoidCallback onTapSegment;
  final ValueChanged<Duration> onTapWord;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isActive = currentPosition >= segment.timestamp &&
        currentPosition <= segment.endTimestamp;
    final backgroundColor = isActive
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : theme.colorScheme.surface;
    final borderColor = theme.colorScheme.outlineVariant;

    return InkWell(
      onTap: onTapSegment,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Chip(
                  avatar: const Icon(Icons.person_outline, size: 16),
                  label: Text(segment.speakerLabel),
                ),
                const SizedBox(width: 12),
                Text(
                  formatTimestamp(segment.timestamp),
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            HighlightedText(
              text: segment.text,
              alignments: segment.alignments,
              highlights: highlights,
              onWordTap: onTapWord,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

class HighlightedText extends StatelessWidget {
  const HighlightedText({
    super.key,
    required this.text,
    required this.alignments,
    required this.highlights,
    required this.onWordTap,
    required this.theme,
  });

  final String text;
  final List<DemoWordAlignment> alignments;
  final List<HighlightRange> highlights;
  final ValueChanged<Duration> onWordTap;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    if (alignments.isEmpty) {
      return Text(text, style: theme.textTheme.bodyMedium);
    }

    final spans = <InlineSpan>[];
    for (final alignment in alignments) {
      final highlightColor =
          _resolveHighlightColor(alignment.start, alignment.end);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => onWordTap(alignment.start),
            child: Container(
              decoration: BoxDecoration(
                color: highlightColor,
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
              child: Text(
                alignment.word,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ),
      );
      spans.add(TextSpan(text: ' ', style: theme.textTheme.bodyMedium));
    }

    return RichText(text: TextSpan(children: spans));
  }

  Color? _resolveHighlightColor(Duration start, Duration end) {
    for (final range in highlights) {
      if (start < range.end && end > range.start) {
        return range.color;
      }
    }
    return null;
  }
}

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
            _TimelineTrack(
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

class _TimelineTrack extends StatelessWidget {
  const _TimelineTrack({
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
          onTapDown: (details) =>
              onSeek(dxToDuration(details.localPosition.dx)),
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
                        (check.start.inMilliseconds / durationMs)
                            .clamp(0.0, 1.0),
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
                        color:
                            theme.colorScheme.onPrimary.withValues(alpha: 0.6),
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

class PlaybackSimulator {
  PlaybackSimulator({
    required this.duration,
    Duration tickInterval = const Duration(milliseconds: 200),
  })  : _tickInterval = tickInterval,
        _positionController = StreamController.broadcast(),
        _statusController = StreamController.broadcast() {
    _statusController.add(PlaybackStatus.ready);
  }

  final Duration duration;
  final Duration _tickInterval;
  final StreamController<Duration> _positionController;
  final StreamController<PlaybackStatus> _statusController;
  Duration _position = Duration.zero;
  Timer? _timer;

  Stream<Duration> get positionStream => _positionController.stream;
  Stream<PlaybackStatus> get statusStream => _statusController.stream;

  bool get isPlaying => _timer != null;
  Duration get currentPosition => _position;

  Future<void> play() async {
    if (isPlaying) return;
    _statusController.add(PlaybackStatus.playing);
    _timer = Timer.periodic(_tickInterval, (_) {
      _position += _tickInterval;
      if (_position >= duration) {
        _position = duration;
        _positionController.add(_position);
        _statusController.add(PlaybackStatus.completed);
        _timer?.cancel();
        _timer = null;
      } else {
        _positionController.add(_position);
      }
    });
  }

  Future<void> pause() async {
    if (!isPlaying) {
      _statusController.add(PlaybackStatus.paused);
      return;
    }
    _timer?.cancel();
    _timer = null;
    _statusController.add(PlaybackStatus.paused);
  }

  Future<void> seek(Duration target) async {
    var clamped = target;
    if (clamped < Duration.zero) clamped = Duration.zero;
    if (clamped > duration) clamped = duration;
    _position = clamped;
    _positionController.add(_position);
    if (!isPlaying) {
      _statusController.add(PlaybackStatus.ready);
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _positionController.close();
    _statusController.close();
  }
}

class HighlightRange {
  const HighlightRange({
    required this.start,
    required this.end,
    required this.color,
  });

  final Duration start;
  final Duration end;
  final Color color;
}

class DemoWordAlignment {
  const DemoWordAlignment({
    required this.word,
    required this.start,
    required this.end,
  });

  final String word;
  final Duration start;
  final Duration end;
}

class DemoSegment {
  DemoSegment({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.speakerLabel,
    required this.alignments,
  }) : endTimestamp = alignments.isNotEmpty
            ? alignments.last.end
            : timestamp + Duration(milliseconds: text.length * 120);

  final String id;
  final String text;
  final Duration timestamp;
  final String speakerLabel;
  final List<DemoWordAlignment> alignments;
  final Duration endTimestamp;
}

class DemoCheck {
  DemoCheck({
    required this.start,
    required this.categoryLabel,
    required this.color,
  });

  final Duration start;
  final String categoryLabel;
  final Color color;
}

class DemoData {
  DemoData({
    required this.segments,
    required this.checks,
    required this.duration,
  });

  final List<DemoSegment> segments;
  final List<DemoCheck> checks;
  final Duration duration;
}

DemoData buildDemoData() {
  const wordSpan = Duration(milliseconds: 600);

  List<DemoWordAlignment> buildAlignments(String text, Duration start) {
    final words = text
        .split(RegExp(r'\\s+'))
        .where((token) => token.trim().isNotEmpty)
        .toList();
    final alignments = <DemoWordAlignment>[];
    var cursor = start;
    for (final word in words) {
      final end = cursor + wordSpan;
      alignments.add(DemoWordAlignment(word: word, start: cursor, end: end));
      cursor = end;
    }
    return alignments;
  }

  final segments = <DemoSegment>[
    DemoSegment(
      id: 'seg1',
      text: '지금은 프로젝트 킥오프를 마친 뒤 중요한 액션 아이템을 다시 점검하는 중입니다.',
      timestamp: const Duration(seconds: 0),
      speakerLabel: 'Alice',
      alignments: buildAlignments(
        '지금은 프로젝트 킥오프를 마친 뒤 중요한 액션 아이템을 다시 점검하는 중입니다.',
        const Duration(seconds: 0),
      ),
    ),
    DemoSegment(
      id: 'seg2',
      text: '두 번째 세션에서는 고객 인터뷰 결과를 바탕으로 핵심 개선 포인트를 정리했습니다.',
      timestamp: const Duration(seconds: 18),
      speakerLabel: 'Bob',
      alignments: buildAlignments(
        '두 번째 세션에서는 고객 인터뷰 결과를 바탕으로 핵심 개선 포인트를 정리했습니다.',
        const Duration(seconds: 18),
      ),
    ),
    DemoSegment(
      id: 'seg3',
      text: '세 번째 단계로는 프로토타입을 빠르게 검증하기 위해 디자인 드래프트를 공유했고,',
      timestamp: const Duration(seconds: 48),
      speakerLabel: 'Alice',
      alignments: buildAlignments(
        '세 번째 단계로는 프로토타입을 빠르게 검증하기 위해 디자인 드래프트를 공유했고,',
        const Duration(seconds: 48),
      ),
    ),
    DemoSegment(
      id: 'seg4',
      text: '마지막으로는 일정 리스크를 줄이기 위해 리소스 할당을 재조정하는 방안을 합의했습니다.',
      timestamp: const Duration(seconds: 78),
      speakerLabel: 'Charlie',
      alignments: buildAlignments(
        '마지막으로는 일정 리스크를 줄이기 위해 리소스 할당을 재조정하는 방안을 합의했습니다.',
        const Duration(seconds: 78),
      ),
    ),
  ];

  final checks = <DemoCheck>[
    DemoCheck(
      start: const Duration(seconds: 10),
      categoryLabel: 'Needs review',
      color: Colors.orange.shade400,
    ),
    DemoCheck(
      start: const Duration(seconds: 34),
      categoryLabel: 'Action item',
      color: Colors.indigo.shade400,
    ),
    DemoCheck(
      start: const Duration(seconds: 62),
      categoryLabel: 'Clarify',
      color: Colors.teal.shade400,
    ),
    DemoCheck(
      start: const Duration(seconds: 86),
      categoryLabel: 'Follow-up',
      color: Colors.pink.shade400,
    ),
  ];

  final duration = segments.last.endTimestamp + const Duration(seconds: 6);

  return DemoData(segments: segments, checks: checks, duration: duration);
}

String formatTimestamp(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

class SegmentScrollCoordinator {
  SegmentScrollCoordinator({
    required ScrollController scrollController,
    required bool Function() isMounted,
  })  : _scrollController = scrollController,
        _isMounted = isMounted;

  final ScrollController _scrollController;
  final bool Function() _isMounted;

  final Map<String, GlobalKey> segmentKeys = {};

  List<DemoSegment> _segments = const [];
  List<_SegmentAnchor> _anchors = const [];
  bool _anchorsDirty = true;
  bool _anchorRebuildScheduled = false;

  void updateSegments(List<DemoSegment> segments) {
    _segments = segments;
    final activeIds = <String>{};
    for (final segment in segments) {
      activeIds.add(segment.id);
      segmentKeys.putIfAbsent(segment.id, () => GlobalKey());
    }
    segmentKeys.removeWhere((key, _) => !activeIds.contains(key));
    _markAnchorsDirty();
  }

  void registerScrollHandler(
    void Function(Future<void> Function(Duration timestamp) register) register,
  ) {
    _schedulePostFrame(() {
      if (!_isMounted()) return;
      register(scrollTo);
    });
  }

  Future<void> scrollTo(Duration timestamp) async {
    var target = timestamp;
    if (target < Duration.zero) target = Duration.zero;

    if (!_scrollController.hasClients) {
      _schedulePostFrame(() {
        if (!_isMounted()) return;
        unawaited(scrollTo(target));
      });
      return;
    }

    await _ensureAnchors();
    if (_anchors.isEmpty) {
      _schedulePostFrame(() {
        if (!_isMounted()) return;
        unawaited(scrollTo(target));
      });
      return;
    }

    final targetOffset = _resolveOffset(target);
    if (targetOffset == null) return;

    final position = _scrollController.position;
    var clamped = targetOffset;
    if (clamped < position.minScrollExtent) clamped = position.minScrollExtent;
    if (clamped > position.maxScrollExtent) clamped = position.maxScrollExtent;
    if ((position.pixels - clamped).abs() < 1) return;

    await _scrollController.animateTo(
      clamped,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  void rebuildAnchors() => _rebuildAnchors();

  void dispose() {
    segmentKeys.clear();
    _segments = const [];
    _anchors = const [];
  }

  Future<void> _ensureAnchors() async {
    if (!_anchorsDirty && _anchors.isNotEmpty) return;
    _rebuildAnchors();
    if (_anchorsDirty && !_anchorRebuildScheduled) {
      _anchorRebuildScheduled = true;
      _schedulePostFrame(() {
        _anchorRebuildScheduled = false;
        if (!_isMounted()) return;
        _rebuildAnchors();
      });
    }
  }

  void _rebuildAnchors() {
    if (!_scrollController.hasClients) {
      _anchorsDirty = true;
      return;
    }

    final anchors = <_SegmentAnchor>[];
    for (final segment in _segments) {
      final key = segmentKeys[segment.id];
      if (key == null) continue;
      final context = key.currentContext;
      if (context == null) continue;
      final renderObject = context.findRenderObject();
      if (renderObject == null) continue;
      final viewport = RenderAbstractViewport.of(renderObject);
      final reveal = viewport.getOffsetToReveal(renderObject, 0);

      anchors.add(
        _SegmentAnchor(
          id: segment.id,
          start: segment.timestamp,
          end: segment.endTimestamp,
          offset: reveal.offset,
        ),
      );
    }

    anchors.sort((a, b) => a.start.compareTo(b.start));
    _anchors = anchors;
    _anchorsDirty = anchors.length != _segments.length;
  }

  double? _resolveOffset(Duration timestamp) {
    if (_anchors.isEmpty) return null;
    for (var i = 0; i < _anchors.length; i++) {
      final anchor = _anchors[i];
      final isLast = i == _anchors.length - 1;
      if (timestamp <= anchor.end || isLast) {
        return anchor.offset;
      }
      final next = _anchors[i + 1];
      if (timestamp > anchor.end && timestamp < next.start) {
        return next.offset;
      }
    }
    return _anchors.last.offset;
  }

  void _markAnchorsDirty() {
    if (_anchorsDirty) return;
    _anchorsDirty = true;
    if (_anchorRebuildScheduled) return;
    _anchorRebuildScheduled = true;
    _schedulePostFrame(() {
      _anchorRebuildScheduled = false;
      if (!_isMounted()) return;
      _rebuildAnchors();
    });
  }

  void _schedulePostFrame(VoidCallback callback) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) return;
      callback();
    });
  }
}

class _SegmentAnchor {
  const _SegmentAnchor({
    required this.id,
    required this.start,
    required this.end,
    required this.offset,
  });

  final String id;
  final Duration start;
  final Duration end;
  final double offset;
}

import 'dart:async';

import 'package:flutter/material.dart';

import 'constants.dart';
import 'data.dart';
import 'playback.dart';
import 'scrolling.dart';
import 'widgets/segment_list.dart';
import 'widgets/timeline_controls.dart';

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
      if (difference >= pauseScrollThreshold) {
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
    final anchor = center - scrollAnchorOffset;
    if (anchor < Duration.zero) return Duration.zero;
    return anchor;
  }

  Duration _difference(Duration a, Duration b) {
    final diff = a - b;
    return diff.isNegative ? -diff : diff;
  }

  @override
  Widget build(BuildContext context) {
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
                    child: SegmentList(
                      segments: _segments,
                      currentPosition: _currentPosition,
                      onTapSegment: (segment) =>
                          _handleSeek(segment.timestamp, forcePlay: true),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'data.dart';

class SegmentScrollCoordinator {
  SegmentScrollCoordinator({
    required ScrollController scrollController,
    required bool Function() isMounted,
  })
      : _scrollController = scrollController,
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

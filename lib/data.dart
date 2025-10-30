import 'package:flutter/material.dart';

class DemoSegment {
  DemoSegment({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.speakerLabel,
    required this.duration,
  }) : endTimestamp = timestamp + duration;

  final String id;
  final String text;
  final Duration timestamp;
  final String speakerLabel;
  final Duration duration;
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
  final segments = <DemoSegment>[
    DemoSegment(
      id: 'seg1',
      text:
          '지금은 프로젝트 킥오프를 마친 뒤 중요한 액션 아이템을 다시 점검하는 중입니다.',
      timestamp: const Duration(seconds: 0),
      speakerLabel: 'Alice',
      duration: _estimateDuration(
        '지금은 프로젝트 킥오프를 마친 뒤 중요한 액션 아이템을 다시 점검하는 중입니다.',
      ),
    ),
    DemoSegment(
      id: 'seg2',
      text:
          '두 번째 세션에서는 고객 인터뷰 결과를 바탕으로 핵심 개선 포인트를 정리했습니다.',
      timestamp: const Duration(seconds: 18),
      speakerLabel: 'Bob',
      duration: _estimateDuration(
        '두 번째 세션에서는 고객 인터뷰 결과를 바탕으로 핵심 개선 포인트를 정리했습니다.',
      ),
    ),
    DemoSegment(
      id: 'seg3',
      text:
          '세 번째 단계로는 프로토타입을 빠르게 검증하기 위해 디자인 드래프트를 공유했고,',
      timestamp: const Duration(seconds: 48),
      speakerLabel: 'Alice',
      duration: _estimateDuration(
        '세 번째 단계로는 프로토타입을 빠르게 검증하기 위해 디자인 드래프트를 공유했고,',
      ),
    ),
    DemoSegment(
      id: 'seg4',
      text:
          '마지막으로는 일정 리스크를 줄이기 위해 리소스 할당을 재조정하는 방안을 합의했습니다.',
      timestamp: const Duration(seconds: 78),
      speakerLabel: 'Charlie',
      duration: _estimateDuration(
        '마지막으로는 일정 리스크를 줄이기 위해 리소스 할당을 재조정하는 방안을 합의했습니다.',
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

Duration _estimateDuration(String text) {
  final wordCount = text
      .trim()
      .split(RegExp(r'\s+'))
      .where((token) => token.isNotEmpty)
      .length;
  if (wordCount == 0) {
    return const Duration(milliseconds: 600);
  }
  return Duration(milliseconds: wordCount * 600);
}

import 'dart:async';

enum PlaybackStatus { ready, playing, paused, completed }

class PlaybackSimulator {
  PlaybackSimulator({
    required this.duration,
    Duration tickInterval = const Duration(milliseconds: 200),
  })
      : _tickInterval = tickInterval,
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

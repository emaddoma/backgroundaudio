import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

MediaControl playControl = MediaControl(
  androidIcon: 'drawable/ic_action_play_arrow',
  label: 'Play',
  action: MediaAction.play,
);
MediaControl pauseControl = MediaControl(
  androidIcon: 'drawable/ic_action_pause',
  label: 'Pause',
  action: MediaAction.pause,
);
MediaControl skipToNextControl = MediaControl(
  androidIcon: 'drawable/ic_action_skip_next',
  label: 'Next',
  action: MediaAction.skipToNext,
);
MediaControl skipToPreviousControl = MediaControl(
  androidIcon: 'drawable/ic_action_skip_previous',
  label: 'Previous',
  action: MediaAction.skipToPrevious,
);
MediaControl stopControl = MediaControl(
  androidIcon: 'drawable/ic_action_stop',
  label: 'Stop',
  action: MediaAction.stop,
);

class AudioPlayerTask extends BackgroundAudioTask {

  AudioPlayer _audioPlayer = new AudioPlayer();
  List<MediaItem> _queue = new List<MediaItem>();

  StreamSubscription<AudioPlaybackState> _playerStateSubscription;
  StreamSubscription<AudioPlaybackEvent> _eventSubscription;

  bool _playing;
  AudioProcessingState _skipState;
  int _queueIndex = -1;

  MediaItem get mediaItem => _queue[_queueIndex];

  bool get hasNext => _queueIndex + 1 < _queue.length;

  bool get hasPrevious => _queueIndex > 0;

  @override
  void onStart(Map<String, dynamic> params) {
    print("[audiotask start]");

    _playerStateSubscription = _audioPlayer.playbackStateStream
        .where((state) => state == AudioPlaybackState.completed)
        .listen((state) {
      _handlePlaybackCompleted();
    });

    _eventSubscription = _audioPlayer.playbackEventStream.listen((event) {
      final bufferingState =
          event.buffering ? AudioProcessingState.buffering : null;
      switch (event.state) {
        case AudioPlaybackState.paused:
          _setState(
            processingState: bufferingState ?? AudioProcessingState.ready,
            position: event.position,
          );
          break;
        case AudioPlaybackState.playing:
          _setState(
            processingState: bufferingState ?? AudioProcessingState.ready,
            position: event.position,
          );
          break;
        case AudioPlaybackState.connecting:
          _setState(
            processingState: _skipState ?? AudioProcessingState.connecting,
            position: event.position,
          );
          break;
        default:
          break;
      }
    });

    /*
    _queue = <MediaItem>[
      MediaItem(
        id: "https://s3.amazonaws.com/scifri-episodes/scifri20181123-episode.mp3",
        album: "Science Friday",
        title: "A Salute To Head-Scratching Science",
        artist: "Science Friday and WNYC Studios",
        duration: Duration(milliseconds: 5739820),
        artUri:
            "https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg",
      ),
      MediaItem(
        id: "https://s3.amazonaws.com/scifri-segments/scifri201711241.mp3",
        album: "Science Friday",
        title: "From Cat Rheology To Operatic Incompetence",
        artist: "Science Friday and WNYC Studios",
        duration: Duration(milliseconds: 2856950),
        artUri:
            "https://media.wnyc.org/i/1400/1400/l/80/1/ScienceFriday_WNYCStudios_1400.jpg",
      ),
    ];
    */

    AudioServiceBackground.setQueue(_queue);

    onSkipToNext();

  }

  Future<void> _setState({
    AudioProcessingState processingState,
    Duration position,
    Duration bufferedPosition,
  }) async {
    if (position == null) {
      position = _audioPlayer.playbackEvent.position;
    }
    await AudioServiceBackground.setState(
      controls: getControls(),
      systemActions: [MediaAction.seekTo],
      processingState:
          processingState ?? AudioServiceBackground.state.processingState,
      playing: _playing,
      position: position,
      bufferedPosition: bufferedPosition ?? position,
      speed: _audioPlayer.speed,
    );
  }

  List<MediaControl> getControls() {
    if (_playing) {
      return [
        skipToPreviousControl,
        pauseControl,
        stopControl,
        skipToNextControl
      ];
    } else {
      return [
        skipToPreviousControl,
        playControl,
        stopControl,
        skipToNextControl
      ];
    }
  }

  Future<void> _handlePlaybackCompleted() async {
    print("[audiotask playback complete]");
    if (hasNext) {
      print("advancing to next track");
      onSkipToNext();
    } else {
      print("queue exhausted, keeping alive");
      _queue.removeAt(_queueIndex);
      _queueIndex = _queue.length - 1;
      _queue.add(MediaItem(
        id: "https://tripchat-la-api.herokuapp.com/paused.mp3",
        album: "Louisiana",
        title: "Waiting...",
        artist: "TripChat",
        extras: {'id': 'paused', 'event': 'LOITER'}
      ));
      await AudioServiceBackground.setQueue(_queue);
      onSkipToNext();
    }
  }

  @override
  Future<void> onAddQueueItem(MediaItem mediaItem) async {
    print("[audiotask onAddQueueItem]");
    bool purged = false;
    
    if(_queue.isNotEmpty && _queueIndex > -1){
      print("Current: ${_queue[_queueIndex].toString()}");
    }

    // If the current track is silence, remove it
    if(_queueIndex > -1 && _queue[_queueIndex].extras['id'] == 'paused'){
      print("REMOVING SILENCE FROM QUEUE");
      _queue.removeAt(_queueIndex);
      _queueIndex = _queue.length - 1;
      purged = true;
    }

    _queue.add(mediaItem);

    await AudioServiceBackground.setQueue(_queue);

    // If we purged
    if(purged){
      print("POST-PURGE");
      onSkipToNext();
    }

    // If this is our first track, play
    if(_queue.length == 1 && _queueIndex == -1 && (_playing == false || _playing == null)){
      print("FIRST TRACK");
      onSkipToNext();
    }
    
    // If the item is added after playback has stopped, play 
    if(_queue.length -1 > _queueIndex && _playing == false){
      print('CONTINUE');
      onSkipToNext();
    }

    super.onAddQueueItem(mediaItem);
  }

  @override
  void onPlay() {
    print("[audiotask play]");
    if (_skipState == null) {
      _playing = true;
      _audioPlayer.play();
      AudioServiceBackground.sendCustomEvent('just played');
    }
  }

  @override
  void onSeekTo(Duration position) {
    _audioPlayer.seek(position);
  }

  @override
  Future<void> onFastForward() async {
    await _seekRelative(fastForwardInterval);
  }

  @override
  Future<void> onRewind() async {
    await _seekRelative(-rewindInterval);
  }

  Future<void> _seekRelative(Duration offset) async {
    var newPosition = _audioPlayer.playbackEvent.position + offset;
    if (newPosition < Duration.zero) newPosition = Duration.zero;
    if (newPosition > mediaItem.duration) newPosition = mediaItem.duration;
    await _audioPlayer.seek(newPosition);
  }

  @override
  void onPause() {
    print("[audiotask pause]");
    if (_skipState == null && _playing != null && _playing == true) {
      _playing = false;
      _audioPlayer.pause();
      AudioServiceBackground.sendCustomEvent('just paused');
    }
    super.onPause();
  }

  @override
  Future<void> onStop() async {
    print("[audiotask stop]");

    await _audioPlayer.stop();
    await _audioPlayer.dispose();
    _playing = false;
    _playerStateSubscription.cancel();
    _eventSubscription.cancel();
    await _setState(processingState: AudioProcessingState.stopped);

    await super.onStop();
  }

  @override
  Future<void> onSkipToNext() => _skip(1);

  @override
  Future<void> onSkipToPrevious() => _skip(-1);

  Future<void> _skip(int offset) async {
    final newPos = _queueIndex + offset;
    if (!(newPos >= 0 && newPos < _queue.length)) return;
    if (_playing == null) {
      // First time, we want to start playing
      _playing = true;
    } else if (_playing) {
      // Stop current item
      await _audioPlayer.stop();
    }
    // Load next item
    _queueIndex = newPos;
    AudioServiceBackground.setMediaItem(mediaItem);
    _skipState = offset > 0
        ? AudioProcessingState.skippingToNext
        : AudioProcessingState.skippingToPrevious;
    await _audioPlayer.setUrl(mediaItem.id);
    _skipState = null;
    // Resume playback if we were playing
    if (_playing) {
      onPlay();
    } else {
      _setState(processingState: AudioProcessingState.ready);
    }
  }

}
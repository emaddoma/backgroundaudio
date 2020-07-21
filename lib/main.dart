import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:backgroundaudio/audiotask.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_geolocation/flutter_background_geolocation.dart' as bgGeo;
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';

void _audioPlayerTaskEntrypoint() async {
  AudioServiceBackground.run(() => AudioPlayerTask());
}

Stream<ScreenState> get _screenStateStream =>
      Rx.combineLatest3<List<MediaItem>, MediaItem, PlaybackState, ScreenState>(
          AudioService.queueStream,
          AudioService.currentMediaItemStream,
          AudioService.playbackStateStream,
          (queue, mediaItem, playbackState) =>
              ScreenState(queue, mediaItem, playbackState));

class ScreenState {
  final List<MediaItem> queue;
  final MediaItem mediaItem;
  final PlaybackState playbackState;

  ScreenState(this.queue, this.mediaItem, this.playbackState);
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AudioServiceWidget(child: MyHomePage(title: 'Background Audio Demo')),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {

  bool geoStarted = false;

  IconButton playButton() => IconButton(
        icon: Icon(Icons.play_arrow),
        iconSize: 64.0,
        onPressed: AudioService.play,
      );

  IconButton pauseButton() => IconButton(
        icon: Icon(Icons.pause),
        iconSize: 64.0,
        onPressed: AudioService.pause,
      );

  IconButton stopButton() => IconButton(
        icon: Icon(Icons.stop),
        iconSize: 64.0,
        onPressed: AudioService.stop,
      );

  Widget positionIndicator(MediaItem mediaItem, PlaybackState state) {
    double seekPos;
    return StreamBuilder(
      stream: Rx.combineLatest2<double, double, double>(
          _dragPositionSubject.stream,
          Stream.periodic(Duration(milliseconds: 200)),
          (dragPosition, _) => dragPosition),
      builder: (context, snapshot) {
        double position =
            snapshot.data ?? state.currentPosition.inMilliseconds.toDouble();
        double duration = mediaItem?.duration?.inMilliseconds?.toDouble();
        return Column(
          children: [
            if (duration != null)
              Slider(
                min: 0.0,
                max: duration,
                value: seekPos ?? max(0.0, min(position, duration)),
                onChanged: (value) {
                  _dragPositionSubject.add(value);
                },
                onChangeEnd: (value) {
                  AudioService.seekTo(Duration(milliseconds: value.toInt()));
                  // Due to a delay in platform channel communication, there is
                  // a brief moment after releasing the Slider thumb before the
                  // new position is broadcast from the platform side. This
                  // hack is to hold onto seekPos until the next state update
                  // comes through.
                  // TODO: Improve this code.
                  seekPos = value;
                  _dragPositionSubject.add(null);
                },
              ),
            Text("${state.currentPosition}"),
          ],
        );
      },
    );
  }

  final BehaviorSubject<double> _dragPositionSubject = BehaviorSubject.seeded(null);

  @override
  void initState() {
    super.initState();

    bgGeo.BackgroundGeolocation.requestPermission().then((int status) {
      print("[requestPermission] STATUS: ${status}");
      switch(status) {
        case bgGeo.ProviderChangeEvent.AUTHORIZATION_STATUS_ALWAYS:
          print("[requestPermission] AUTHORIZATION_STATUS_ALWAYS");
          break;
        case bgGeo.ProviderChangeEvent.AUTHORIZATION_STATUS_WHEN_IN_USE:
          print("[requestPermission] AUTHORIZATION_STATUS_WHEN_IN_USE");
          break;
        case bgGeo.ProviderChangeEvent.AUTHORIZATION_STATUS_DENIED:
          print("[requestPermission] AUTHORIZATION_STATUS_DENIED");
          break;
        case bgGeo.ProviderChangeEvent.AUTHORIZATION_STATUS_NOT_DETERMINED:
          print("[requestPermission] AUTHORIZATION_STATUS_NOT_DETERMINED");
          break;
        case bgGeo.ProviderChangeEvent.AUTHORIZATION_STATUS_RESTRICTED:
          print("[requestPermission] AUTHORIZATION_STATUS_RESTRICTED");
          break;
      }
    }).catchError((dynamic error) {
      print("[requestPermission] ERROR: ${error}");
    });

    bgGeo.BackgroundGeolocation.onLocation((bgGeo.Location location) {
      print('[location change]\n\n');
    });

    // Fired whenever the plugin changes motion-state (stationary->moving and vice-versa)
    bgGeo.BackgroundGeolocation.onMotionChange((bgGeo.Location location) {
      print('[motion change]\n\n');
    });

    // Fired whenever the state of location-services changes.  Always fired at boot
    bgGeo.BackgroundGeolocation.onProviderChange((bgGeo.ProviderChangeEvent event) {
      print('[provider change]\n\n');
    });

    bgGeo.BackgroundGeolocation.onGeofence((bgGeo.GeofenceEvent event) async {
      print('[geofence ${event.identifier} ${event.action}]\n\n');
      if(event.action != 'ENTER'){
        return;
      }
      var db = await openDatabase('my_db.db');
      List<Map> list = await db.rawQuery('SELECT * FROM poi WHERE id = ?', [event.identifier]);
      if (list.length == 0) {
        print("No matching POI!");
        return;
      }
      Map record = list.first;
      print("$record");

      if(!AudioService.running){
        await startAudio();
      }

      print('AudioService.addQueueItem()');
      AudioService.addQueueItem(MediaItem(
        id: record['audio'],
        album: "Demo",
        title: record['id'],
        artist: "Demo",
        extras: {'id': record['id'], 'event': event.action}
      ));
    });

    WidgetsBinding.instance.addObserver(this);

  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  didChangeAppLifecycleState(AppLifecycleState state) async {
    super.didChangeAppLifecycleState(state);

    print("didChangeAppLifecycleState: ${state.toString()}");
  }

  Future<void> startAudio() async {
    print('AudioService.start()');
    await AudioService.start(
      backgroundTaskEntrypoint: _audioPlayerTaskEntrypoint,
      androidNotificationChannelName: 'Audio Service Demo',
      // Enable this if you want the Android service to exit the foreground state on pause.
      //androidStopForegroundOnPause: true,
      androidNotificationColor: 0xFF2196f3,
      androidNotificationIcon: 'mipmap/ic_launcher',
      androidEnableQueue: true,
    );

    print('AudioService.addQueueItem()');
    AudioService.addQueueItem(MediaItem(
      id: 'https://raw.githubusercontent.com/anars/blank-audio/master/5-seconds-of-silence.mp3', 
      album: "Demo",
      title: "Waiting for Audio...",
      artist: "Demo",
    ));

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: StreamBuilder<ScreenState>(
          stream: _screenStateStream,
          builder: (context, snapshot){

            final screenState = snapshot.data;
            final queue = screenState?.queue;
            final mediaItem = screenState?.mediaItem;
            final state = screenState?.playbackState;
            final processingState = state?.processingState ?? AudioProcessingState.none;
            final playing = state?.playing ?? false;

            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[

                if(!geoStarted) ...[
                  FlatButton(
                    child: Text('Start Geo'),
                    onPressed: () async {

                      var db = await openDatabase('my_db.db');
                      try {
                        await db.execute('DROP TABLE poi');
                      } catch (err) {
                        // TABLE DIDN'T EXIST
                      }
                      await db.execute('CREATE TABLE poi (id TEXT PRIMARY KEY, audio TEXT)').then((value) => null);
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'One\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-three/animal_bull_scottish_highland_moo_002.mp3?_=2\')');
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'Two\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-46416/zapsplat_animals_pig_grunt_designed_009_51358.mp3?_=9\')');
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'Three\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-35448/zapsplat_animals_bird_cockatoo_black_squawk_slight_distance_003_41717.mp3?_=5\')');
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'Four\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-smartsound/smartsound_ANIMAL_PANTHER_Young_Snarl_03.mp3?_=3\')');
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'Five\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-smartsound/smartsound_ANIMAL_DOG_Puppy_Growl_Aggressive_01.mp3?_=10\')');
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'Six\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-smartsound/smartsound_ANIMAL_BIRD_OF_PREY_Eagle_Call_01.mp3?_=1\')');
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'Seven\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-35448/zapsplat_animals_owl_hoot_night_002_37137.mp3?_=7\')');
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'Eight\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-27787/zapsplat_animals_cat_kitten_meow_006_30182.mp3?_=10\')');
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'Nine\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-glitched-tones/glitched_tones_urban_farm_hens_365.mp3?_=5\')');
                      await db.execute('INSERT INTO poi (id, audio) VALUES (\'Ten\', \'https://www.zapsplat.com/wp-content/uploads/2015/sound-effects-27787/zapsplat_animals_bird_parrot_black_cockatoo_squawk_single_003_28297.mp3?_=5\')');

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "One",
                        radius: 100,
                        latitude: 38.89058,
                        longitude: -77.00437,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "Two",
                        radius: 100,
                        latitude: 38.89062,
                        longitude: -77.00913,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "Three",
                        radius: 100,
                        latitude: 38.88898,
                        longitude: -77.00909,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "Four",
                        radius: 100,
                        latitude: 38.88815,
                        longitude: -77.01959,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "Five",
                        radius: 100,
                        latitude: 38.88874,
                        longitude: -77.02599,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "Six",
                        radius: 100,
                        latitude: 38.88945,
                        longitude: -77.03529,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "Seven",
                        radius: 100,
                        latitude: 38.88931,
                        longitude: -77.05017,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "Eight",
                        radius: 100,
                        latitude: 38.89761,
                        longitude: -77.03667,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "Nine",
                        radius: 100,
                        latitude: 38.89115,
                        longitude: -77.02609,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.addGeofence(bgGeo.Geofence(
                        identifier: "Ten",
                        radius: 100,
                        latitude: 38.89121,
                        longitude: -77.02005,
                        notifyOnEntry: true,
                        notifyOnExit: false,
                      ));

                      bgGeo.BackgroundGeolocation.ready(bgGeo.Config(
                          desiredAccuracy: bgGeo.Config.DESIRED_ACCURACY_NAVIGATION,
                          distanceFilter: 10.0,
                          stopOnTerminate: false,
                          startOnBoot: true,
                          debug: true,
                          logLevel: bgGeo.Config.LOG_LEVEL_ERROR,
                          geofenceProximityRadius: 1000,
                          disableLocationAuthorizationAlert: false,
                          locationAuthorizationAlert: {
                            'titleWhenNotEnabled': 'Yo, location-services not enabled',
                            'titleWhenOff': 'Yo, location-services OFF',
                            'instructions': 'You must enable \'Always\' in location-services, buddy',
                            'cancelButton': 'Cancel',
                            'settingsButton': 'Settings'
                          }
                      )).then((bgGeo.State state) async {
                        if (!state.enabled) {
                          bgGeo.BackgroundGeolocation.start();
                        }

                        await startAudio();

                        setState(() {
                          geoStarted = true;
                        });

                      });

                      

                    },
                  )
                ] else ...[
                  if(!AudioService.running) ...[
                    Text("Audio Service Not Running")
                  ] else if (queue != null && queue.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.skip_previous),
                          iconSize: 64.0,
                          onPressed: mediaItem == queue.first
                              ? null
                              : AudioService.skipToPrevious,
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next),
                          iconSize: 64.0,
                          onPressed: mediaItem == queue.last
                              ? null
                              : AudioService.skipToNext,
                        ),
                      ],
                    ),
                    if (mediaItem?.title != null) Text(mediaItem.title),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (playing) pauseButton() else playButton(),
                        stopButton(),
                      ],
                    ),
                    positionIndicator(mediaItem, state),
                    Text("Processing state: " +
                        "$processingState".replaceAll(RegExp(r'^.*\.'), '')),
                    StreamBuilder(
                      stream: AudioService.customEventStream,
                      builder: (context, snapshot) {
                        return Text("custom event: ${snapshot.data}");
                      },
                    ),
                    StreamBuilder<bool>(
                      stream: AudioService.notificationClickEventStream,
                      builder: (context, snapshot) {
                        return Text(
                          'Notification Click Status: ${snapshot.data}',
                        );
                      },
                    ),
                  ] else ... [
                    Text("Awaiting Audio")
                  ],
                ],

              ],
            );
          }
        ),
      ),
    );
  }
}

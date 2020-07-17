# backgroundaudio

A demo Flutter project of background location (geofence) detection that triggers audio playback.

Accept all prompts for permissions and click Start Geo.  On iOS, you can use ControlRoom (https://github.com/twostraws/ControlRoom) to change locations.  The geofences are all on the National Mall in Washington, DC.

- US Supreme Court
- US Senate
- US House of Representatives
- Air and Space Museum
- Smithsonian Castle
- National Gallery of Art
- White House
- Washington Monument
- Lincoln Memorial
- National Museum of Natural History

A suvvessful geofence entry will trigger audio playback, whether the app is in the foreground or background.  Except on Android, which fails when the app is in the background with the following error...

`
E/MethodChannel#ryanheise.com/audioService(28150): Failed to handle method call
E/MethodChannel#ryanheise.com/audioService(28150): java.lang.NullPointerException: Attempt to invoke virtual method 'void android.support.v4.media.session.MediaControllerCompat.addQueueItem(android.support.v4.media.MediaDescriptionCompat)' on a null object reference
E/MethodChannel#ryanheise.com/audioService(28150):      at com.ryanheise.audioservice.AudioServicePlugin$ClientHandler.onMethodCall(AudioServicePlugin.java:409)
E/MethodChannel#ryanheise.com/audioService(28150):      at io.flutter.plugin.common.MethodChannel$IncomingMethodCallHandler.onMessage(MethodChannel.java:226)
E/MethodChannel#ryanheise.com/audioService(28150):      at io.flutter.embedding.engine.dart.DartMessenger.handleMessageFromDart(DartMessenger.java:85)
E/MethodChannel#ryanheise.com/audioService(28150):      at io.flutter.embedding.engine.FlutterJNI.handlePlatformMessage(FlutterJNI.java:631)
E/MethodChannel#ryanheise.com/audioService(28150):      at android.os.MessageQueue.nativePollOnce(Native Method)
E/MethodChannel#ryanheise.com/audioService(28150):      at android.os.MessageQueue.next(MessageQueue.java:336)
E/MethodChannel#ryanheise.com/audioService(28150):      at android.os.Looper.loop(Looper.java:174)
E/MethodChannel#ryanheise.com/audioService(28150):      at android.app.ActivityThread.main(ActivityThread.java:7356)
E/MethodChannel#ryanheise.com/audioService(28150):      at java.lang.reflect.Method.invoke(Native Method)
E/MethodChannel#ryanheise.com/audioService(28150):      at com.android.internal.os.RuntimeInit$MethodAndArgsCaller.run(RuntimeInit.java:492)
E/MethodChannel#ryanheise.com/audioService(28150):      at com.android.internal.os.ZygoteInit.main(ZygoteInit.java:930)
E/flutter (28150): [ERROR:flutter/lib/ui/ui_dart_state.cc(157)] Unhandled Exception: PlatformException(error, Attempt to invoke virtual method 'void android.support.v4.media.session.MediaControllerCompat.addQueueItem(android.support.v4.media.MediaDescriptionCompat)' on a null object reference, null)
E/flutter (28150): #0      StandardMethodCodec.decodeEnvelope (package:flutter/src/services/message_codecs.dart:569:7)
E/flutter (28150): #1      MethodChannel._invokeMethod (package:flutter/src/services/platform_channel.dart:156:18)
E/flutter (28150): <asynchronous suspension>
E/flutter (28150): #2      MethodChannel.invokeMethod (package:flutter/src/services/platform_channel.dart:329:12)
E/flutter (28150): #3      AudioService.addQueueItem (package:audio_service/audio_service.dart:726:20)
E/flutter (28150): #4      _MyHomePageState.initState.<anonymous closure> (package:backgroundaudio/main.dart:180:20)
E/flutter (28150): <asynchronous suspension>
E/flutter (28150): #5      _MyHomePageState.initState.<anonymous closure> (package:backgroundaudio/main.dart)
E/flutter (28150): #6      _rootRunUnary (dart:async/zone.dart:1192:38)
E/flutter (28150): #7      _CustomZone.runUnary (dart:async/zone.dart:1085:19)
E/flutter (28150): #8      _CustomZone.runUnaryGuarded (dart:async/zone.dart:987:7)
E/flutter (28150): #9      _BufferingStreamSubscription._sendData (dart:async/stream_impl.dart:339:11)
E/flutter (28150): #10     _BufferingStreamSubscription._add (dart:async/stream_impl.dart:266:7)
E/flutter (28150): #11     _ForwardingStreamSubscription._add (dart:async/stream_pipe.dart:134:11)
E/flutter (28150): #12     _MapStream._handleData (dart:async/stream_pipe.dart:234:10)
E/flutter (28150): #13     _ForwardingStreamSubscription._handleData (dart:async/stream_pipe.dart:166:13)
E/flutter (28150): #14     _rootRunUnary (dart:async/zone.dart:1192:38)
E/flutter (28150): #15     _CustomZone.runUnary (dart:async/zone.dart:1085:19)
E/flutter (28150): #16     _CustomZone.runUnaryGuarded (dart:async/zone.dart:987:7)
E/flutter (28150): #17     _BufferingStreamSubscription._sendData (dart:async/stream_impl.dart:339:11)
E/flutter (28150): #18     _DelayedData.perform (dart:async/stream_impl.dart:594:14)
E/flutter (28150): #19     _StreamImplEvents.handleNext (dart:async/stream_impl.dart:710:11)
E/flutter (28150): #20     _PendingEvents.schedule.<anonymous closure> (dart:async/stream_impl.dart:670:7)
E/flutter (28150): #21     _rootRun (dart:async/zone.dart:1180:38)
E/flutter (28150): #22     _CustomZone.run (dart:async/zone.dart:1077:19)
E/flutter (28150): #23     _CustomZone.runGuarded (dart:async/zone.dart:979:7)
E/flutter (28150): #24     _CustomZone.bindCallbackGuarded.<anonymous closure> (dart:async/zone.dart:1019:23)
E/flutter (28150): #25     _rootRun (dart:async/zone.dart:1184:13)
E/flutter (28150): #26     _CustomZone.run (dart:async/zone.dart:1077:19)
E/flutter (28150): #27     _CustomZone.runGuarded (dart:async/zone.dart:979:7)
E/flutter (28150): #28     _CustomZone.bindCallbackGuarded.<anonymous closure> (dart:async/zone.dart:1019:23)
E/flutter (28150): #29     _microtaskLoop (dart:async/schedule_microtask.dart:43:21)
E/flutter (28150): #30     _startMicrotaskLoop (dart:async/schedule_microtask.dart:52:5)
E/flutter (28150): 
I/flutter (28150): [location change]
I/flutter (28150): 
`

import 'package:polymer/polymer.dart';
import 'dart:html' hide Notification;
import 'dart:web_audio';
import 'dart:async';
import 'dart:js';
import 'package:paper_elements/paper_toggle_button.dart';

import '../lib/app_services.dart';
import '../lib/notification_patch.dart';
import 'paper-tristate-toggle-button.dart';

@CustomTag('pomeranian-app')
class PomeranianApp extends PolymerElement with Observable {
  static const String APP_NAME = "pomeranian_chrome";
  static const String RINGING_URI = "assets/sounds/ring.ogg";
  static const String WIND_UP_URI = "assets/sounds/wind.ogg";
  static const String TICKING_URI = "assets/sounds/tick-loop.ogg";
  
  @observable int selected;
  @observable String timeRemaining;
  @observable String status;
  
  DateTime expires = null;
  
  Timer clockTick = null;
  Timer endOfTimer = null;
  
  AudioBufferSourceNode _tickingLoop;
  
  AppDelegate get _appDelegate {
    if (__appDelegate == null) {
      if (context['appDelegate'] != null) {
        __appDelegate = new JsAppDelegate(context['appDelegate']);
        
      }
      else
        __appDelegate = new _HTML5AppDelegate();
    }
    return __appDelegate;
  }
  AppDelegate __appDelegate = null;
  
  AudioContext _audioContext;
  AudioContext get audioContext {
    if (_audioContext == null)
      _audioContext = new AudioContext();
    return _audioContext;
  }
  
  
  @observable bool tryNotifications = true;
  void tryNotificationsChanged(bool oldValue) {
    _appDelegate.tryNotifications = tryNotifications;
    if (_appDelegate.hasStorageCapabilities)
      _appDelegate.storeKey(
          "$APP_NAME.notifications",
          tryNotifications.toString());
  }
  
  @observable int keepOnTop;
  void keepOnTopChanged(int oldValue) {
    switch (keepOnTop) {
      case 1:
        _appDelegate.keepOnTop = (expires == null);
        break;
      case 2:
        _appDelegate.keepOnTop = true;
        break;
      default:
        _appDelegate.keepOnTop = false;
        break;
    }
    if (_appDelegate.hasStorageCapabilities)
      _appDelegate.storeKey(
        "$APP_NAME.alwaysOnTop",
        keepOnTop.toString());
  }
  @ComputedProperty("(keepOnTop == 0)?'Never':((keepOnTop == 1)?'When Stopped':'Always')")
  String get keepOnTopDescription => readValue(#keepOnTopDescription);
  
  @observable bool tryNotify;
  void tryNotifyChanged(bool oldValue) {
    if (_appDelegate.hasStorageCapabilities)
      _appDelegate.storeKey(
        "$APP_NAME.notify",
        tryNotify.toString());
  }
  
  @observable bool doAlarmAudio = false;
  void doAlarmAudioChanged(bool oldValue) {
    _appDelegate.doAlarmAudio = doAlarmAudio;
    if (_appDelegate.hasStorageCapabilities)
      _appDelegate.storeKey(
          "$APP_NAME.doAlarmAudio",
          doAlarmAudio.toString());
  }

  @observable bool doTickAudio = false;
  void doTickAudioChanged(bool oldValue) {
    if (_appDelegate.hasStorageCapabilities)
      _appDelegate.storeKey(
          "$APP_NAME.doTickAudio",
          doTickAudio.toString());
    if (expires != null && doTickAudio) {
      var request_ticking = new HttpRequest();
      request_ticking.onLoad.listen((event) {
        audioContext.decodeAudioData(request_ticking.response).then((buffer) {
          if (!doAlarmAudio) return;
         
          _tickingLoop = audioContext.createBufferSource();
          _tickingLoop.buffer = buffer;
          _tickingLoop.connectNode(audioContext.destination);
          _tickingLoop.loop = true;
          _tickingLoop.start(0);
        });
      });
      request_ticking.responseType = 'arraybuffer';
      request_ticking.open('GET', TICKING_URI);
      request_ticking.send();
    } else if (!doTickAudio && _tickingLoop != null) {
      _tickingLoop.stop(0);
      _tickingLoop = null;
    }
  }
  
  bool get hasAlwaysOnTopCapabilities =>
    _appDelegate.hasAlwaysOnTopCapabilities;
  bool get hasNotifyCapabilities =>
    _appDelegate.hasNotifyCapabilities;
  
  bool canDoNotifications = false;
  bool get isAuthorizedForNotifications => 
      !_appDelegate.hasNotificationCapabilities || 
      _appDelegate.isAuthorizedForNotifications;
  
  PomeranianApp.created() : super.created() {
    if (_appDelegate.hasStorageCapabilities) {
      var enableNotifications = _appDelegate.getKey("$APP_NAME.notifications");
      if (enableNotifications != null) {
        _appDelegate.tryNotifications = tryNotifications = (enableNotifications == "true");
      }
      var enableAlarmAudio = _appDelegate.getKey("$APP_NAME.doAlarmAudio");
      if (enableAlarmAudio != null) {
        doAlarmAudio = (enableAlarmAudio == "true");
      }
      var enableTickAudio = _appDelegate.getKey("$APP_NAME.doTickAudio");
      if (enableTickAudio != null) {
        doTickAudio = (enableTickAudio == "true");
      }
      if (_appDelegate.hasAlwaysOnTopCapabilities) {
        var enableAlwaysOnTop = _appDelegate.getKey("$APP_NAME.alwaysOnTop");
        if (enableAlwaysOnTop != null) {
          keepOnTop = 
              (enableAlwaysOnTop == null || enableAlwaysOnTop == "true")?2:
                (enableAlwaysOnTop == "false"?0:
                  int.parse(enableAlwaysOnTop,onError: (_) => 0));
        }
      }
      if (_appDelegate.hasNotifyCapabilities) {
        var enableNotify = _appDelegate.getKey("$APP_NAME.notify");
        if (enableNotify != null) {
          tryNotify = enableNotify == "true";
        }
      }
    }
  }
  
  @override
  ready() {
    if (_appDelegate.alarm != null) {
      clockTick = new Timer.periodic(
          const Duration(milliseconds: 500), 
          (timer) {
        if (clockTick == null) return;
        var difference = expires.difference(new DateTime.now());
        var seconds = difference.inSeconds;
        var minute = (seconds / 60).floor();
        seconds %= 60;
        timeRemaining = "$minute:${seconds.toString().padLeft(2,'0')}";
      });
      
      var duration = __appDelegate.alarm.difference(new DateTime.now());
      var title = __appDelegate.status;
      
      endOfTimer = new Timer(
          duration,
          () {
        statusReset();
        alarm(title);
      });
      var seconds = duration.inSeconds;
      var minute = (seconds / 60).floor();
      seconds %= 60;
      timeRemaining = "$minute:${seconds.toString().padLeft(2,'0')}";
      status = title;
      selected = 1;
      if (keepOnTop == 1)
        _appDelegate.keepOnTop = false;
      
      expires = __appDelegate.alarm;
      
      if (doTickAudio) {
        var request_ticking = new HttpRequest();
        request_ticking.onLoad.listen((event) {
          audioContext.decodeAudioData(request_ticking.response).then((buffer) {
            if (!doAlarmAudio) return;
             
            _tickingLoop = audioContext.createBufferSource();
            _tickingLoop.buffer = buffer;
            _tickingLoop.connectNode(audioContext.destination);
            _tickingLoop.loop = true;
            _tickingLoop.start(0);
          });
        });
        request_ticking.responseType = 'arraybuffer';
        request_ticking.open('GET', TICKING_URI);
        request_ticking.send();
      }
      
      //_appDelegate.postAlarm(expires, status);
      
      if (!isAuthorizedForNotifications && tryNotifications) {
        canDoNotifications = false;
        _appDelegate.authorizeForNotification().then((result) {
          canDoNotifications = result;
        });
      } else if (isAuthorizedForNotifications)
        canDoNotifications = true;
      selected = 1;
    } else {
      selected = 0;
      timeRemaining = "Stopped";
      status = "Pomeranian";
    }
  }
  void alarm(String title, [bool notificationOnly = false]) {
    if (canDoNotifications && tryNotifications) {
      var message = 
          (title == 'Sprint')?'Time for a break.':'Time to get back to work.';
      var notification = _appDelegate.createNotification('$title is over.',body: message,
              icon: '/icon_${_appDelegate.iconSize}.png');
      notification.onClick.listen((ev) =>
        notification.close());
    }
    if (hasNotifyCapabilities && tryNotify)
      _appDelegate.setNotify();
    if (_tickingLoop != null) {
      _tickingLoop.stop(0);
      _tickingLoop = null;
    }
    if (doAlarmAudio) {
      var request = new HttpRequest();
      request.onLoad.listen((event) {
        audioContext.decodeAudioData(request.response).then((buffer) {
          var source = audioContext.createBufferSource();
          source.buffer = buffer;
          source.connectNode(audioContext.destination);
          source.start(0);
        });
      });
      request.open('GET', RINGING_URI);
      request.responseType = 'arraybuffer';
      request.send();
    }
  }
  void statusReset() {
    if (clockTick != null)
      clockTick.cancel();
    clockTick = null; 
    if (endOfTimer != null)
      endOfTimer.cancel();
    
    _appDelegate.removeAlarm(expires);
    
    endOfTimer = null;
    expires = null;
    timeRemaining = "Stopped";
    status = "Pomeranian";
    selected = 0;
    if (keepOnTop == 1)
      _appDelegate.keepOnTop = true;
  }
  void setTimer(int timeInMinutes, String title, Event ev) {
    if (((ev.target as Node)
        .parentNode.parentNode as Element)
        .getAttribute("animate") != null)
      return;
    clockTick = new Timer.periodic(
        const Duration(milliseconds: 500), 
        (timer) {
      if (clockTick == null) return;
      var difference = expires.difference(new DateTime.now());
      var seconds = difference.inSeconds;
      var minute = (seconds / 60).floor();
      seconds %= 60;
      timeRemaining = "$minute:${seconds.toString().padLeft(2,'0')}";
    });
    var duration = new Duration(minutes: timeInMinutes);
    endOfTimer = new Timer(
        duration,
        () {
      statusReset();
      alarm(title);
    });
    timeRemaining = "$timeInMinutes:00";
    status = title;
    selected = 1;
    if (keepOnTop == 1)
      _appDelegate.keepOnTop = false;
    
    expires = new DateTime.now().add(duration);
    _appDelegate.postAlarm(expires, status);
    
    if (hasNotifyCapabilities)
      _appDelegate.clearNotify();
    
    if (!isAuthorizedForNotifications && tryNotifications) {
      canDoNotifications = false;
      _appDelegate.authorizeForNotification().then((result) {
        canDoNotifications = result;
      });
    }
    
    if (doTickAudio) {
      var buffers = new BufferLoader(this.audioContext,[WIND_UP_URI, TICKING_URI]);
      buffers.onLoaded.listen((_) {
        buffers.sources[WIND_UP_URI].connectNode(audioContext.destination);
        new Timer(new Duration(milliseconds: 
            (buffers.sources[WIND_UP_URI].buffer.duration*1000).floor()),() {
          if (!doAlarmAudio) return;
          _tickingLoop = buffers.sources[TICKING_URI];
          buffers.sources[TICKING_URI].connectNode(audioContext.destination);
          buffers.sources[TICKING_URI].loop = true;
          buffers.sources[TICKING_URI].start(0);
        });
        buffers.sources[WIND_UP_URI].start(0);
      });
      buffers.send();
    }
  }
  void pomodoroButton(Event ev) => setTimer(25,"Sprint",ev);
  void shortBreakButton(Event ev) => setTimer(5,"Break",ev);
  void longBreakButton(Event ev) => setTimer(15,"Break",ev);
  void stopButton(Event ev) {
    if (((ev.target as Node).parentNode.parentNode as Element).getAttribute("animate") != null)
      return;
    statusReset();
  }
  void changeTryNotifications(Event ev) {
    tryNotifications = ($['try-notifications-toggle'] as PaperToggleButton).checked;
  }
  void toggleTryNotifications(Event ev) {
    PaperToggleButton toggleButton = $['try-notifications-toggle'];
    if (ev.target == toggleButton) return;
    
    tryNotifications = !tryNotifications;
    if (tryNotifications && !isAuthorizedForNotifications)
      _appDelegate.authorizeForNotification().then((result) {
        canDoNotifications = result;
      });
  }
  void changeKeepOnTop(Event ev) {
    keepOnTop = ($['keep-on-top-toggle'] as PaperTristateToggleButton).state;
  }
  void toggleKeepOnTop(Event ev) {
    PaperTristateToggleButton toggleButton = $['keep-on-top-toggle'];
    if (ev.target == toggleButton) ev.stopPropagation();
    
    toggleButton.state = (toggleButton.state + 1) % 3;
  }
  void changeTryNotify(Event ev) {
    tryNotify = ($['try-notify-toggle'] as PaperToggleButton).checked;
  }
  void toggleTryNotify(Event ev) {
    PaperToggleButton toggleButton = $['try-notify-toggle'];
    if (ev.target == toggleButton) return;
      
    tryNotify = !tryNotify;
  }
  void changePlayBell(Event ev) {
    doAlarmAudio = ($['alarm-audio-toggle'] as PaperToggleButton).checked;
  }
  void togglePlayBell(Event ev) {
    PaperToggleButton toggleButton = $['alarm-audio-toggle'];
    if (ev.target == toggleButton) return;
      
    doAlarmAudio = !doAlarmAudio;
  }
  void changePlayTick(Event ev) {
    doTickAudio = ($['tick-audio-toggle'] as PaperToggleButton).checked;
  }
  void togglePlayTick(Event ev) {
    PaperToggleButton toggleButton = $['tick-audio-toggle'];
    if (ev.target == toggleButton) return;
      
    doTickAudio = !doTickAudio;
  }
}

class _HTML5AppDelegate extends AppDelegate {
  int get iconSize => 48;
  @override bool get isAuthorizedForNotifications => _isAuthorizedForNotifications;
  bool _isAuthorizedForNotifications = false;
  bool _canDoNotifications = false;
  bool _tryNotifications = true;
  bool _doAlarmAudio = false;
  
  _HTML5AppDelegate() : super();
  
  @override Future<bool> authorizeForNotification() {
    var completer = new Completer<bool>();
    if (isAuthorizedForNotifications)
      completer.complete(_canDoNotifications);
    else {
      _canDoNotifications = false;
      Notification.requestPermission().then((result) {
        if (result == 'granted') 
          completer.complete(_canDoNotifications = true);
        else
          completer.complete(_canDoNotifications = true);
        _isAuthorizedForNotifications = true;
      });
    }
    return completer.future;
  }
  
  @override AppNotification createNotification (String title, {String body, String icon}) {
    var notification =
      new Notification(title,body: body,
                  iconUrl: icon);
    return new _HTML5AppNotification(notification);
  }

  @override
  bool get hasNotificationCapabilities => true;

  @override String getKey(String key) {
    if (!window.localStorage.containsKey(key))
      return null;
    return (window.localStorage[key]);
  }

  @override void storeKey(String key, String value) {
    window.localStorage[key] = value;
  }

  @override
  bool get hasStorageCapabilities => true;

  @override
  DateTime get alarm => null;

  @override
  void postAlarm(DateTime alarm, String status) {
    // Do nothing
  }

  @override
  void removeAlarm(DateTime alarm) {
    // Do nothing
  }

  @override
  bool get tryNotifications => _tryNotifications;

  @override
  void set tryNotifications(bool value) {
    _tryNotifications = value;
  }
  
  @override String get status => '';

  @override
  bool get hasAlwaysOnTopCapabilities => 
      false;

  @override
  void set keepOnTop(bool value) {
    throw new UnsupportedError("set keepOnTop not supported.");
  }

  @override
  bool get keepOnTop => 
      throw new UnsupportedError("get keepOnTop not supported.");
  
  @override
  bool get hasNotifyCapabilities => false;

  @override
  void clearNotify() =>
    throw new UnsupportedError("clearNotify not supported.");

  @override
  void setNotify() =>
    throw new UnsupportedError("setNotify not supported.");

  @override
  bool get doAlarmAudio => _doAlarmAudio;

  @override
  void set doAlarmAudio(bool value) {
    _doAlarmAudio = value;
  }
}
class _HTML5AppNotification extends AppNotification {
  final Notification _delegate;
  
  _HTML5AppNotification(Notification this._delegate) : super();

  @override void close() =>
    _delegate.close();
  
  @override Stream get onClick => _delegate.onClick;
}
class BufferLoader {
  final AudioContext audioContext;
  final List<String> _urlList;
  final Map<String,AudioBufferSourceNode> sources = new Map();
  int _count;

  final StreamController _onLoaded = new StreamController();
  Stream get onLoaded => _onLoaded.stream;
  
  final StreamController _onError = new StreamController();
  Stream get onError => _onError.stream;
  
  BufferLoader(AudioContext this.audioContext, List<String> urlList) :
    _count = urlList.length,
    _urlList = new List.from(urlList);
  void send() {
    for (var url in _urlList) {
      var request = new HttpRequest();
      request.onLoad.listen((onData) {
        audioContext.decodeAudioData(request.response).then((buffer) {
          var source = audioContext.createBufferSource();
          source.buffer = buffer;
          sources[url] = source;
          if (--_count == 0) {
            _onLoaded.add(null);
          }
        },
        onError: (error) {
          _onError.add(error);
        });
      });
      request.onError.listen((progress) {
        _onError.add(progress);
      });
      request.responseType = 'arraybuffer';
      request.open('GET', url);
      request.send();
    }
  }
  
}
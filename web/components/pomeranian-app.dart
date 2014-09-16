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
  
  @observable bool active;
  void activeChanged(bool oldValue) {
    animating = true;
    new Timer(new Duration(seconds: 1), () {
      animating = false;
    });
  }
  @observable bool animating;
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
          if (!doTickAudio) return;
         
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
  bool get hasNotificationCapabilities =>
    _appDelegate.hasNotificationCapabilities;
  
  bool canDoNotifications = false;
  bool get isAuthorizedForNotifications => 
      !_appDelegate.hasNotificationCapabilities || 
      _appDelegate.isAuthorizedForNotifications;
  
  PomeranianApp.created() : super.created() {
    if (_appDelegate.hasStorageCapabilities) {
      if (hasNotificationCapabilities) {
        var enableNotifications = _appDelegate.getKey("$APP_NAME.notifications");
        if (enableNotifications != null) {
          _appDelegate.tryNotifications = tryNotifications = (enableNotifications == "true");
        }
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
      active = true;
      if (keepOnTop == 1)
        _appDelegate.keepOnTop = false;
      
      expires = __appDelegate.alarm;
      
      if (doTickAudio) {
        var request_ticking = new HttpRequest();
        request_ticking.onLoad.listen((event) {
          audioContext.decodeAudioData(request_ticking.response).then((buffer) {
            if (!doAlarmAudio || expires == null) return;
             
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
      active = true;
    } else {
      active = false;
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
    active = false;
    if (keepOnTop == 1)
      _appDelegate.keepOnTop = true;
    if (_tickingLoop != null) {
      _tickingLoop.stop(0);
      _tickingLoop = null;
    }
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
    active = true;
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
          if (!doTickAudio || expires == null) return;
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
    if (ev.target == toggleButton) {
      ev.stopPropagation();
      return;
    }
    
    toggleButton.state = (toggleButton.state + 1) % 3;
  }
  void changeTryNotify(Event ev) {
    tryNotify = ($['try-notify-toggle'] as PaperToggleButton).checked;
  }
  void toggleTryNotify(Event ev) {
    PaperToggleButton toggleButton = $['try-notify-toggle'];
    if (ev.target == toggleButton) {
      ev.stopPropagation();
      return;
    }
      
    tryNotify = !tryNotify;
  }
  void changePlayBell(Event ev) {
    doAlarmAudio = ($['alarm-audio-toggle'] as PaperToggleButton).checked;
  }
  void togglePlayBell(Event ev) {
    PaperToggleButton toggleButton = $['alarm-audio-toggle'];
    if (ev.target == toggleButton) {
      ev.stopPropagation();
      return;
    }
      
    doAlarmAudio = !doAlarmAudio;
  }
  void changePlayTick(Event ev) {
    doTickAudio = ($['tick-audio-toggle'] as PaperToggleButton).checked;
  }
  void togglePlayTick(Event ev) {
    PaperToggleButton toggleButton = $['tick-audio-toggle'];
    if (ev.target == toggleButton) {
      ev.stopPropagation();
      return;
    }
      
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
  static const String MOBILE_TEST_STRING = r'''(android|bb\d+|meego).+mobile|avantgo|bada\/|blackberry|blazer|compal|elaine|fennec|hiptop|iemobile|ip(hone|od)|iris|kindle|lge |maemo|midp|mmp|mobile.+firefox|netfront|opera m(ob|in)i|palm( os)?|phone|p(ixi|re)\/|plucker|pocket|psp|series(4|6)0|symbian|treo|up\.(browser|link)|vodafone|wap|windows (ce|phone)|xda|xiino/i.test(a)||/1207|6310|6590|3gso|4thp|50[1-6]i|770s|802s|a wa|abac|ac(er|oo|s\-)|ai(ko|rn)|al(av|ca|co)|amoi|an(ex|ny|yw)|aptu|ar(ch|go)|as(te|us)|attw|au(di|\-m|r |s )|avan|be(ck|ll|nq)|bi(lb|rd)|bl(ac|az)|br(e|v)w|bumb|bw\-(n|u)|c55\/|capi|ccwa|cdm\-|cell|chtm|cldc|cmd\-|co(mp|nd)|craw|da(it|ll|ng)|dbte|dc\-s|devi|dica|dmob|do(c|p)o|ds(12|\-d)|el(49|ai)|em(l2|ul)|er(ic|k0)|esl8|ez([4-7]0|os|wa|ze)|fetc|fly(\-|_)|g1 u|g560|gene|gf\-5|g\-mo|go(\.w|od)|gr(ad|un)|haie|hcit|hd\-(m|p|t)|hei\-|hi(pt|ta)|hp( i|ip)|hs\-c|ht(c(\-| |_|a|g|p|s|t)|tp)|hu(aw|tc)|i\-(20|go|ma)|i230|iac( |\-|\/)|ibro|idea|ig01|ikom|im1k|inno|ipaq|iris|ja(t|v)a|jbro|jemu|jigs|kddi|keji|kgt( |\/)|klon|kpt |kwc\-|kyo(c|k)|le(no|xi)|lg( g|\/(k|l|u)|50|54|\-[a-w])|libw|lynx|m1\-w|m3ga|m50\/|ma(te|ui|xo)|mc(01|21|ca)|m\-cr|me(rc|ri)|mi(o8|oa|ts)|mmef|mo(01|02|bi|de|do|t(\-| |o|v)|zz)|mt(50|p1|v )|mwbp|mywa|n10[0-2]|n20[2-3]|n30(0|2)|n50(0|2|5)|n7(0(0|1)|10)|ne((c|m)\-|on|tf|wf|wg|wt)|nok(6|i)|nzph|o2im|op(ti|wv)|oran|owg1|p800|pan(a|d|t)|pdxg|pg(13|\-([1-8]|c))|phil|pire|pl(ay|uc)|pn\-2|po(ck|rt|se)|prox|psio|pt\-g|qa\-a|qc(07|12|21|32|60|\-[2-7]|i\-)|qtek|r380|r600|raks|rim9|ro(ve|zo)|s55\/|sa(ge|ma|mm|ms|ny|va)|sc(01|h\-|oo|p\-)|sdk\/|se(c(\-|0|1)|47|mc|nd|ri)|sgh\-|shar|sie(\-|m)|sk\-0|sl(45|id)|sm(al|ar|b3|it|t5)|so(ft|ny)|sp(01|h\-|v\-|v )|sy(01|mb)|t2(18|50)|t6(00|10|18)|ta(gt|lk)|tcl\-|tdg\-|tel(i|m)|tim\-|t\-mo|to(pl|sh)|ts(70|m\-|m3|m5)|tx\-9|up(\.b|g1|si)|utst|v400|v750|veri|vi(rg|te)|vk(40|5[0-3]|\-v)|vm40|voda|vulc|vx(52|53|60|61|70|80|81|83|85|98)|w3c(\-| )|webc|whit|wi(g |nc|nw)|wmlb|wonu|x700|yas\-|your|zeto|zte\-'''; 
  
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
  
  bool _isMobile;
  bool get isMobile {
    if (_isMobile == null) {
      var regex = new RegExp(MOBILE_TEST_STRING, caseSensitive: false);
      String agentString;
      if (window.navigator == null || 
          (window.navigator.userAgent == null &&
           window.navigator.vendor == null)) {
        //agentString = window.opera;
        agentString = '';
      } else if (window.navigator.userAgent == null) {
        agentString = window.navigator.vendor;
      } else {
        agentString = window.navigator.userAgent;
      }
      _isMobile = regex.hasMatch(agentString.substring(0,4));
    }
    return _isMobile;
  }

  @override
  bool get hasNotificationCapabilities => 
    context.hasProperty('Notification');

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

  @override
  bool get hasTickCapabilities => true;
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
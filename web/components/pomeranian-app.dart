import 'package:polymer/polymer.dart';
import 'dart:html' hide Notification;
import 'dart:async';
import 'dart:js';
import 'package:paper_elements/paper_toggle_button.dart';

import '../lib/app_services.dart';
import '../lib/notification_patch.dart';
import 'paper-tristate-toggle-button.dart';

@CustomTag('pomeranian-app')
class PomeranianApp extends PolymerElement with Observable {
  static const String APP_NAME = "pomeranian_chrome";
  
  @observable int selected;
  @observable String timeRemaining;
  @observable String status;
  
  DateTime expires = null;
  
  Timer clockTick = null;
  Timer endOfTimer = null;
  
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
  
  
  bool get hasAlwaysOnTopCapabilities =>
    _appDelegate.hasAlwaysOnTopCapabilities;
  
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
      if (_appDelegate.hasAlwaysOnTopCapabilities) {
        var enableAlwaysOnTop = _appDelegate.getKey("$APP_NAME.alwaysOnTop");
        if (enableAlwaysOnTop != null) {
          keepOnTop = 
              (enableAlwaysOnTop == null || enableAlwaysOnTop == "true")?2:
                (enableAlwaysOnTop == "false"?0:
                  int.parse(enableAlwaysOnTop,onError: (_) => 0));
        }
      }
    }
  }
  
  @override
  ready() {
    if (__appDelegate.alarm != null) {
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
    
    if (!isAuthorizedForNotifications && tryNotifications) {
      canDoNotifications = false;
      _appDelegate.authorizeForNotification().then((result) {
        canDoNotifications = result;
      });
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
    if (ev.target == toggleButton) ev.stopPropagation();
    
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
}



class _HTML5AppDelegate extends AppDelegate {
  int get iconSize => 48;
  @override bool get isAuthorizedForNotifications => _isAuthorizedForNotifications;
  bool _isAuthorizedForNotifications = false;
  bool _canDoNotifications = false;
  bool _tryNotifications = true;
  
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

  // TODO: implement tryNotifications
  @override
  bool get tryNotifications => _tryNotifications;

  @override
  void set tryNotifications(bool value) {
    _tryNotifications = value;
  }
  
  @override String get status => '';

  // TODO: implement hasAlwaysOnTopCapabilities
  @override
  bool get hasAlwaysOnTopCapabilities => 
      false;

  @override
  void set keepOnTop(bool value) {
  }

  @override
  bool get keepOnTop => false;
}
class _HTML5AppNotification extends AppNotification {
  final Notification _delegate;
  
  _HTML5AppNotification(Notification this._delegate) : super();

  @override void close() =>
    _delegate.close();
  
  @override Stream get onClick => _delegate.onClick;
  
}
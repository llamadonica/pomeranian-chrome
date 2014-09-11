import 'package:polymer/polymer.dart';
import 'dart:html' hide Notification;
import 'dart:async';
import 'dart:js';
import 'package:paper_elements/paper_toggle_button.dart';

import '../lib/app_services.dart';
import '../lib/notification_patch.dart';

@CustomTag('pomeranian-app')
class PomeranianApp extends PolymerElement {
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
  
  bool get tryNotifications => _appDelegate.tryNotifications;
  void set tryNotifications(bool value) {
    _appDelegate.tryNotifications = value;
  }
  
  bool canDoNotifications = false;
  bool get isAuthorizedForNotifications => 
      !_appDelegate.hasNotificationCapabilities || 
      _appDelegate.isAuthorizedForNotifications;
  
  PomeranianApp.created() : super.created() {
    if (_appDelegate.hasStorageCapabilities) {
      var enableNotifications = _appDelegate.getKey("$APP_NAME.notifications");
      if (enableNotifications != null) {
        tryNotifications = (enableNotifications == "true");
      }
    }
  }
  
  @override
  ready() {
    if (__appDelegate.alarms.isNotEmpty) {
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
      
      var duration = __appDelegate.alarms.first.difference(new DateTime.now());
      
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
      
      expires = __appDelegate.alarms.first;
      //_appDelegate.postAlarm(expires, status);
      
      if (!isAuthorizedForNotifications && tryNotifications) {
        canDoNotifications = false;
        _appDelegate.authorizeForNotification().then((result) {
          canDoNotifications = result;
        });
      } else if (isAuthorizedForNotifications)
        canDoNotifications = true;
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
  void shortBreakButton(Event ev) => setTimer(1,"Break",ev);
  void longBreakButton(Event ev) => setTimer(15,"Break",ev);
  void stopButton(Event ev) {
    if (((ev.target as Node).parentNode.parentNode as Element).getAttribute("animate") != null)
      return;
    statusReset();
  }
  void changeTryNotifications(Event ev) {
    tryNotifications = ($['try-notifications-toggle'] as PaperToggleButton).checked;
    if (tryNotifications && !isAuthorizedForNotifications)
      _appDelegate.authorizeForNotification().then((result) {
        canDoNotifications = result;
      });
    if (_appDelegate.hasStorageCapabilities)
      _appDelegate.storeKey(
          "$APP_NAME.notifications",
          tryNotifications.toString());
  }
  void toggleTryNotifications(Event ev) {
    PaperToggleButton toggleButton = $['try-notifications-toggle'];
    if (ev.target == toggleButton) return;
    toggleButton.checked = !toggleButton.checked;
    changeTryNotifications(ev);
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
  Iterable<DateTime> get alarms => [];

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
}
class _HTML5AppNotification extends AppNotification {
  final Notification _delegate;
  
  _HTML5AppNotification(Notification this._delegate) : super();

  @override void close() =>
    _delegate.close();
  
  @override Stream get onClick => _delegate.onClick;
  
}
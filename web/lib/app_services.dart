library pomeranian.app_services;

import 'dart:async';
import 'dart:js';

import 'notification_patch.dart';

abstract class AppNotification {
  Stream get onClick;
  void close();
  AppNotification();
}
abstract class AppDelegate {
  int get iconSize;
  
  bool get hasNotificationCapabilities;
  bool get hasStorageCapabilities;
  bool get hasAlwaysOnTopCapabilities;
  bool get hasNotifyCapabilities;
  bool get hasTickCapabilities;
  
  bool get tryNotifications;
  void set tryNotifications(bool value);

  bool get keepOnTop;
  void set keepOnTop(bool value);
  
  bool get doAlarmAudio;
  void set doAlarmAudio(bool value);
  
  void setNotify();
  void clearNotify();
  
  bool get isAuthorizedForNotifications;
  Future<bool> authorizeForNotification();
  AppNotification createNotification (String title, {String body, String icon});
  
  DateTime get alarm;
  String get status;
  
  void postAlarm(DateTime alarm, String status);
  void removeAlarm();
  
  void storeKey(String key, String value);
  String getKey(String key);
  
  AppDelegate();
}
class JsAppDelegate extends AppDelegate {
  final JsObject _proxy;
  
  JsAppDelegate(JsObject this._proxy) : super();
  
  @override
  String get status => 
      (_proxy['alarm'] == null)?
          null:
          _proxy['alarm']['status'];   
  
  @override
  DateTime get alarm => 
    (_proxy['alarm'] == null)?
        null:
        new DateTime.fromMillisecondsSinceEpoch(_proxy['alarm']['time']);

  @override
  Future<bool> authorizeForNotification() {
    var completer = new Completer<bool>();
    _proxy.callMethod('authorizeForNotification',
        [new JsFunction.withThis((_this,result) {
          completer.complete(result);
        })]);
    return completer.future;
  }

  @override
  AppNotification createNotification(String title, {String body, String icon}) {
    var parsedOptions = {};
    if (body != null) parsedOptions['body'] = body;
    if (icon != null) parsedOptions['icon'] = icon;
    return new _ChromeNotification(
        new Notification.fromProxy(
            _proxy.callMethod('createNotification',
            [title,new JsObject.jsify(parsedOptions)])));
  }

  @override
  String getKey(String key) =>
    _proxy.callMethod('getKey',[key]);

  @override
  bool get hasNotificationCapabilities => 
      _proxy.callMethod('getHasNotificationCapabilities',[]);

  @override
  bool get hasStorageCapabilities => 
      _proxy.callMethod('getHasStorageCapabilities',[]);

  @override
  bool get isAuthorizedForNotifications => 
      _proxy.callMethod('getIsAuthorizedForNotifications',[]);

  @override
  void postAlarm(DateTime alarm, String status) =>
      _proxy.callMethod('postAlarm',[alarm.millisecondsSinceEpoch, status]);

  @override
  void removeAlarm() =>
    _proxy.callMethod('removeAlarm',[]);

  @override
  void storeKey(String key, String value) =>
      _proxy.callMethod('storeKey',[key, value]);

  @override
  bool get tryNotifications => 
      _proxy.callMethod('getTryNotifications',[]);

  @override
  void set tryNotifications(bool value) =>
    _proxy.callMethod('setTryNotifications',[value]);

  // TODO: implement iconSize
  @override
  int get iconSize => 
      _proxy.callMethod('getIconSize',[]);

  // TODO: implement hasAlwaysOnTopCapabilities
  @override
  bool get hasAlwaysOnTopCapabilities => 
      _proxy.callMethod('getHasAlwaysOnTopCapabilities',[]);

  @override
  void set keepOnTop(bool value) =>
    _proxy.callMethod('setKeepOnTop',[value]);

  @override
  bool get keepOnTop =>
    _proxy.callMethod('getKeepOnTop',[]);

  @override
  bool get hasNotifyCapabilities => 
      _proxy.callMethod('getHasNotifyCapabilities',[]);

  @override
  void clearNotify()  => 
      _proxy.callMethod('clearNotify',[]);

  @override
  void setNotify() => 
      _proxy.callMethod('setNotify',[]);
  

  @override
  void set doAlarmAudio(bool value) =>
    _proxy.callMethod('setDoAlarmAudio',[value]);

  @override
  bool get doAlarmAudio=>
    _proxy.callMethod('getDoAlarmAudio',[]);

  // TODO: implement hasTickCapabilities
  @override
  bool get hasTickCapabilities => 
      _proxy.callMethod('getHasTickCapabilities',[]);
}

class _ChromeNotification extends AppNotification {
  final Notification _delegate;
  
  _ChromeNotification(Notification this._delegate) : super();

  @override void close() =>
    _delegate.close();
  
  @override Stream get onClick => _delegate.onClick;
}

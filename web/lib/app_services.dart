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
  
  bool get tryNotifications;
  void set tryNotifications(bool value);
  
  bool get isAuthorizedForNotifications;
  Future<bool> authorizeForNotification();
  AppNotification createNotification (String title, {String body, String icon});
  
  Iterable<DateTime> get alarms;
  String get status;
  
  void postAlarm(DateTime alarm, String status);
  void removeAlarm(DateTime alarm);
  
  void storeKey(String key, String value);
  String getKey(String key);
  
  AppDelegate();
  //factory AppDelegate() => new _HTML5AppDelegate();
}
class JsAppDelegate extends AppDelegate {
  final JsObject _proxy;
  
  JsAppDelegate(JsObject this._proxy) : super();
  
  @override
  String get status => _proxy['_status'];      
  
  @override
  Iterable<DateTime> get alarms => 
    new Iterable.generate(
        _proxy['alarms']['length'],
        (n) => new DateTime.fromMillisecondsSinceEpoch(_proxy['alarms'][n]));

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

  // TODO: implement hasNotificationCapabilities
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
  void removeAlarm(DateTime alarm) =>
    _proxy.callMethod('removeAlarm',[alarm.millisecondsSinceEpoch]);

  @override
  void storeKey(String key, String value) =>
      _proxy.callMethod('storeKey',[key, value]);

  // TODO: implement tryNotifications
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
}

class _ChromeNotification extends AppNotification {
  final Notification _delegate;
  
  _ChromeNotification(Notification this._delegate) : super();

  @override void close() =>
    _delegate.close();
  
  @override Stream get onClick => _delegate.onClick;
}

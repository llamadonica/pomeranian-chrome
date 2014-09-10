library pomeranian.app_services;

import 'dart:async';

abstract class AppNotification {
  Stream get onClick;
  void close();
  AppNotification();
}
abstract class AppDelegate {
  bool get hasNotificationCapabilities;
  bool get hasStorageCapabilities;
  
  bool get isAuthorizedForNotifications;
  Future<bool> authorizeForNotification();
  AppNotification createNotification (String title, {String body, String icon});
  
  void storeKey(String key, String value);
  String getKey(String key);
  
  AppDelegate();
  //factory AppDelegate() => new _HTML5AppDelegate();
}
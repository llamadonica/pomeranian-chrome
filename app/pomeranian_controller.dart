/**
 * <pomeranian_controller.dart>
 * 
 * Copyright (c) 2014 "Adam Stark"
 * 
 * This file is part of Pomeranian Chrome.
 * 
 * Pomeranian Chrome is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 * 
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 * 
 */

library pomeranian_controller;

import 'dart:async'
  show StreamController, Stream;
import 'package:chrome/chrome_app.dart' as chrome
  show notifications, alarms, NotificationOptions, TemplateType, 
  AlarmCreateInfo, Alarm;
import 'pomeranian_notification_options.dart';

class Controller {
  StreamController<String> _onRaise = new StreamController();
  Stream<String> get onRaise => _onRaise.stream;
  StreamController _onAlarm = new StreamController();
  Stream get onAlarm => _onAlarm.stream;
  DateTime timeout = null;
  bool get stopped => timeout == null;
  Controller([chrome.Alarm alarm = null]) {
    if (alarm != null) {
      timeout = new DateTime.fromMillisecondsSinceEpoch(alarm.scheduledTime.round());
    }
    chrome.alarms.onAlarm.listen(
      (alarm) {
        chrome.notifications.create(
            "_pomerananianNotification",
            PomeranianNotificationOptions.notificationOptions(alarm.name));
        timeout = null;
        _onAlarm.add(null);
    });
    chrome.notifications.onClicked.listen((notification) {
      assert(notification == "_pomerananianNotification");
      this._onRaise.add(notification);
      chrome.notifications.clear(notification);
    });
  }
  void setAlarm (int delayInMinutes, {String name:"Pomodoro"}) {
    chrome.alarms.clearAll();
    chrome.alarms.create(
        new chrome.AlarmCreateInfo(delayInMinutes:delayInMinutes), name);
    timeout = (new DateTime.now()).add(new Duration(minutes:delayInMinutes));
  }
  void cancelAlarm () {
    chrome.alarms.clearAll();
    timeout = null;
  }
}
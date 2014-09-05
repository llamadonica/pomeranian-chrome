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

import 'dart:html'
  show Event;
import 'dart:async'
  show StreamController, Stream, Future;
import 'package:chrome/chrome_app.dart' as chrome
  show notifications, alarms, NotificationOptions, TemplateType, 
  AlarmCreateInfo, Alarm, storage;
import 'pomeranian_notification_options.dart';

class Controller {
  StreamController<String> _onRaise = new StreamController();
  Stream<String> get onRaise => _onRaise.stream;
  StreamController _onAlarm = new StreamController();
  Stream get onAlarm => _onAlarm.stream;
  DateTime alarmTimeout = null;
  String alarmName = null;
  bool get stopped => alarmTimeout == null;
  Controller([chrome.Alarm alarm = null]) {
    if (alarm != null) {
      alarmTimeout = new DateTime.fromMillisecondsSinceEpoch(alarm.scheduledTime.round());
      alarmName = alarm.name;
    }
    chrome.alarms.onAlarm.listen(
      (alarm) {
        chrome.notifications.create(
            "_pomerananianNotification",
            PomeranianNotificationOptions.notificationOptions(alarm.name));
        alarmTimeout = null;
        _onAlarm.add(null);
    });
    chrome.notifications.onClicked.listen((notification) {
      assert(notification == "_pomerananianNotification");
      this._onRaise.add(notification);
      chrome.notifications.clear(notification);
    });
  }
  void setAlarm (int delayInMinutes, Event event, {String name:"Pomodoro"}) {
    chrome.alarms.clearAll();
    chrome.alarms.create(
        new chrome.AlarmCreateInfo(delayInMinutes:delayInMinutes), name);
    alarmTimeout = (new DateTime.fromMillisecondsSinceEpoch(event.timeStamp)).add(new Duration(minutes:delayInMinutes));
    alarmName = name;
    _setWasRunningWhenClosedInStorage(true);
  }
  void cancelAlarm () {
    chrome.alarms.clearAll();
    alarmTimeout = null;
    alarmName = null;
    _setWasRunningWhenClosedInStorage(false);
  }
  int _lastAction = 0;
  int get lastAction => _lastAction;
  set lastAction (int value) {
    _lastAction = value;
    _setLastActionInStorage(value);
  }
  Future _setLastActionInStorage(int value) =>
        chrome.storage.local.set({'lastAction':value});
  Future _setWasRunningWhenClosedInStorage(bool value) =>
          chrome.storage.local.set({'wasRunningWhenClosed':value});
  Future<bool> syncLocalStorage() => 
        chrome.storage.local.get({'lastAction':0,'wasRunningWhenClosed':false})
            .then((map) {
              _lastAction = map['lastAction'];
              return map['wasRunningWhenClosed'];
            });
}
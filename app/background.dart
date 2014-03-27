/**
 * <background.dart>
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

import 'dart:html';
import 'dart:async';
import 'dart:js';
import 'package:chrome/chrome_app.dart' as chrome;
import 'pomeranian_notification_options.dart';

void main () {
  windowIsActive = false;
  chrome.app.runtime.onLaunched.listen(onLaunch);
  chrome.alarms.onAlarm.listen(onAlarm);
  chrome.notifications.onClicked.listen(onNotificationClicked);
}

void onAlarm (chrome.Alarm alarm) {
  if (windowIsActive) return;
  chrome.notifications.create(
      "_pomerananianNotification",
      PomeranianNotificationOptions.notificationOptions(alarm.name));
}
void onNotificationClicked (String notification) {
  if (windowIsActive) return;
  assert(notification == "_pomerananianNotification");
  onLaunch();
  chrome.notifications.clear(notification);
}

void onLaunch ([chrome.LaunchData launchData = null]) {
    //TODO: Use chrome APIs to discover OS.
    bool isWindows = ((new RegExp(r'Windows')).hasMatch(window.navigator.userAgent));
    String frame = isWindows?'chrome':'chrome';
    chrome.WindowType type = isWindows?chrome.WindowType.SHELL:chrome.WindowType.PANEL;
    
    chrome.alarms.getAll().then((alarms) {
      chrome.Alarm notificationAlarm = null;
      if (!alarms.isEmpty)
        notificationAlarm = alarms[0];
      chrome.app.window.create(
        'pomeranianchrome.html',
        new chrome.CreateWindowOptions(
            id:'_mainWindow',
            frame:frame,
            type:type,
            defaultWidth:560,
            defaultHeight:240,
            minWidth: 400,
            minHeight: 220,
            alwaysOnTop: true
            )).then((appWindow) {
              windowIsActive = true;
              //TODO: This needs to be more thoroughly validated, since I'm not
              //sure whether it's possible to miss an alarm here.
              appWindow.jsProxy['alarm'] = notificationAlarm;
              appWindow.onClosed.listen((_) {
                windowIsActive = false;
              });
            });
    });
  }

bool get windowIsActive => context['windowIsActive'];
set windowIsActive (bool value) {
  context['windowIsActive'] = value;
}

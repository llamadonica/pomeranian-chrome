/**
 * <pomeranian_notification_options.dart>
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

import 'package:chrome/chrome_app.dart' as chrome;

class PomeranianNotificationOptions {
  static Map<String,chrome.NotificationOptions> _notificationOptions = new Map();
  static chrome.NotificationOptions notificationOptions (String instanceName) {
    chrome.NotificationOptions notificationOption;
    if ((notificationOption = _notificationOptions[instanceName]) == null) {
      String message;
      String title;
      if (instanceName == "Work") {
        title = "Pomodoro sprint is up";
        message = "Time for a break.";
      } else {
        title = "Break is up";
        message = "Time to work.";
      }
      notificationOption = 
        new chrome.NotificationOptions(title:title,
                                       message:message,
                                       type:chrome.TemplateType.BASIC,
                                       iconUrl:"icon_128.png");
      _notificationOptions[instanceName] = notificationOption;
    }
    return notificationOption;
  }
}
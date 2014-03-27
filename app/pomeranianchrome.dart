/**
 * <pomeranianchrome.dart>
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

library pomeranian;

import 'pomeranian_controller.dart' as pomeranian;
import 'pomeranian_view.dart' as pomeranian;

import 'package:chrome/chrome_app.dart' as chrome;
import 'dart:html';

/**
 * For non-trivial uses of the Chrome apps API, please see the
 * [chrome](http://pub.dartlang.org/packages/chrome).
 * 
 * * http://developer.chrome.com/apps/api_index.html
 */
void main() {
  //TODO: I'm not sure if alarm should be persisted in this way. It seems
  //like I'm mixing concerns.
  new pomeranian.View(
          new pomeranian.Controller(currentAlarm),
          chrome.app.window.current(),
          window,
          currentAlarm);
}

chrome.Alarm get currentAlarm => chrome.app.window.current().jsProxy['alarm'];
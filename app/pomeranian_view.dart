/**
 * <pomeranian_view.dart>
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

library pomeranian_view;

import 'dart:html';
import 'dart:async';
import 'package:chrome/chrome_app.dart' as chrome;
import 'pomeranian_controller.dart' as pomeranian;
import 'pomeranian_window_animation.dart' as pomeranian;


typedef void ClickHandlerFunction(Event event);

class View {
  final chrome.AppWindow _window;
  final Window _jsWindow;
  final pomeranian.Controller _app;
    
  pomeranian.Button _focusButton = pomeranian.Button.POMODORO;
  int _buttonsContainerWidth = 530;
  
  int _lastActionSync = 0;
  int get _lastAction => _lastActionSync;
  set _lastAction (int value) {
    _lastActionSync = value;
    _setLastAction(value);
  }
  
  Future<bool> _getLocalStorage() => 
      chrome.storage.local.get({'lastAction':0,'wasRunningWhenClosed':false})
          .then((map) {
            _lastActionSync = map['lastAction'];
            return map['wasRunningWhenClosed'];
          });
  
  Future _setLastAction(int value) =>
      chrome.storage.local.set({'lastAction':value});
  Future _setWasRunningWhenClosed(bool value) =>
        chrome.storage.local.set({'wasRunningWhenClosed':value});
  
  pomeranian.Button _lastButton = pomeranian.Button.POMODORO;
  String currentlyHighlighted = "#pomodoro_button_id";
  
  //TODO: This could probably be done as a simple property instead.
  pomeranian.Button get nextButton {
    if (_lastAction > 7) _lastAction %= 8;
    switch (_lastAction) {
      case 0:
      case 2:
      case 4:
      case 6:
        return pomeranian.Button.POMODORO;
      case 1:
      case 3:
      case 5:
        return pomeranian.Button.SHORT_BREAK;
      default:
        return pomeranian.Button.LONG_BREAK;
    }
  }
  
  pomeranian.Pointer<pomeranian.ViewAnimation> currentAnimation = new pomeranian.Pointer();
  
  View(pomeranian.Controller this._app, chrome.AppWindow this._window, Window this._jsWindow,[chrome.Alarm alarm = null]) {
    bool isRunning = false;
    if (alarm != null) {
      presetAlarmState(alarm);
      _setWasRunningWhenClosed(isRunning = true);
    }
    this._getLocalStorage().then((_) {
      highlightNextButton();
    });
    
    _app.onRaise.listen((_) => _window.focus());
    _app.onAlarm.listen((_) => toStopState());
    _jsWindow.onResize.listen(this.resizeWindow);
    _jsWindow.onLoad.listen(this.resizeWindow);
    absolutizeElements(
      _jsWindow.document.querySelectorAll("#buttons_container_id button"));
    _jsWindow
      .document
      .querySelector("#timer_text_id")
      .text = "Stopped";
    _jsWindow.document.querySelector("#pomodoro_button_id").onClick.listen(clickAction(pomeranian.Button.POMODORO));
    _jsWindow.document.querySelector("#long_button_id").onClick.listen(clickAction(pomeranian.Button.LONG_BREAK));
    _jsWindow.document.querySelector("#short_button_id").onClick.listen(clickAction(pomeranian.Button.SHORT_BREAK));
    _jsWindow.document.querySelector("#stop_button_id").onClick.listen(clickStop);
    _jsWindow.onKeyPress.listen((KeyboardEvent keyEvent) {
      if (keyEvent.keyCode != 13) return;
      keyEvent.preventDefault();
      keyEvent.stopPropagation();
      if (_app.stopped) {
        clickAction(nextButton)(keyEvent);
      } else {
        clickStop(keyEvent);
      }
    });
  }
  
  presetAlarmState(chrome.Alarm alarm) {
    _jsWindow.document.querySelector("#stop_button_id").style.display = "inline-block";
    _jsWindow.document.querySelector("#pomodoro_button_id").style.display=
        _jsWindow.document.querySelector("#short_button_id").style.display =
        _jsWindow.document.querySelector("#long_button_id").style.display =
        "none";
    _jsWindow.document.querySelector("#title_id").text = alarm.name;
    timerLoop();
  }
  
  ClickHandlerFunction clickAction(pomeranian.Button button) => ((Event event) {
    event.preventDefault();
    var nextAnimation;
    if (this.currentAnimation.data != null &&
        this.currentAnimation.data is pomeranian.TransitionButtonsAnimation) {
      pomeranian.TransitionButtonsAnimation prevAnimation = this.currentAnimation.data; 
      nextAnimation = 
         new pomeranian.TransitionButtonsAnimation(
           _jsWindow,
           currentAnimation,
           defaultButtonsContainerWidth: _buttonsContainerWidth,
           focusButton: button,
           isGoingToStop: true,
           startPosition: (time) => 1-prevAnimation.positionAtTime(time));
    } else {
      nextAnimation = 
         new pomeranian.TransitionButtonsAnimation(
           _jsWindow,
           currentAnimation,
           defaultButtonsContainerWidth: _buttonsContainerWidth,
           focusButton: button,
           isGoingToStop: true);
    }
    _lastButton = button;
    if (button == nextButton) {
      _lastAction++;
    } else if (button == pomeranian.Button.POMODORO) {
      _lastAction = 1;
    } else if (button == pomeranian.Button.SHORT_BREAK) {
      _lastAction = 2;
    } else {
      _lastAction = 0;
    }
    chrome.notifications.clear("_pomerananianNotification");
    animateNow().then(nextAnimation.drawFirstFrame);
    setTimer(button);
  });
  
  void setTimer (pomeranian.Button button) {
    int delayInMinutes;
    String eventName;
    if (button == pomeranian.Button.POMODORO) {
      delayInMinutes = 25;
      eventName = "Work";
    } else if (button == pomeranian.Button.SHORT_BREAK) {
      delayInMinutes = 5;
      eventName = "Short Break";
    } else {
      delayInMinutes = 15;
      eventName = "Long Break";
    }
    _jsWindow.document.querySelector("#title_id").text = eventName;
    _setWasRunningWhenClosed(true);
    _app.setAlarm(delayInMinutes, name: eventName);
    timerLoop();
  }
  
  int previousTime = 0;
  
  void timerLoop () {
    if (_app.stopped) return;
    var newTime = _app.timeout.difference(new DateTime.now()).inSeconds;
    if (newTime != previousTime) {
      previousTime = newTime;
      _jsWindow.animationFrame.then(redrawClock);
    }
    new Timer(new Duration(milliseconds:100), timerLoop);
  }
  
  void redrawClock (double clock) {
    int previousMinutes = previousTime ~/ 60;
    int previousSeconds = previousTime % 60;
    String secondsText = ((previousSeconds < 10)?'0':'') + previousSeconds.toString();
    _jsWindow.document.querySelector("#timer_text_id")
          .text = previousMinutes.toString() + ':' + secondsText;
  }
  void highlightNextButton() {
    String nextHighlight;
    if (nextButton == pomeranian.Button.POMODORO) {
        nextHighlight = "#pomodoro_button_id";
    } else if (nextButton == pomeranian.Button.SHORT_BREAK) {
        nextHighlight = "#short_button_id";
    } else {
      nextHighlight = "#long_button_id";
    }
    
    _jsWindow.document.querySelector(currentlyHighlighted).classes.remove('focused');
    _jsWindow.document.querySelector(nextHighlight).classes.add('focused');
    currentlyHighlighted = nextHighlight;
  }
  void toStopState() {
    _jsWindow
      .document
      .querySelector("#timer_text_id")
      .text = "Stopped";
    var nextAnimation;
    if (this.currentAnimation.data != null &&
                     this.currentAnimation.data is pomeranian.TransitionButtonsAnimation) {
            pomeranian.TransitionButtonsAnimation prevAnimation = this.currentAnimation.data;
            nextAnimation = 
                new pomeranian.TransitionButtonsAnimation(
                    _jsWindow,
                    currentAnimation,
                    defaultButtonsContainerWidth: _buttonsContainerWidth,
                    focusButton: _lastButton,
                    isGoingToStop: false,
                    startPosition: (time) => 1-prevAnimation.positionAtTime(time));
    } else {
            nextAnimation = 
              new pomeranian.TransitionButtonsAnimation(
                  _jsWindow,
                  currentAnimation,
                  defaultButtonsContainerWidth: _buttonsContainerWidth,
                  focusButton: _lastButton,
                  isGoingToStop: false);
    }
    _setWasRunningWhenClosed(false);
    animateNow().then(nextAnimation.drawFirstFrame);
    highlightNextButton();
    _jsWindow.document.querySelector("#title_id").text = "Pomeranian";
  }
  
  void clickStop(Event event) {
      
      if (this.currentAnimation.data != null &&
          this.currentAnimation.data is pomeranian.TransitionButtonsAnimation &&
          !(this.currentAnimation.data as pomeranian.TransitionButtonsAnimation).isGoingToStop) {
        clickAction((this.currentAnimation.data as pomeranian.TransitionButtonsAnimation).focusButton)(event); 
        return;
      } 
      
      event.preventDefault();
      _lastAction = 0;
      toStopState();
      _app.cancelAlarm();
    }
  
  void resizeWindow(Event event) {
    dynamic bounds = _window.getBounds().jsProxy;
    //TODO(ads) File bug report as the compilation of this is incorrect.
    _buttonsContainerWidth = bounds['width'] - 30;
    if (currentAnimation.data != null) {
      currentAnimation.data.buttonsContainerWidth = _buttonsContainerWidth;
    } else {
      var nextAnimation = new pomeranian.ResizeAnimation(_jsWindow,currentAnimation,_buttonsContainerWidth);
      animateNow().then(nextAnimation.drawFirstFrame);
    }
    var timerText = _jsWindow.document.querySelector("#timer_text_id");
    //TODO(ads) File bug report as the compilation of this is incorrect.
    var computedMarginTop    = (bounds['height'] - 160 - timerText.clientHeight) ~/ 2;
    //TODO(ads) File bug report as the compilation of this is incorrect.
    var computedMarginBottom = bounds['height'] - 160 - timerText.clientHeight 
                              - computedMarginTop;
    _jsWindow.animationFrame.then((_) {
      timerText.style
        ..marginTop = computedMarginTop.toString() + 'px'
        ..marginBottom = computedMarginBottom.toString() + 'px';
    });
  }
  
  //TODO: This doesn't really belong here.
  static void absolutizeElements (Iterable<Element> collection) {
    List<Bounds> bounds = new List();
    for (Element element in collection) {
      bounds.add(new Bounds(
        left: element.offsetLeft,
        width: element.offsetWidth,
        top: element.offsetTop,
        height: element.offsetHeight
      ));
    }
    var collectionIterator = collection.iterator;
    var boundsIterator = bounds.iterator; 
    while (collectionIterator.moveNext()) {
      boundsIterator.moveNext();
      if (collectionIterator.current.style.display == "none")
        continue;
      assert(boundsIterator.current != null);
      collectionIterator.current.style.position = "absolute";
      collectionIterator.current.style.width = 
          boundsIterator.current.width.toString() + "px";
      collectionIterator.current.style.height = 
          boundsIterator.current.height.toString() + "px";
      collectionIterator.current.style.left = 
          boundsIterator.current.left.toString() + "px";
      collectionIterator.current.style.top = 
          boundsIterator.current.top.toString() + "px";
    }
  }
  
  //TODO: I thought this would make things clearer in general,
  //but I think it just confuses things.
  Future<num> animateNow() {
    if (currentAnimation.data == null) {
      return _jsWindow.animationFrame;
    } else {
      return currentAnimation.data.stop().then((innerTime) =>
        _jsWindow.animationFrame);
    }
  }
}


class Bounds {
  final int left;
  final int top;
  final int width;
  final int height;
  int get right => left + width;
  int get bottom => top + height;
  Bounds._ (this.left, this.top, this.width, this.height);
  factory Bounds ({
    int left:   null, 
    int top:    null, 
    int width:  null, 
    int height: null,
    int right:  null,
    int bottom: null}) {
    try {
      if (width==null) {
        width = right - left; 
      }
      
      if (left==null) {
        left = width - right;
      }
    } 
    catch (_) {
      throw new ArgumentError("Must have two of 'left', 'right' or 'width'");
    }
    try {
      if (height==null) {
        height = bottom - top;
      
      } 
      if (left==null) {
        top = bottom - height;
      }
    }
    catch (e) {
      throw new ArgumentError("Must have two of 'top', 'bottom' or 'height''");
    }
    return new Bounds._ (left, top, width, height);
  }
}
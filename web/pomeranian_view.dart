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
import 'generic_view.dart' as generic;


typedef void ClickHandlerFunction(Event event);
typedef void AnimationCallback(double time);

class View implements generic.AnimatableView {
  final chrome.AppWindow _window;
  final Window _jsWindow;
  final pomeranian.Controller _app;
  
  //TODO: Double up on animation frames so that one animation
  //frame and one timer loop frame can be called at a time.
  @override generic.AnimationFrame requestAnimationFrame() {
    return new generic.WindowAnimationFrame(_jsWindow);
  }
  Future<generic.AnimationFrame> requestFirstAnimationFrame() {
    if (_currentAnimation.data == null) {
      return new Future.sync(requestAnimationFrame);
    }
    else {
      return _currentAnimation.data.stop().then((innerTime) =>
        new generic.WindowAnimationFrame(_jsWindow));
    }
  }
  
  
  
  /*
  @override void cancelAnimationFrame(int id) =>
      _jsWindow.cancelAnimationFrame(id);
  
  @override Future<double> get animationFrame {
    if (_currentAnimation.data == null) {
      return _jsWindow.animationFrame;
    } else {
      return _currentAnimation.data.stop().then((innerTime) =>
        _jsWindow.animationFrame);
    }
  }
  */
  @override Document get document =>
      _jsWindow.document;
  @override double now() =>
      _jsWindow.performance.now();
    
  pomeranian.Button _focusButton = pomeranian.Button.POMODORO;
  pomeranian.Button _lastButton = pomeranian.Button.POMODORO;
  int _buttonsContainerWidth = 530;
  String _currentlyHighlightedButton = "#pomodoro_button_id";
  int _timerLoopFrame;
  Timer _redrawClockTimer;
  int _previousTime = 0;
  
  pomeranian.Pointer<pomeranian.ViewAnimation> _currentAnimation = new pomeranian.Pointer();
  pomeranian.Button get _nextButton {
    if (_app.lastAction > 7) _app.lastAction %= 8;
    switch (_app.lastAction) {
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
  
  generic.AnimationFrame __timerLoopAnimationFrame;
  
  generic.AnimationFrame get _timerLoopAnimationFrame {
    if (__timerLoopAnimationFrame != null) __timerLoopAnimationFrame.cancel();
    __timerLoopAnimationFrame = new generic.WindowAnimationFrame(_jsWindow);
    __timerLoopAnimationFrame.onExpire.listen((_) {
      __timerLoopAnimationFrame = null;
    });
    return __timerLoopAnimationFrame;
    
  }
  void _cancelTimerLoopAnimationFrame () => __timerLoopAnimationFrame.cancel();
  
  View(pomeranian.Controller this._app, chrome.AppWindow this._window, Window this._jsWindow, [bool viewIsReady = false]) {
    if (!_app.stopped) {
      _presetAlarmState();
    } else {
      document.querySelector("#timer_text_id").text = "Stopped";
    }
    _highlightNextButton();
    _app.onRaise.listen((_) => _window.focus());
    _app.onAlarm.listen((_) => _animateToStopState());
    _jsWindow.onResize.listen(_resizeWindow);
    if (viewIsReady) { 
      _resizeWindow(null);
    } else {
      _jsWindow.onLoad.listen(_resizeWindow);
    }
    
    List<Bounds> bounds = new List();
    for (Element element in document.querySelectorAll("#buttons_container_id button")) {
      bounds.add(new Bounds(
        left: element.offsetLeft,
        width: element.offsetWidth,
        top: element.offsetTop,
        height: element.offsetHeight
      ));
    }
    var collectionIterator = document.querySelectorAll("#buttons_container_id button").iterator;
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
    
    document.querySelector("#pomodoro_button_id").onClick.listen(_clickActionButton(pomeranian.Button.POMODORO));
    document.querySelector("#long_button_id").onClick.listen(_clickActionButton(pomeranian.Button.LONG_BREAK));
    document.querySelector("#short_button_id").onClick.listen(_clickActionButton(pomeranian.Button.SHORT_BREAK));
    document.querySelector("#stop_button_id").onClick.listen(_clickStop);
    _jsWindow.onKeyPress.listen((KeyboardEvent keyEvent) {
      if (keyEvent.keyCode != 13) return;
      keyEvent.preventDefault();
      keyEvent.stopPropagation();
      if (_app.stopped) {
        _clickActionButton(_nextButton)(keyEvent);
      } else {
        _clickStop(keyEvent);
      }
    });
  }
  
  _presetAlarmState() {
    document.querySelector("#stop_button_id").style.display = "inline-block";
    document.querySelector("#pomodoro_button_id").style.display=
    document.querySelector("#short_button_id").style.display =
    document.querySelector("#long_button_id").style.display =
        "none";
    document.querySelector("#title_id").text = _app.alarmName;
    _timerLoop();
  }
  
  ClickHandlerFunction _clickActionButton(pomeranian.Button button) => ((Event event) {
    event.preventDefault();
    var nextAnimation;
    if (this._currentAnimation.data != null &&
        this._currentAnimation.data is pomeranian.TransitionButtonsAnimation) {
      pomeranian.TransitionButtonsAnimation prevAnimation = this._currentAnimation.data; 
      nextAnimation = 
         new pomeranian.TransitionButtonsAnimation(
           this,
           _currentAnimation,
           defaultButtonsContainerWidth: _buttonsContainerWidth,
           focusButton: button,
           isGoingToStop: true,
           startPosition: (time) => 1-prevAnimation.positionAtTime(time));
    } else {
      nextAnimation = 
         new pomeranian.TransitionButtonsAnimation(
           this,
           _currentAnimation,
           defaultButtonsContainerWidth: _buttonsContainerWidth,
           focusButton: button,
           isGoingToStop: true);
    }
    requestFirstAnimationFrame().then((firstFrame) {
      _currentAnimation.data = nextAnimation;
      firstFrame.onDraw.listen(nextAnimation.drawFirstFrame);
    });
    _lastButton = button;
    if (button == _nextButton) {
      _app.lastAction++;
    } else if (button == pomeranian.Button.POMODORO) {
      _app.lastAction = 1;
    } else if (button == pomeranian.Button.SHORT_BREAK) {
      _app.lastAction = 2;
    } else {
      _app.lastAction = 0;
    }
    chrome.notifications.clear("_pomerananianNotification");
    _setTimerFromButton (button, event);
  });
  
  void _setTimerFromButton (pomeranian.Button button, Event event) {
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
    document.querySelector("#title_id").text = eventName;
    _app.setAlarm(delayInMinutes, event, name: eventName);
    _timerLoop();
  }
  
  
  void _timerLoop () {
    if (_app.stopped) return;
    var newTime = _app.alarmTimeout.difference(new DateTime.now()).inSeconds;
    if (newTime != _previousTime) {
      _previousTime = newTime;
      _timerLoopAnimationFrame.onDraw.listen(_redrawClock);
    }
    _redrawClockTimer = new Timer(new Duration(milliseconds:100), _timerLoop);
  }
  
  void _redrawClock (double clock) {
    int previousMinutes = _previousTime ~/ 60;
    int previousSeconds = _previousTime % 60;
    String secondsText = ((previousSeconds < 10)?'0':'') + previousSeconds.toString();
    document.querySelector("#timer_text_id")
          .text = previousMinutes.toString() + ':' + secondsText;
  }
  void _highlightNextButton() {
    String nextHighlight;
    if (_nextButton == pomeranian.Button.POMODORO) {
        nextHighlight = "#pomodoro_button_id";
    } else if (_nextButton == pomeranian.Button.SHORT_BREAK) {
        nextHighlight = "#short_button_id";
    } else {
      nextHighlight = "#long_button_id";
    }
    
    document.querySelector(_currentlyHighlightedButton).classes.remove('focused');
    document.querySelector(nextHighlight).classes.add('focused');
    _currentlyHighlightedButton = nextHighlight;
  }
  void _animateToStopState() {
    if (_redrawClockTimer != null) {
      _redrawClockTimer.cancel();
      _redrawClockTimer = null;
    }
    var nextAnimation;
    if (this._currentAnimation.data != null &&
                     this._currentAnimation.data is pomeranian.TransitionButtonsAnimation) {
            pomeranian.TransitionButtonsAnimation prevAnimation = this._currentAnimation.data;
            nextAnimation = 
                new pomeranian.TransitionButtonsAnimation(
                    this,
                    _currentAnimation,
                    defaultButtonsContainerWidth: _buttonsContainerWidth,
                    focusButton: _lastButton,
                    isGoingToStop: false,
                    startPosition: (time) => 1-prevAnimation.positionAtTime(time));
    } else {
            nextAnimation = 
              new pomeranian.TransitionButtonsAnimation(
                  this,
                  _currentAnimation,
                  defaultButtonsContainerWidth: _buttonsContainerWidth,
                  focusButton: _lastButton,
                  isGoingToStop: false);
    }
    requestFirstAnimationFrame().then((firstFrame) {
      _currentAnimation.data = nextAnimation;
      firstFrame.onDraw.listen(nextAnimation.drawFirstFrame);
    });
    _highlightNextButton();
    _timerLoopAnimationFrame.onDraw.listen((_) {
      document.querySelector("#title_id").text = "Pomeranian";
      document.querySelector("#timer_text_id").text = "Stopped";
    });
  }
  
  void _clickStop(Event event) {
      
      if (this._currentAnimation.data != null &&
          this._currentAnimation.data is pomeranian.TransitionButtonsAnimation &&
          !(this._currentAnimation.data as pomeranian.TransitionButtonsAnimation).isGoingToStop) {
        _clickActionButton((this._currentAnimation.data as pomeranian.TransitionButtonsAnimation).focusButton)(event); 
        return;
      } 
      
      event.preventDefault();
      _app.lastAction = 0;
      _animateToStopState();
      _app.cancelAlarm();
    }
  
  void _resizeWindow(Event event) {
    dynamic bounds = _window.getBounds().jsProxy;
    //TODO(ads) File bug report as the compilation of this is incorrect.
    _buttonsContainerWidth = bounds['width'] - 30;
    if (_currentAnimation.data != null) {
      _currentAnimation.data.buttonsContainerWidth = _buttonsContainerWidth;
    } else {
      var nextAnimation = new pomeranian.ResizeAnimation(this,_currentAnimation,_buttonsContainerWidth);
      requestFirstAnimationFrame().then((firstFrame) {
        _currentAnimation.data = nextAnimation;
      firstFrame.onDraw.listen(nextAnimation.drawFirstFrame);
    });
    }
    var timerText = document.querySelector("#timer_text_id");
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
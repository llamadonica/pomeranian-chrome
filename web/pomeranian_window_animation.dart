/**
 * <pomeranian_window_animation.dart>
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

library pomeranian_window_animation;

import 'dart:html';
import 'dart:async';
import 'easing_curve.dart';
import 'animation.dart';
import 'generic_view.dart' as generic;

abstract class ViewAnimation extends Animation {
  Pointer<ViewAnimation> pointer;
  int get commonButtonWidth => (buttonsContainerWidth - 20 + 1) ~/ 3;
  int get middleButtonAdjust => ((buttonsContainerWidth - 20 + 1) % 3) - 1; 
  int get buttonsContainerWidth;
  set buttonsContainerWidth (int value);
  void drawFirstFrame (double time);
  @override Future<double> stop() {
    return super.stop().then((time) {
      pointer.data = null;
      return time;
    });
  }
}

//TODO: Clean up private properties and methods.
class ResizeAnimation extends ViewAnimation {
  final generic.AnimatableView _view;
  generic.AnimatableView get view => _view;
  final Pointer<ViewAnimation> pointer;
  int _buttonsContainerWidth;
  final Element pomodoroButton;
  final Element longButton;
  final Element shortButton;
  final Element stopButton;
  int get buttonsContainerWidth => _buttonsContainerWidth;
  set buttonsContainerWidth (int value) {
    _buttonsContainerWidth = value;
  }
  ResizeAnimation(generic.AnimatableView window, Pointer<ViewAnimation> this.pointer, int this._buttonsContainerWidth) :
    _view = window,
    pomodoroButton = window.document.querySelector("#pomodoro_button_id"),
    longButton = window.document.querySelector("#long_button_id"),
    shortButton = window.document.querySelector("#short_button_id"),
    stopButton = window.document.querySelector("#stop_button_id"); 
  @override void drawFirstFrame (double time) {
    _view.document.querySelector("#buttons_container_id").style.width =
        buttonsContainerWidth.toString() + "px";

    int shortBreakButtonLeft = commonButtonWidth + 10;
    int longBreakButtonLeft = 2*commonButtonWidth + middleButtonAdjust + 20;
            
    stopButton.style
      ..width = buttonsContainerWidth.toString() + "px"
      ..left  = "0px"; 
    pomodoroButton.style
      ..width = commonButtonWidth.toString() + "px"
      ..left  = "0px";
    shortButton.style
      ..width = (commonButtonWidth + middleButtonAdjust).toString() + "px"
      ..left  = shortBreakButtonLeft.toString() + "px";
    longButton.style
      ..width = commonButtonWidth.toString() + "px"
      ..left  = longBreakButtonLeft.toString() + "px";
      
    redraw(time);
  }
  @override animateFrame(double time) {
    pointer.data = null;
    return false;
  }
  @override stop() {
    return this; //Cannot be stopped.
  }
}

//TODO: Clean up private properties and methods.
class TransitionButtonsAnimation extends ViewAnimation {
    final generic.AnimatableView _view;
    final Element pomodoroButton;
    final Element longButton;
    final Element shortButton;
    final Element stopButton;
    final Pointer<ViewAnimation> pointer;
    final Button focusButton;
    final bool isGoingToStop;
    final num animationDuration;
    final EasingCurve _easingCurve;
    final StartPositionFunction _startPosition;
    int defaultButtonsContainerWidth;
    int get buttonsContainerWidth => defaultButtonsContainerWidth;
    set buttonsContainerWidth (int value) {
      defaultButtonsContainerWidth = value;
    }
    
    generic.AnimatableView get view => _view;
    TransitionButtonsAnimation(
        generic.AnimatableView window,
        Pointer<TransitionButtonsAnimation> this.pointer,
        { int this.defaultButtonsContainerWidth: 530,
          Button focusButton,
          bool this.isGoingToStop: false,
          num this.animationDuration: _DEFAULT_ANIMATION_DURATION,
          EasingCurve easingCurve,
          double startPosition(double)}) :
            _view = window,
      pomodoroButton = window.document.querySelector("#pomodoro_button_id"),
      longButton = window.document.querySelector("#long_button_id"),
      shortButton = window.document.querySelector("#short_button_id"),
      stopButton = window.document.querySelector("#stop_button_id"),
      focusButton = (focusButton == null)?Button.POMODORO:focusButton,
      _easingCurve = (easingCurve == null)?_DEFAULT_EASING_CURVE:easingCurve,
      _startPosition = (startPosition == null)?((_) => 0):startPosition ;

    double _animationStart;
    double _animationEnd;
    

    //The default speed is 400 ms.
    static const num _DEFAULT_ANIMATION_DURATION = 400;
    static EasingCurve _DEFAULT_EASING_CURVE = EasingCurve.CUBIC_EASE_IN_OUT;

    int get commonButtonWidth => (buttonsContainerWidth - 20 + 1) ~/ 3;
    int get middleButtonAdjust => ((buttonsContainerWidth - 20 + 1) % 3) - 1;
        
    @override bool animateFrame(double time) {
        double ratio = 0.0;
        bool finished = true;
          
        if (_animationEnd == _animationStart || time > _animationEnd) {
          ratio = 1.0;
        } else {
          var timePosition = positionAtTime(time);
          ratio = _easingCurve[timePosition];
          finished = false;
        }
        
        double position = isGoingToStop?ratio:(1.0-ratio);
        
        double mainButtonSize = 
            commonButtonWidth.toDouble()*(1 - position)
            + buttonsContainerWidth.toDouble()*(position);
        //Before middle button adjustment.
        double secondaryButtonSize = 
            (buttonsContainerWidth.toDouble() - mainButtonSize - 20 - middleButtonAdjust)/2;
        double unadjustedPomodoroButtonWidth =
            (this.focusButton == Button.POMODORO)?mainButtonSize:secondaryButtonSize;
        double unadjustedShortBreakButtonWidth = 
            (this.focusButton == Button.SHORT_BREAK)?mainButtonSize:secondaryButtonSize
            + middleButtonAdjust.toDouble();
        double unadjustedLongBreakButtonWidth = 
            (this.focusButton == Button.LONG_BREAK)?mainButtonSize:secondaryButtonSize;
        
        double secondaryButtonOpacity = (secondaryButtonSize < 0)?0.0:(secondaryButtonSize/commonButtonWidth.toDouble());
        
        int pomodoroButtonLeft = 0;
        int shortBreakButtonLeft = (unadjustedPomodoroButtonWidth + 10.0).round();
        
        int pomodoroButtonWidth = (shortBreakButtonLeft < 10)?0:(shortBreakButtonLeft - 10);
        int longBreakButtonLeft = (unadjustedShortBreakButtonWidth + unadjustedPomodoroButtonWidth + 20).round();
        
        int shortBreakButtonWidth = (longBreakButtonLeft < shortBreakButtonLeft + 10)?0:(longBreakButtonLeft - shortBreakButtonLeft - 10);
        int longBreakButtonWidth = buttonsContainerWidth - longBreakButtonLeft;
        
        double pomodoroButtonOpacity = (this.focusButton == Button.POMODORO)?(1 - position):secondaryButtonOpacity;
        double shortBreakButtonOpacity = (this.focusButton == Button.SHORT_BREAK)?(1 - position):secondaryButtonOpacity;
        double longBreakButtonOpacity = (this.focusButton == Button.LONG_BREAK)?(1 - position):secondaryButtonOpacity;
        
        double stopButtonOpacity = position;
        int stopButtonLeft ;
        int stopButtonWidth;
        if (this.focusButton == Button.POMODORO) {
          stopButtonLeft = pomodoroButtonLeft;
          stopButtonWidth = pomodoroButtonWidth;
        } else if (this.focusButton == Button.SHORT_BREAK) {
          stopButtonLeft = shortBreakButtonLeft;
          stopButtonWidth = shortBreakButtonWidth;
        } else {
          stopButtonLeft = longBreakButtonLeft;
          stopButtonWidth = longBreakButtonWidth;
        }
        
        _view.document.querySelector("#buttons_container_id").style.width =
            buttonsContainerWidth.toString() + "px";
        pomodoroButton.style.width =
            pomodoroButtonWidth.toString() + "px";
        longButton.style.width =
            longBreakButtonWidth.toString() + "px";
        shortButton.style.width =
            shortBreakButtonWidth.toString() + "px";
        
        shortButton.style.left = shortBreakButtonLeft.toString() + "px";
        longButton.style.left = 
            longBreakButtonLeft.toString() + "px";

        pomodoroButton.style.opacity = pomodoroButtonOpacity.toStringAsFixed(2);
        shortButton.style.opacity = shortBreakButtonOpacity.toStringAsFixed(2);
        longButton.style.opacity = longBreakButtonOpacity.toStringAsFixed(2);
           
        stopButton.style.opacity = stopButtonOpacity.toStringAsFixed(2);
        stopButton.style.left = stopButtonLeft.toString() + "px";
        stopButton.style.width = stopButtonWidth.toString() + "px";
//        
//        timerText.style.marginTop =
//          _computedMarginTop.toString() + "px";
//        timerText.style.marginBottom = 
//          _computedMarginBottom.toString() + "px";
        
        if (finished) {
          pointer.data = null;
          if (!isGoingToStop) {
            stopButton.style.display = "none";
          } else {
            pomodoroButton.style.display = "none";
            shortButton.style.display = "none";
            longButton.style.display = "none";
          }
        } 
        return !finished;
      }
    void drawFirstFrame (double time) {
      var startPosition = _startPosition(time);
      _animationStart = time - animationDuration*startPosition;
      _animationEnd = _animationStart + animationDuration;
      if (isCompleted) 
        throw new StateError ("Each animation may only be run once.");
      if (isGoingToStop) {
        stopButton.style.display = "inline-block";
      } else {
        pomodoroButton.style.display = "inline-block";
        shortButton.style.display = "inline-block";
        longButton.style.display = "inline-block";
      }
      redraw(time);
    }
    double positionAtTime (double time) => (time - _animationStart)/(_animationEnd -_animationStart);
}

typedef double StartPositionFunction(double);

class Pointer<T> {
  T _data;
  final StreamController<T> _change = new StreamController.broadcast();
  Stream<T> get onChange => _change.stream;
  void set data (T value) {
    _data = value;
    _change.add(value);
  }
  T get data => _data;
  T qualifiedData() {
    if (_data == null) {
      throw new StateError("_data of Pointer is null.");
    } 
    return _data;
  }
}

abstract class Enum<T> {
  final T value;
  const Enum(T this.value);
  bool operator ==(Enum<T> other) => value == other.value;
  int get hashCode => value.hashCode;
}

class Button extends Enum<int> {
  const Button._(int value): super(value);
  static const Button POMODORO = const Button._(0);
  static const Button SHORT_BREAK = const Button._(1);
  static const Button LONG_BREAK = const Button._(2);
  static const Button STOP = const Button._(3);
  static List<Button> VALUES = [POMODORO,
                                 SHORT_BREAK,
                                 LONG_BREAK,
                                 STOP] ;
}

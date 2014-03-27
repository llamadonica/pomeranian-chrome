/**
 * <animation.dart>
 * 
 * Copyright (c) 2014 "Adam Stark"
 * Animation Engine
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

library animation;

import 'dart:async';
import 'dart:html';

abstract class Animation implements Future<Pair<bool, double>> {    
    Completer<Pair<bool, double>> _completer = new Completer();
    bool get isCompleted => _completer.isCompleted;
    int _requestedFrame;
    int frameCount = 0;
    /**
     * The window that owns this animation.
     */
    Window get window;
    /**
     * Animates the current frame, based on the current time. If the result is
     * true, then it enqueues the frame again. If it's false, it calls the
     * handlers that have attached to [then] asynchronously. 
     */
    bool animateFrame(double time);
    
    /** 
     * Stops the animation. All futures are passed that haven't been called are
     * passed the AnimationStoppedException, instead of calling the done signal.
     */
    Future<double> stop() {
      window.cancelAnimationFrame(_requestedFrame);
      
      var stopCompleter = new Completer();
      var now = window.performance.now();
      _completer.future.whenComplete(() {
        stopCompleter.complete(now);
      });
      _completer.complete(new Pair(false, now));
      return stopCompleter.future;
    }
    /**
     * The main redraw function.
     */
    void redraw(double time) {
      bool continueAnimation = false;
      var throwError = null;
      try {
        continueAnimation = animateFrame(time);
      }
      catch (e) {
        throwError = e;
        continueAnimation = false;
      }
      if (continueAnimation) {
        _requestedFrame = window.requestAnimationFrame(redraw);
        return;
      } else if (throwError == null) {
        _completer.complete(new Pair(true, time));
        return;
      } else {
        _completer.completeError(throwError);
        return;
      }
    }
    Future then(onValue(Pair<bool, double> value), { Function onError }) => 
        _completer.future.then(onValue, onError: onError);
    Future catchError(Function onError, {bool test(Object error)}) =>
        _completer.future.catchError(onError, test: test);
    Future<Pair<bool, double>> whenComplete(action()) =>
        _completer.future.whenComplete(action);
    Future timeout(Duration timelimit, {void onTimeout()}) =>  _completer.future.timeout(timelimit, onTimeout:onTimeout);
    Stream<Pair<bool, double>> asStream() => _completer.future.asStream();
    Animation start() {
      if (this._completer.isCompleted) 
        throw new StateError ("Each animation may only be run once.");
      _requestedFrame = window.requestAnimationFrame(redraw);
      return this;
    }
}

class Pair<A,B> {
  final A first;
  final B second;
  Pair(A this.first, B this.second);
}

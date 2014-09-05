/**
 * <generic_view.dart>
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

import 'dart:async';
import 'dart:html';

abstract class AnimationFrame {
  void cancel();
  Stream<double> get onDraw;
  Stream get onExpire;
}
abstract class AnimatableView {
  AnimationFrame requestAnimationFrame();
  Document get document;
  double now();
  AnimatableView();
  factory AnimatableView.fromWindow(Window window) => new _AnimatableWindow(window);
}

class _AnimatableWindow extends AnimatableView {
  final Window _window;
  _AnimatableWindow(Window this._window);
  @override AnimationFrame requestAnimationFrame() {
    return new WindowAnimationFrame(_window);
  }
  @override Document get document =>
      _window.document;
  @override double now() =>
      _window.performance.now();
}
class WindowAnimationFrame extends AnimationFrame {
  final Window _window;
  final StreamController<double> _onDraw  = new StreamController(sync: true);
  final StreamController _onExpire  = new StreamController(sync: true);
  Stream<double> get onDraw => _onDraw.stream;
  Stream get onExpire  => _onExpire.stream;
  
  int _id;
  bool isCompleted = false;
  WindowAnimationFrame(Window window):
    _window = window {
    _id = window.requestAnimationFrame(callback);
  }
  void callback(double time) {
    if (isCompleted) throw new StateError ("Frame can not be drawn once drawn or cancelled.");
    _onDraw.add(time);
    isCompleted = true;
    _onExpire.add(null);
  }
  void cancel() {
    if (isCompleted) throw new StateError ("Frame can not be cancelled once drawn or cancelled.");
    _window.cancelAnimationFrame(_id);
    isCompleted = true;
    _onExpire.add(null);
  }
}
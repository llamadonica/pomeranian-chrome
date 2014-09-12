import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:math' as Math;
import 'dart:js';

import 'paper-tristate-radio-button.dart';

@CustomTag('paper-tristate-toggle-button')
class PaperTristateToggleButton extends PolymerElement {
  @published int state = 0;
  
  int _w;
  int _x;
  
  PaperTristateToggleButton.created() : super.created();
  
  void trackStart(Event e) {
    _w = $['toggleBar'].offsetLeft + $['toggleBar'].offsetWidth;
    (new JsObject.fromBrowserObject(e)).callMethod("preventTap",[]);
  }
  void trackx(Event e) {
    var jsProxy = new JsObject.fromBrowserObject(e);
    _x = Math.min(_w, Math.max(0, ((state == 2) ? _w : ((state == 1) ? _w / 2 : 0)) +  jsProxy["dx"] as int));
    ($['toggleRadio'] as PaperTristateRadioButton).classes.add('dragging'); //classList.add('dragging');
    var s = ($['toggleRadio'] as PaperTristateRadioButton).style;
    s.transform = 'translate3d(${_x}px,0,0)';
  }
  void trackEnd() {
    var s = ($['toggleRadio'] as PaperTristateRadioButton).style;
    s.transform = '';
    ($['toggleRadio'] as PaperTristateRadioButton).classes.remove('dragging');
    var old = state;
    state = (_x > 3*_w / 4)?2:((_x > _w / 4)?1:0);
    if (state != old)
      fire('change');
  }
  void stateChanged() {
    setAttribute('aria-pressed', (state > 0).toString());
    fire('core-change');
  }
      
  void changeAction(Event e) {
    e.stopPropagation();
    fire('change');
  }
      
  void stopPropagation(Event e) {
    e.stopPropagation();
  }
}
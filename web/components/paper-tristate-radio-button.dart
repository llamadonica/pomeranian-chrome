import 'package:polymer/polymer.dart';
import 'dart:html';

@CustomTag('paper-tristate-radio-button')
class PaperTristateRadioButton extends PolymerElement {
  @PublishedProperty(reflect: true) int state = 0;
  stateChanged(int oldValue) {
    switch (state) {
      case 1:
        ($['onRadio'] as DivElement).classes.remove('fill');
        ($['midRadio'] as DivElement).classes.add('fill');
        break;
      case 2:
        ($['onRadio'] as DivElement).classes.add('fill');
        ($['midRadio'] as DivElement).classes.add('fill');
        break;
      default: 
        ($['onRadio'] as DivElement).classes.remove('fill');
        ($['midRadio'] as DivElement).classes.remove('fill');
        break;
    }
    
    setAttribute('aria-checked', (state > 0) ? 'true': 'false');
    fire('core-change');
  }
  @published String label = '';
  labelChanged(String oldValue) {
    setAttribute('aria-label', label);
  }
  @PublishedProperty(reflect: true) bool disabled = false;
  PaperTristateRadioButton.created() : super.created() {
    addEventListener('tap', tap);
  }
  
  void tap(Event ev) {
    var old = state;
    toggle();
    if (state != old) {
      fire('change');
    }
  }
  void toggle() {
    state = (state + 1) % 3;
  }
}
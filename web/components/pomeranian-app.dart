import 'package:polymer/polymer.dart';
import 'dart:html';

@CustomTag('pomeranian-app')
class PomeranianApp extends PolymerElement {
  @observable int selected;
  @observable String timeRemaining;
  @observable String status;
  
  PomeranianApp.created() : super.created();
  
  @override
  ready() {
    selected = 0;
    timeRemaining = "Stopped";
    status = "Pomeranian";
  }
}
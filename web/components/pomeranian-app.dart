import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';

@CustomTag('pomeranian-app')
class PomeranianApp extends PolymerElement {
  @observable int selected;
  @observable String timeRemaining;
  @observable String status;
  
  DateTime expires = null;
  
  Timer clockTick = null;
  Timer endOfTimer = null;  
  
  PomeranianApp.created() : super.created();
  
  @override
  ready() {
    selected = 0;
    timeRemaining = "Stopped";
    status = "Pomeranian";
  }
  void bellChimes() {
  }
  void statusReset() {
    clockTick = null; 
    endOfTimer = null;
    expires = null;
    timeRemaining = "Stopped";
    status = "Pomeranian";
    selected = 0;
  }
  void setTimer(int timeInMinutes, String title) {
    clockTick = new Timer.periodic(
        const Duration(milliseconds: 500), 
        (timer) {
      if (clockTick == null) return;
      var difference = expires.difference(new DateTime.now());
      var seconds = difference.inSeconds;
      var minute = (seconds / 60).floor();
      seconds %= 60;
      timeRemaining = "$minute:${seconds.toString().padLeft(2,'0')}";
    });
    var duration = new Duration(minutes: timeInMinutes);
    endOfTimer = new Timer(
        duration,
        () {
      statusReset();
      bellChimes();
    });
    timeRemaining = "$timeInMinutes:00";
    status = title;
    selected = 1;
    expires = new DateTime.now().add(duration);
  }
  void pomodoroButton() => setTimer(25,"Sprint");
  void shortBreakButton() => setTimer(5,"Break");
  void longBreakButton() => setTimer(15,"Break");
  void stopButton() => statusReset();
  
}
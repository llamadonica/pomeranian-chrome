/**
 * <background.dart>
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
 (function() {
   var suspendApp = function () {
     window.console.log("Sleeping.");
     windowIsActive = false;
     if (appDelegate.alarm)
       chrome.alarms.create(
         (appDelegate.getTryNotifications()?'':'#') + 
         (appDelegate.getDoAlarmAudio()?'$':'') + 
         appDelegate.alarm.status,
         { when: appDelegate.alarm.time});
   }
   var performLaunch = function() {
    chrome.runtime.getPlatformInfo(function (platformInfo) {
      var frameType;
      if (platformInfo.os == 'cros') {
        frameType = 'panel';
      } else {
        frameType = 'shell';
      }
      chrome.alarms.getAll(function (alarms) {
        var notificationAlarm;
        if (alarms.length) {
          var alarmName = alarms[0].name;
	        if (alarmName.indexOf('#') == 0)
	          alarmName = alarmName.slice(1);
	        if (alarmName.indexOf('$') == 0)
            alarmName = alarmName.slice(1);
          appDelegate.alarm = {
            time: alarms[0].scheduledTime,
            status: alarmName
          };
        }
        chrome.app.window.create(
          'pomeranianchrome.html',
          { id:'_mainWindow',
            frame:'chrome',
            type:frameType,
            defaultWidth:560,
            defaultHeight:240,
            minWidth: 422,
            minHeight: 200,
            alwaysOnTop: true },
          function (appWindow) {
            appWindow.contentWindow.appDelegate = appDelegate;
            windowIsActive = true;
            chrome.alarms.clearAll();
	          if (typeof Cordova === 'undefined')
	            appWindow.onClosed.addListener(suspendApp);
          });
        });
     });
   };
   var windowIsActive = false;
   var allNotifications = {
     handleClick: function (id) {
       if (this && this[id] && this[id].innerListener)
         this[id].innerListener(null);
       if (id == '_POMERANIAN_NOTIFICATION_') {
         if (windowIsActive) {
           var mainWindow = chrome.app.window.get('_mainWindow');
           mainWindow.clearAttention();
           mainWindow.show();
         } else {
           performLaunch();
         }
       }
       chrome.notifications.clear(id, function(_) {;});
     }
   };
   var appDelegate = {
     alarm: null,
     storage: {},
     _tryNotifications: true,
     _keepOnTop: 2,
     _isAuthorizedForNotifications: false,
     getIconSize: function() {return 128;},
     storeKey: function(key, value) {
       if (!this.storage)
         this.storage = {};
       this.storage[key] = value;
       chrome.storage.local.set({
         _APP_: this.storage
       });
     },
     getKey: function(key) {
       if (this.storage && this.storage[key]) 
         return this.storage[key];
       return null;
     },
     getHasNotificationCapabilities: function() {
       return true;
     },
     getHasStorageCapabilities: function() {
       return true;
     },
     getHasAlwaysOnTopCapabilities: function() {
       if (typeof Cordova === 'undefined')
         return true;
       return false;
     },
     getHasTickCapabilities: function() {
       return true;
     },
     getHasNotifyCapabilities: function() {
       return true;
     },
     getIsAuthorizedForNotifications: function() {
       return this._isAuthorizedForNotifications;
     },
     postAlarm: function(alarmTime, status) {
       this.alarm = {
         time: alarmTime,
         status: status
       };
     },
     removeAlarm: function(alarmTime) {
       this.alarm = null;
     },
     getTryNotifications: function() {
       return this._tryNotifications;
     },
     setTryNotifications: function(value) {
       this._tryNotifications = value;
     },
     getKeepOnTop: function() {
       return this._keepOnTop;
     },
     setKeepOnTop: function(value) {
       this._keepOnTop = value;
       if (typeof Cordova !== 'undefined') return;
       
       var window = chrome.app.window.get('_mainWindow');
       if (window)
         window.setAlwaysOnTop(value > 0);
     },
     createNotification: function (title, options) {
       chrome.notifications.create(
         '_POMERANIAN_NOTIFICATION_',
         { 
           type: 'basic',
           title: title,
           message: (options && options.body)?options.body:'',
           isClickable: true,
           iconUrl: (options && options.icon)?options.icon:''
         },
         function(_) {}
       );
       var thisNotification = {
         _id: '_POMERANIAN_NOTIFICATION_',
         innerListener: null,
         close: function() {
           chrome.notifications.clear(this._id);
         },
         addEventListener: function(callback) {
           if (this.innerListener)
             throw "Can only have one listener for _POMERANIAN_NOTIFICATION_.onClick";
           this.innerListener = callback;
         },
         removeEventListener: function(callback) {
           this.innerListener = null;
         }
       };
       if (allNotifications)
         allNotifications[thisNotification._id] = thisNotification;
       return thisNotification;
     },
     authorizeForNotification: function (callback) {
       this._isAuthorizedForNotifications = true;
       if (callback) callback(true);
     },
     setNotify: function () {
       if (typeof Cordova !== 'undefined')
         return;
       var window = chrome.app.window.get('_mainWindow');
       if (window)
         window.drawAttention();
     },
     clearNotify: function () {
       if (typeof Cordova !== 'undefined')
         return;
       var window = chrome.app.window.get('_mainWindow');
       if (window)
         window.clearAttention();
     },
     getDoAlarmAudio: function() {
       return this._doAlarmAudio;
     },
     setDoAlarmAudio: function(value) {
       this._doAlarmAudio = value;
     }
   }
  chrome.storage.local.get('_APP_',function(keys) {
    appDelegate.storage = keys['_APP_'];
  });
  chrome.app.runtime.onLaunched.addListener(performLaunch);
  if (typeof Cordova !== 'undefined') {
    window.console.log("Setting up listeners.");
    chrome.runtime.onSuspend.addListener(suspendApp);
    chrome.runtime.onSuspendCanceled.addListener(function() {
      window.console.log("Waking up.");
      windowIsActive = true;
      chrome.alarms.clearAll();
    });
  } 
  
  chrome.notifications.onClicked.addListener(allNotifications.handleClick);
})();
chrome.notifications.onClicked.addListener(function(id) {
  chrome.notifications.clear(id, function(_) {;});
});
chrome.alarms.onAlarm.addListener(function (alarm) {
  var alarmName = alarm.name;
  var notify = true;
  audio = false;
  if (alarmName.indexOf('#') == 0) {
    notify = false;
    alarmName = alarmName.slice(1);
  }
  if (alarmName.indexOf('$') == 0) {
    audio = true;
    alarmName = alarmName.slice(1);
  }

  var message = (alarmName == 'Sprint')?'Time for a break.':'Time to get back to work.';
  if (notify)
    chrome.notifications.create(
      '_POMERANIAN_NOTIFICATION_',
      { type: 'basic',
        title: alarmName + ' is over.',
        message: message,
        isClickable: true,
        iconUrl: '/icon_' + 128 + '.png'
      }, function(_) {}
    );
  if (audio) {
    var context = new AudioContext();
    var request = new XMLHttpRequest();
    var uri = 'assets/sounds/ring.ogg';
    request.addEventListener('load',function(e) {
      context.decodeAudioData(request.response, function(buffer) {
        var source = context.createBufferSource(); // creates a sound source
        source.buffer = buffer;                    // tell the source which sound to play
        source.connect(context.destination);       // connect the source to the context's destination (the speakers)
        source.start(0);
      });
    });
    request.responseType = 'arraybuffer';
    request.open('GET', uri, true);
    request.send();
  }
});
chrome.runtime.onSuspend.addListener(function() {
  window.console.log("Suspending on line 274.");
});
chrome.runtime.onSuspendCanceled.addListener(function() {
  window.console.log("Suspend resumed on line 277.");
});
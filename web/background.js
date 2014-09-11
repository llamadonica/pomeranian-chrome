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
        if (alarms)
          appDelegate.alarms = alarms;
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
	    console.debug('Window Opened');
	    
	    appWindow.onClosed.addListener(function () {
	      console.debug('Window Closed');
	      windowIsActive = false;
	      if (appDelegate.alarms.length)
	        chrome.alarms.create('', {when: appDelegate.alarms[0]});
	    });
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
     }
   };
   var appDelegate = {
     alarms: [],
     storage: {},
     _tryNotifications: true,
     _isAuthorizedForNotifications: false,
     _status: '',
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
     getIsAuthorizedForNotifications: function() {
       return this._isAuthorizedForNotifications;
     },
     postAlarm: function(alarmTime, status) {
       this.alarms[0] = alarmTime;
       this._status = status;
     },
     removeAlarm: function(alarmTime) {
       this.alarms = [];
     },
     getTryNotifications: function() {
       return this._tryNotifications;
     },
     setTryNotifications: function(value) {
       this._tryNotifications = value;
     },
     createNotification: function(title, options) {
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
	 _innerListener: null,
	 close: function() {
	   chrome.notifications.clear(this._id);
	 },
	 addEventListener: function(callback) {
	   if (_innerListener)
	     throw "Can only have one listener for _POMERANIAN_NOTIFICATION_.onClick";
	   this._innerListener = callback;
	 },
	 removeEventListener: function(callback) {
	   this._innerListener = null;
	 }
       };
       allNotifications[thisNotification._id] = thisNotification;
       return thisNotification;
     },
     authorizeForNotification: function (callback) {
       this._isAuthorizedForNotifications = true;
       if (callback) callback(true);
     }
   }
  chrome.storage.local.get('_APP_',function(keys) {
    appDelegate.storage = keys['_APP_'];
  });
  chrome.app.runtime.onLaunched.addListener(performLaunch);
  chrome.alarms.onAlarm.addListener(function (alarm) {
    var message = (appDelegate._status == 'Sprint')?'Time for a break.':'Time to get back to work.';
    var notification = appDelegate.createNotification(appDelegate._status + ' is over.',
    { body: message,
      icon: '/icon_' + appDelegate.getIconSize() + '.png' });
    appDelegate.alarms = [];
  });
  chrome.notifications.onClicked.addListener(allNotifications.handleClick);
})();
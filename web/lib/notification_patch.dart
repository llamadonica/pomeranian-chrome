library notification_patch;

import 'dart:html_common';
import 'dart:html';
import 'dart:async';
import 'dart:js';

@DomName('Notification')
class Notification /*implements EventTarget*/ {
  final JsObject _proxy;

  factory Notification(String title, {String titleDir: null, String body: null,
      String bodyDir: null, String tag: null, String iconUrl: null}) {

    var parsedOptions = {};
    if (titleDir != null) parsedOptions['titleDir'] = titleDir;
    if (body != null) parsedOptions['body'] = body;
    if (bodyDir != null) parsedOptions['bodyDir'] = bodyDir;
    if (tag != null) parsedOptions['tag'] = tag;
    if (iconUrl != null) parsedOptions['icon'] = iconUrl;

    return new Notification._factoryNotification(title, new JsObject.jsify(parsedOptions));
  }
  // To suppress missing implicit constructor warnings.
  factory Notification._() { throw new UnsupportedError("Not supported"); }

  @DomName('Notification.Notification')
  @DocsEditable()
  Notification._factoryNotification(String title, JsObject options) :
    _proxy = new JsObject(context['Notification'], [title, options]);
  Notification.fromProxy(JsObject this._proxy);

  @DomName('Notification.body')
  @DocsEditable()
  @Experimental() // untriaged
  String get body => _proxy['body'];

  @DomName('Notification.dir')
  @DocsEditable()
  @Experimental() // nonstandard
  String get dir => _proxy['dir'];

  @DomName('Notification.icon')
  @DocsEditable()
  @Experimental() // untriaged
  String get icon => _proxy['icon'];

  @DomName('Notification.lang')
  @DocsEditable()
  @Experimental() // untriaged
  String get lang => _proxy['lang'];

  @DomName('Notification.permission')
  @DocsEditable()
  String get permission => _proxy['permission'];

  @DomName('Notification.tag')
  @DocsEditable()
  @Experimental() // nonstandard
  String get tag => _proxy['tag'];

  @DomName('Notification.title')
  @DocsEditable()
  @Experimental() // untriaged
  String get title => _proxy['title'];

  @DomName('Notification.close')
  @DocsEditable()
  void close() => _proxy.callMethod('close',[]);

  @DomName('Notification.requestPermission')
  @DocsEditable()
  static void _requestPermission([_NotificationPermissionCallback callback]) =>
      context['Notification'].callMethod('requestPermission',
          [new JsFunction.withThis((_this, permission) => callback(permission))]);

  @DomName('Notification.requestPermission')
  @DocsEditable()
  static Future<String> requestPermission() {
    var completer = new Completer<String>();
    _requestPermission(
        (value) { completer.complete(value); });
    return completer.future;
  }

  /// Stream of `click` events handled by this [Notification].
  @DomName('Notification.onclick')
  @DocsEditable()
  Stream<Event> get onClick => _onClick.stream;
  StreamController<Event> __onClick;
  JsFunction _onClickHandler;
  StreamController<Event> get _onClick {
    if (__onClick == null)
      __onClick = new StreamController.broadcast(
        onListen: () {
          _onClickHandler = new JsFunction.withThis((_this,event) {
            _onClick.add(event);
          });
          _proxy.callMethod('addEventListener',['click',_onClickHandler]);
        },
        onCancel: () {
          _proxy.callMethod('removeEventListener',['click',_onClickHandler]);
          _onClickHandler = null;
        }
      );
    return __onClick;
  }
/*  

  /// Stream of `close` events handled by this [Notification].
  @DomName('Notification.onclose')
  @DocsEditable()
  Stream<Event> get onClose => closeEvent.forTarget(this);

  /// Stream of `error` events handled by this [Notification].
  @DomName('Notification.onerror')
  @DocsEditable()
  Stream<Event> get onError => errorEvent.forTarget(this);

  /// Stream of `show` events handled by this [Notification].
  @DomName('Notification.onshow')
  @DocsEditable()
  Stream<Event> get onShow => showEvent.forTarget(this);
*/
}
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// WARNING: Do not edit - generated code.


@DomName('NotificationPermissionCallback')
// http://www.w3.org/TR/notifications/#notificationpermissioncallback
@Experimental()
typedef void _NotificationPermissionCallback(String permission);
// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

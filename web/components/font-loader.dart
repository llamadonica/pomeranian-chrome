import 'package:polymer/polymer.dart';
import 'dart:html';
import 'dart:async';

@CustomTag('font-loader')
class FontLoader extends PolymerElement {
  @published String fontCss;
  
  List<String> _oldCss = new List();
  List<String> _newCss;
  
  Map<String,String> _loadedUrls = new Map();
  Map<String,List<String>> _refFiles = new Map();
  Map<String,int> _fileCounts = new Map();
  Map<String,StyleElement> _styles = new Map();
  
  static const String REGEX_EXPR=r'''url\s*\(('|"|)([^'" ]+)('|"|)\)''';
  RegExp cssRegex = new RegExp(REGEX_EXPR);
  
  static const String REGEX_URL=r'''((([A-Za-z]{3,9}:(?:\/\/)?)(?:[-;:&=\+\$,\w]+@)?[A-Za-z0-9.-]+|(?:www.|[-;:&=\+\$,\w]+@)[A-Za-z0-9.-]+)((?:\/(([\+~%.\w-_]*\/)*)([\+~%.\w-_]*))?\??(?:[-\+=&;%@.\w_]*)#?(?:[\w]*))?)''';
  RegExp urlRegex = new RegExp(REGEX_URL);
  
  void fontCssChanged(String old) {
    if (old == fontCss) return;
    _oldCss = _newCss;
    parseCss().then((_) {
      fire('fonts-loaded');
    });
    for (var oldUrl in _oldCss) {
      if (_newCss.contains(oldUrl)) continue;
      
      _styles[oldUrl].remove();
      _styles.remove(oldUrl);
      for (var fontUrl in _refFiles[oldUrl]) {
        if (--_fileCounts[fontUrl] == 0) {
          Url.revokeObjectUrl(_loadedUrls[fontUrl]);
          _loadedUrls.remove(fontUrl);
        }
        _fileCounts.remove(fontUrl);
      }
      _refFiles.remove(oldUrl);
    }
  }
  FontLoader.created() : super.created();
  @override ready() {
    parseCss().then((_) {
      fire('fonts-loaded');
    });
  }
  Future parseCss() {
    _newCss = fontCss.split(' ');
    
    var completer = new Completer();
    
    Ref<int> counter = new Ref();
    counter.value = 1;
    
    for (var url in _newCss) {
      if (_oldCss.contains(url)) continue;
      
      counter.value++;
      handleCssUrl(url).then((_) {
        if (--counter.value == 0) {
          completer.complete();
        }
      });
    }
    if (--counter.value == 0) {
      completer.complete();
    }
    return completer.future;
  }
  Future handleCssUrl(String url) {
    var completer = new Completer();
    
    var request = new HttpRequest();
    request.responseType = 'text';
    request.open('GET', url);
    request.onLoad.listen((ev) {
      handleCssFile(url, request.response).then((_) {
        completer.complete();
      });
    });
    request.onError.listen((ev) {
      window.console.error("Could not load CSS from URL $url: ${request.statusText}");
    });
    request.send();
    return completer.future;
  }
  Future handleCssFile(String url, String body) {
    var urlMatch = urlRegex.firstMatch(url);
    _refFiles[url] = new List();
    
    var matches = cssRegex.allMatches(body).toList().reversed;
    Ref<int> counter = new Ref();
    counter.value = 1;
    var completer = new Completer();
    
    Map<String,String> _relativeToAbsolute = new Map();
    
    for (var match in matches) {
      var absoluteUrl = '';
      
      var relativeUrl = match.group(2);
            
      if (relativeUrl.startsWith("http://") || relativeUrl.startsWith("https://")) {
        absoluteUrl = relativeUrl;
      } else if (relativeUrl.startsWith("//")) {
        absoluteUrl = urlMatch.group(3) + relativeUrl.substring(2);
      } else if (relativeUrl.startsWith("/")) {
        absoluteUrl = urlMatch.group(2) + relativeUrl;
      } else {
        absoluteUrl = urlMatch.group(2) + '/' + urlMatch.group(4) + relativeUrl;
      }
      
      _relativeToAbsolute[relativeUrl] = absoluteUrl;
      
      if (_loadedUrls.containsKey(absoluteUrl)) {
        _fileCounts[absoluteUrl] ++;
      } else {
        counter.value++;
        
        var request = new HttpRequest();
        request.responseType = 'blob';
        request.open('GET', absoluteUrl);
        request.onLoad.listen((ev) {
          var blob = request.response as Blob;
          _loadedUrls[absoluteUrl] = Url.createObjectUrlFromBlob(blob);
          _fileCounts[absoluteUrl] = 1;
          if (--counter.value == 0) {
            completer.complete();
          }
        });
        request.onError.listen((ev) {
          window.console.error("Could not load CSS from URL $absoluteUrl: ${request.statusText}");
          if (--counter.value == 0) {
            completer.complete();
          }
        });
        request.send();
        _refFiles[url].add(absoluteUrl);
      }
    }
    if (--counter.value == 0) {
      completer.complete();
    }
    return completer.future.then((_) {
      for (var match in matches) {
        var absoluteUrl = _relativeToAbsolute[match.group(2)];
        if (_loadedUrls.containsKey(absoluteUrl)) {
          var fileUrl = _loadedUrls[absoluteUrl];
          var newScript = 'url("$fileUrl")';
          body = body.substring(0, match.start) + newScript + body.substring(match.end);
        }
      }
      var style = new StyleElement();
      style.text = body;
      var docBody = document.querySelector("body");
      docBody.insertBefore(style, docBody.firstChild);
      _styles[url] = style;
    });
  }
}

class Ref<T> {
  T value;
}
library polymer_chrome.transformer;

// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';

import 'package:barback/barback.dart';
import 'package:path/path.dart' as path;
import 'package:polymer/transformer.dart' as polymer;
import 'package:polymer/src/build/common.dart' as polymer;

import 'package:html5lib/parser.dart';
import 'package:html5lib/dom.dart';

import 'package:http/http.dart' as http;

import 'dart:io';

class TransformOptions {
  final polymer.TransformOptions polymerOptions;
  TransformOptions({entryPoints, inlineStylesheets,
    contentSecurityPolicy: false, directlyIncludeJS: true,
    releaseMode: true, lint: true,
    injectBuildLogsInOutput: false}) : 
      polymerOptions = new polymer.TransformOptions(
          entryPoints:entryPoints, 
          inlineStylesheets:inlineStylesheets,
          contentSecurityPolicy: contentSecurityPolicy,
          directlyIncludeJS: directlyIncludeJS,
          releaseMode: releaseMode,
          lint: lint,
          injectBuildLogsInOutput: injectBuildLogsInOutput);
}

class CssImporter extends Transformer {
  CssImporter.asPlugin();
  CssImporter();
  
  Map<String, String> _urls = new Map();
  Map<String, String> _shortnames = new Map();
  Map<String, int> _shortnamesIndices = new Map();
  
  static const String IMPORT_REGEX = 
      r'''@import\s+url\(\s*('|"|)((http:|https:|)//[^ '")]+)('|"|)\s*\)\s*''';
  static const String SHORTNAME_REGEX = 
      r'''.*/([^/?]*)(\?.*)?$''';
  static const String URL_REGEX = 
        r'''url\(\s*('|"|)((http:|https:|)//[^ '")]+)('|"|)\s*\)\s*''';
  
  
  String get allowedExtensions => ".css .html";
  Future apply(Transform transform) =>
    applyAsset(transform.primaryInput, transform);
  Future applyAsset(Asset asset, Transform transform) {
    return asset.readAsString().then((String content) {
      var completer = new Completer();
      if (asset.id.extension == '.css') {
        importCss(content, transform).then((newContent) {
          if (newContent != content) {
            transform.addOutput(new Asset.fromString(asset.id, newContent));
          }
          completer.complete();
        });
      } else if (asset.id.extension == '.html') {
        importHtml(content, transform).then((newContent) {
          if (newContent != content) {
            transform.addOutput(new Asset.fromString(asset.id, newContent));
          }
          completer.complete();
        });
      } else {
        completer.complete();
      }
      return completer.future;
    });
    
  }
  Future<String> importCss(String content, Transform transform) {
    var regex = new RegExp(IMPORT_REGEX);
    
    var matches = regex.allMatches(content).toList().reversed;
    
    Ref<int> ref = new Ref();
    ref.value = 0;
    Completer completer = new Completer();
    
    for (var match in matches) {
      ref.value++;
      var url = match.group(2);
      if (url.startsWith('//'))
        url = 'https:' + url;
      transform.logger.info("GETting $url");
      var shortname_regex = new RegExp(SHORTNAME_REGEX);
      var shortname = url;
      if (shortname_regex.hasMatch(url)) {
        shortname = shortname_regex.firstMatch(url).group(1);
      }
      
       
      if (!_urls.containsKey(url)) {
        if (_shortnames.containsKey(shortname)) {
          if (!_shortnamesIndices.containsKey(shortname)) {
            _shortnamesIndices[shortname] = 0;
          }
          shortname = shortname + '_' + (++_shortnamesIndices[shortname]).toString();  
        }
        
        _shortnames[shortname] = url;
        _urls[url] = shortname;
        
        http.get(url).then((response) {
          transform.logger.info("$url => assets/downloads/$shortname.css");
          importCss(response.body, transform).then((newContent) {
            var newAsset = new Asset.fromString(
                new AssetId(
                  transform.primaryInput.id.package,
                  "web/assets/downloads/$shortname.css"), newContent);
            transform.addOutput(newAsset);
            if (--ref.value == 0) {
              completer.complete();
            }
          });
        });
      } else {
        shortname = _urls[url];
        if (--ref.value == 0) {
          completer.complete();
        }
      }
      var newScript = "@import url('/assets/downloads/$shortname.css');";
      content = content.substring(0, match.start)
              + newScript + content.substring(match.end);
    }
    
    regex = new RegExp(URL_REGEX);
    matches = regex.allMatches(content).toList().reversed;
    for (var match in matches) {
      ref.value++;
      var url = match.group(2);
      if (url.startsWith('//'))
        url = 'https:' + url;
      transform.logger.info("GETting $url");
      var shortname_regex = new RegExp(SHORTNAME_REGEX);
      var shortname = url;
      if (shortname_regex.hasMatch(url)) {
        shortname = shortname_regex.firstMatch(url).group(1);
      }
    
           
      if (!_urls.containsKey(url)) {
        if (_shortnames.containsKey(shortname)) {
          if (!_shortnamesIndices.containsKey(shortname)) {
            _shortnamesIndices[shortname] = 0;
          }
          shortname = shortname + '_' + (++_shortnamesIndices[shortname]).toString();  
        }
            
        _shortnames[shortname] = url;
        _urls[url] = shortname;
            
        http.get(url).then((response) {
          transform.logger.info("$url => assets/downloads/$shortname");
          transform.addOutput(new Asset.fromString(
              new AssetId(
                  transform.primaryInput.id.package,
                  "web/assets/downloads/$shortname"), response.body));
          if (--ref.value == 0) {
            completer.complete();
          }
        });
      } else {
        shortname = _urls[url];
        if (--ref.value == 0) {
          completer.complete();
        }
      }
      var newScript = "url('/assets/downloads/$shortname');";
      content = content.substring(0, match.start)
              + newScript + content.substring(match.end);
    }
    
    if (ref.value == 0 && !completer.isCompleted)
      completer.complete();
    
    return completer.future.then((_) => content);
  }
  Future<String> importHtml(String content, Transform transform) {
    Document document = parse(content, encoding: 'UTF-8');
    var styles = document.querySelectorAll('style');
    
    Ref<int> ref = new Ref();
    ref.value = 0;
    Completer completer = new Completer();
    
    for (var style in styles) {
      ref.value++;
      importCss(style.innerHtml, transform).then((newStyle) {
        if (style.innerHtml == newStyle) return;
        style.text = newStyle;
      }).then((_) {
        if (--ref.value == 0)
          completer.complete();
      });
    }
    if (styles == null || styles.length == 0) 
      completer.complete();
    return completer.future.then((_) => document.outerHtml);
  }
}

class Ref<T> {
  T _value;
  T get value => _value;
  void set value(T input) {
    _value = input;
  }
}

class ChromeTransformer extends Transformer {
  final List<String> entryPoints;
  final RegExp _regex = new RegExp(
      r'''^(.*)\.html_bootstrap\.dart\.js$''');

  ChromeTransformer(TransformOptions options) 
    : entryPoints = options.polymerOptions.entryPoints;

  // TODO: Remove the [assetOrId] hack.
  Future<bool> isPrimary(assetOrId) {
    AssetId id = assetOrId is Asset ? assetOrId.id : assetOrId;
    return new Future.value(entryPoints.contains(id.path));
  }

  Future apply(Transform transform) {
    return transform.primaryInput.readAsString().then((String content) {
      var id = transform.primaryInput.id;
      String newContent = rewriteContent(content,transform.primaryInput.id.path);
      if (newContent != content) {
        transform.addOutput(new Asset.fromString(id, newContent));
      }
    });
  }

  /**
   * Change:
   *     <script src="demo.dart" type="application/dart"></script>
   * to:
   *     <script src="demo.dart.js"></script>
   */
  String rewriteContent(String content, String path) {
    Document document = parse(content, encoding: 'UTF-8');
    var scripts = document.querySelectorAll('script');
    
    for (Element script in scripts) {
      
      if (script.attributes['type'] == 'application/dart') {
        script.attributes.remove('type');
        script.attributes['src'] = script.attributes['src'] + '.precompiled.js';
      } else if (_regex.hasMatch(script.attributes['src'])) {
        script.attributes['src'] = 
            _regex.firstMatch(script.attributes['src']).group(1) + '.html_bootstrap.dart.precompiled.js';
      }
    }

    return document.outerHtml;
    //return content;
  }
}

/// The Polymer transformer, which internally runs several phases that will:
///   * Extract inlined script tags into their separate files
///   * Apply the observable transformer on every Dart script.
///   * Inline imported html files
///   * Combine scripts) from multiple files into a single script tag
///   * Inject extra polyfills needed to run on all browsers.
///
/// At the end of these phases, this tranformer produces a single entrypoint
/// HTML file with a single Dart script that can later be compiled with dart2js.
class PomeranianChromeTransformer implements TransformerGroup {
final Iterable<Iterable> phases;

PomeranianChromeTransformer(TransformOptions options)
   : phases = createDeployPhases(options);

PomeranianChromeTransformer.asPlugin(BarbackSettings settings)
   : this(_parseSettings(settings));
}

TransformOptions _parseSettings(BarbackSettings settings) {
  var args = settings.configuration;
  bool releaseMode = settings.mode == BarbackMode.RELEASE;
  bool jsOption = args['js'];
  bool csp = args['csp'] == true; // defaults to false
  bool lint = args['lint'] != false; // defaults to true
  bool injectBuildLogs =
     !releaseMode && args['inject_build_logs_in_output'] != false;
  return new TransformOptions(
    entryPoints: _readEntrypoints(args['entry_points']),
    inlineStylesheets: _readInlineStylesheets(args['inline_stylesheets']),
    directlyIncludeJS: jsOption == null ? releaseMode : jsOption,
    contentSecurityPolicy: csp,
    releaseMode: releaseMode,
    lint: lint,
    injectBuildLogsInOutput: injectBuildLogs);
}

_readEntrypoints(value) {
if (value == null) return null;
var entryPoints = [];
bool error;
if (value is List) {
 entryPoints = value;
 error = value.any((e) => e is! String);
} else if (value is String) {
 entryPoints = [value];
 error = false;
} else {
 error = true;
}
if (error) {
 print('Invalid value for "entry_points" in the polymer transformer.');
}
return entryPoints;
}

Map<String, bool> _readInlineStylesheets(settingValue) {
if (settingValue == null) return null;
var inlineStylesheets = {};
bool error = false;
if (settingValue is Map) {
 settingValue.forEach((key, value) {
   if (value is! bool || key is! String) {
     error = true;
     return;
   }
   if (key == 'default') {
     inlineStylesheets[key] = value;
     return;
   };
   key = _systemToAssetPath(key);
   // Special case package urls, convert to AssetId and use serialized form.
   var packageMatch = _PACKAGE_PATH_REGEX.matchAsPrefix(key);
   if (packageMatch != null) {
     var package = packageMatch[1];
     var path = 'lib/${packageMatch[2]}';
     key = new AssetId(package, path).toString();
   }
   inlineStylesheets[key] = value;
 });
} else if (settingValue is bool) {
 inlineStylesheets['default'] = settingValue;
} else {
 error = true;
}
if (error) {
 print('Invalid value for "inline_stylesheets" in the polymer transformer.');
}
return inlineStylesheets;
}

/// Create deploy phases for Polymer. Note that inlining HTML Imports
/// comes first (other than linter, if [options.linter] is enabled), which
/// allows the rest of the HTML-processing phases to operate only on HTML that
/// is actually imported.
List<List<Transformer>> createDeployPhases(
 TransformOptions options, {String sdkDir}) {
 var phases = [
   [new polymer.PolymerTransformerGroup(options.polymerOptions)],
   [new ChromeTransformer(options)],
   [new CssImporter()]];
 return phases;
}

/// Convert system paths to asset paths (asset paths are posix style).
String _systemToAssetPath(String assetPath) {
if (path.Style.platform != path.Style.windows) return assetPath;
return path.posix.joinAll(path.split(assetPath));
}

final RegExp _PACKAGE_PATH_REGEX = new RegExp(r'packages\/([^\/]+)\/(.*)');

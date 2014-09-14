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
    print("Transforming ${transform.primaryInput.id.path}");
    return transform.primaryInput.readAsString().then((String content) {
      var id = transform.primaryInput.id;
      print("Checking ${transform.primaryInput.id.path}");
      String newContent = rewriteContent(content,transform.primaryInput.id.path);
      if (newContent != content) {
        print("Changed ${transform.primaryInput.id.path}");
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
        print("Found dart application in $path");
        script.attributes.remove('type');
        script.attributes['src'] = script.attributes['src'] + '.precompiled.js';
      } else if (_regex.hasMatch(script.attributes['src'])) {
        print("Found non-CSP application in $path");
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
///   * Combine scripts from multiple files into a single script tag
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
   [new ChromeTransformer(options)]];
 return phases;
}

/// Convert system paths to asset paths (asset paths are posix style).
String _systemToAssetPath(String assetPath) {
if (path.Style.platform != path.Style.windows) return assetPath;
return path.posix.joinAll(path.split(assetPath));
}

final RegExp _PACKAGE_PATH_REGEX = new RegExp(r'packages\/([^\/]+)\/(.*)');

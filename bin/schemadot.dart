#!/usr/bin/env dart
/// 
/// Usage: schemadot --in-uri INPUT_JSON_URI --out-file OUTPUT_FILE
///
/// Given an input uri [in-uri] processes content of uri as
/// json schema and generates input file for Graphviz dot
/// program. If [out-file] provided, output is written to 
/// to the file, otherwise written to stdout.
/// 

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';
import 'dart:math';
import 'package:args/args.dart';
import 'package:json_schema/json_schema.dart';
import 'package:json_schema/schema_dot.dart';
import 'package:logging/logging.dart';

//! The parser for this script
ArgParser _parser;

//! The comment and usage associated with this script
void _usage() { 
  print('''

Usage: schemadot --in-uri INPUT_JSON_URI --out-file OUTPUT_FILE

Given an input uri [in-uri] processes content of uri as
json schema and generates input file for Graphviz dot
program. If [out-file] provided, output is written to 
to the file, otherwise written to stdout.

''');
  print(_parser.getUsage());
}

//! Method to parse command line options.
//! The result is a map containing all options, including positional options
Map _parseArgs(args) { 
  ArgResults argResults;
  Map result = { };
  List remaining = [];

  _parser = new ArgParser();
  try { 
    /// Fill in expectations of the parser
    _parser.addOption('in-uri', 
      defaultsTo: null,
      allowMultiple: false,
      abbr: 'i',
      allowed: null);
    _parser.addOption('out-file', 
      defaultsTo: null,
      allowMultiple: false,
      abbr: 'o',
      allowed: null);

    /// Parse the command line options (excluding the script)
    var arguments = args;
    argResults = _parser.parse(arguments);
    argResults.options.forEach((opt) { 
      result[opt] = argResults[opt];
    });
    
    return { 'options': result, 'rest': remaining };

  } catch(e) { 
    _usage();
    throw e;
  }
}

final _logger = new Logger("schemadot");

main(List<String> args) { 
  Logger.root.onRecord.listen((LogRecord r) =>
      print("${r.loggerName} [${r.level}]:\t${r.message}"));
  Logger.root.level = Level.INFO;
  Map argResults = _parseArgs(args);
  Map options = argResults['options'];
  List positionals = argResults['rest'];

  try { 
    if(options["in-uri"] == null)
      throw new ArgumentError("option: in-uri is required");

  } on ArgumentError catch(e) { 
    print(e);
    _usage();
  }
  // custom <schemadot main>

  Logger.root.level = Level.SHOUT;
  Completer completer = new Completer();
  Uri uri = Uri.parse(options['in-uri']);
  if(uri.scheme == 'http') {
    new HttpClient()
      .getUrl(uri)
      .then((HttpClientRequest request) => request.close())
      .then((HttpClientResponse response) =>
          response
          .transform(new convert.Utf8Decoder())
          .join())
      .then((text) {
        completer.complete(text);
      });
  } else {
    File target = new File(uri.toString());
    if(target.existsSync()) {
      completer.complete(target.readAsStringSync());
    }
    else {
      print('file does not exist');
    }
  }

  completer.future.then((schemaText) {
    Future schema = Schema.createSchema(convert.JSON.decode(schemaText));
    schema.then((schema) {
      String dot = createDot(schema);
      if(options['out-file'] != null) {
        new File(options['out-file']).writeAsStringSync(dot);
      } else {
        print(dot);
      }
    });

  });


  // end <schemadot main>

}

// custom <schemadot global>

// end <schemadot global>



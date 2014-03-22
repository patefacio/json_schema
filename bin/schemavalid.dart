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

Usage: schemavalid --schema INPUT_SCHEMA_URI --json INPUT_JSON_URI

Given an schema uri [schema] and json uri [json]
validate the json against the schema.

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
    _parser.addOption('schema', 
      defaultsTo: null,
      allowMultiple: false,
      abbr: 's',
      allowed: null);
    _parser.addOption('json', 
      defaultsTo: null,
      allowMultiple: false,
      abbr: 'j',
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

final _logger = new Logger("schemavalid");

main(List<String> args) { 
  Logger.root.onRecord.listen((LogRecord r) =>
      print("${r.loggerName} [${r.level}]:\t${r.message}"));
  Logger.root.level = Level.WARNING;
  Map argResults = _parseArgs(args);

  Map options = argResults['options'];
  List positionals = argResults['rest'];

  try { 
    if(options["schema"] == null)
      throw new ArgumentError("option: schema is required");

    if(options["json"] == null)
      throw new ArgumentError("option: json is required");

  } on ArgumentError catch(e) { 
    print(e);
    _usage();
  }
  // custom <schemadot main>

  String suri = options['schema'];
  Schema.createSchemaFromUrl(suri)
    .then((schema) {
      String juri = options['json'];
      File target = new File(juri);
      var json = convert.JSON.decode(target.readAsStringSync());

      print(schema.validate(json));
    });

  // end <schemadot main>

}

// custom <schemadot global>

// end <schemadot global>



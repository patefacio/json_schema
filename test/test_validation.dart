import "dart:io";
import "dart:json" as JSON;
import 'package:unittest/unittest.dart';
import "package:json_schema/json_schema.dart";
import "package:pathos/path.dart" as path;
import "package:logging/logging.dart";
import "package:logging_handlers/logging_handlers_shared.dart";

main() {

  ////////////////////////////////////////////////////////////////////////
  // Uncomment to see logging of excpetions
  //
  Logger.root.onRecord.listen(new PrintHandler());
  Logger.root.level = Level.FINE;
  logFormatExceptions = true;

  Options options = new Options();
  String here = path.dirname(path.absolute(options.script));
  Directory testSuiteFolder = 
    new Directory("${here}/JSON-Schema-Test-Suite/tests/draft4/invalidSchemas");

  testSuiteFolder = 
    new Directory("${here}/JSON-Schema-Test-Suite/tests/draft4");

  testSuiteFolder.listSync().forEach((testEntry) {
    if(testEntry is File) {
      group("Validations ${path.basename(testEntry.path)}", () {
        if(
                [
                  "additionalItems.json",
                  "additionalProperties.json",                  
                  "allOf.json",
                  "anyOf.json",
                  "dependencies.json",
                  "enum.json",
                  "items.json",
                  "maxItems.json",
                  "maxLength.json",
                  "maxProperties.json",
                  "maximum.json",
                  "minItems.json",
                  "minLength.json",
                  "minProperties.json",
                  "minimum.json",
                  "multipleOf.json",
                  "not.json",
                  "oneOf.json",
                  "pattern.json",
                  "patternProperties.json",
                  "properties.json",
                  "required.json",
                  "type.json",
                  "uniqueItems.json",
                  //"ref.json",
                  //"refRemote.json",
                  //"definitions.json",
                ].indexOf(path.basename(testEntry.path)) < 0) return;
        List tests = JSON.parse((testEntry as File).readAsStringSync());
        tests.forEach((testEntry) {
          var schemaData = testEntry["schema"];
          var description = testEntry["description"];
          List validationTests = testEntry["tests"];
          validationTests.forEach((validationTest) {
            String validationDescription = validationTest["description"];
            test("${description} : ${validationDescription}", () {
              var instance = validationTest["data"];
              bool expectedResult = validationTest["valid"];
              var schema = new Schema.fromMap(schemaData);
              var validator = new Validator(schema);
              bool result = validator.validate(instance);
              expect(result, expectedResult);
            });
          });
        });
      });
    }
  });

}
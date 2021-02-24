## 3.0.0

* Removed support for Dart 1

## 2.2.0

* Add note about root path in error string when instance path is empty
* Expose `ValidationError` class

## 2.1.4

* Use deep equality to compare maps, fixing equality when enums are present

## 2.1.3

* New `validateWithErrors` method on `JsonSchema` returns all validation errors as a list of objects
* `ValidationError` objects include both instance & schema paths for each error
* Error logic tweaked to provide consistent error paths in JSON pointer notation

## 2.0.0

* json_schema is no longer bound to dart:io and works in the browser!
* Full JSON Schema draft6 compatibility
* Much better $ref resolution, including deep nesting of $refs
* More typed keyword getters for draft6 like `examples`
* Syncronous schema evaluation by default
* Optional async evaluation and fetching with `createSchemaAsync`
* Automatic parsing of JSON strings passed to `createSchema` and `createSchemaAsync`
* Ability to do custom resolution of $refs with `RefProvider` and `RefProviderAsync`
* Optional parsing of JSON strings passed to `validate` with `parseJson = true`
* Dart 2.0 compatibility
* Many small changes to make things more in line with modern dart.
* Please see the [migration guide](./MIGRATION.md) for additional info.

## 1.0.8

* Code cleanup
* Strong mode
* Switch build tools to dart_dev

## 1.0.7

* Update dependency constraint on the `args` package.

## 1.0.3

* Add a dependency on the `args` package.

## 1.0.2

* Add a dependency on the `logging` package.

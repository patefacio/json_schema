// Copyright 2013-2018 Workiva Inc.
//
// Licensed under the Boost Software License (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.boost.org/LICENSE_1_0.txt
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// This software or document includes material copied from or derived
// from JSON-Schema-Test-Suite (https://github.com/json-schema-org/JSON-Schema-Test-Suite),
// Copyright (c) 2012 Julian Berman, which is licensed under the following terms:
//
//     Copyright (c) 2012 Julian Berman
//
//     Permission is hereby granted, free of charge, to any person obtaining a copy
//     of this software and associated documentation files (the "Software"), to deal
//     in the Software without restriction, including without limitation the rights
//     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//     copies of the Software, and to permit persons to whom the Software is
//     furnished to do so, subject to the following conditions:
//
//     The above copyright notice and this permission notice shall be included in
//     all copies or substantial portions of the Software.
//
//     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//     IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//     FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//     AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//     LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//     OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//     THE SOFTWARE.

import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path_lib;

import 'package:json_schema/src/json_schema/constants.dart';
import 'package:json_schema/src/json_schema/format_exceptions.dart';
import 'package:json_schema/src/json_schema/global_platform_functions.dart';
import 'package:json_schema/src/json_schema/schema_type.dart';
import 'package:json_schema/src/json_schema/type_validators.dart';
import 'package:json_schema/src/json_schema/utils.dart';
import 'package:json_schema/src/json_schema/validator.dart';
import 'package:json_schema/src/json_schema/typedefs.dart';

typedef dynamic SchemaPropertySetter(JsonSchema s, dynamic value);
typedef SchemaAssigner(JsonSchema s);
typedef SchemaAdder(JsonSchema s);
typedef Future<JsonSchema> AsyncRetrievalOperation();
typedef JsonSchema SyncRetrievalOperation();

class RetrievalRequest {
  Uri schemaUri;
  AsyncRetrievalOperation asyncRetrievalOperation;
  SyncRetrievalOperation syncRetrievalOperation;
}

/// Constructed with a json schema, either as string or Map. Validation of
/// the schema itself is done on construction. Any errors in the schema
/// result in a FormatException being thrown.
class JsonSchema {
  JsonSchema._fromMap(this._root, this._schemaMap, this._path, {JsonSchema parent}) {
    this._parent = parent;
    _initialize();
    _addSchemaToRefMap(path, this);
  }

  JsonSchema._fromBool(this._root, this._schemaBool, this._path, {JsonSchema parent}) {
    this._parent = parent;
    _initialize();
    _addSchemaToRefMap(path, this);
  }

  JsonSchema._fromRootMap(this._schemaMap, SchemaVersion schemaVersion,
      {Uri fetchedFromUri, bool isSync = false, RefProvider refProvider, RefProviderAsync refProviderAsync}) {
    _initialize(
        schemaVersion: schemaVersion,
        fetchedFromUri: fetchedFromUri,
        isSync: isSync,
        refProvider: refProvider,
        refProviderAsync: refProviderAsync);
  }

  JsonSchema._fromRootBool(this._schemaBool, SchemaVersion schemaVersion,
      {Uri fetchedFromUri, bool isSync = false, RefProvider refProvider, RefProviderAsync refProviderAsync}) {
    _initialize(
        schemaVersion: schemaVersion,
        fetchedFromUri: fetchedFromUri,
        isSync: isSync,
        refProvider: refProvider,
        refProviderAsync: refProviderAsync);
  }

  /// Create a schema from a JSON [data].
  ///
  /// This method is asynchronous to support automatic fetching of sub-[JsonSchema]s for items,
  /// properties, and sub-properties of the root schema.
  ///
  /// If you want to create a [JsonSchema] synchronously, use [createSchema]. Note that for
  /// [createSchema] remote reference fetching is not supported.
  ///
  /// The [schema] can either be a decoded JSON object (Only [Map] or [bool] per the spec),
  /// or alternatively, a [String] may be passed in and JSON decoding will be handled automatically.
  static Future<JsonSchema> createSchemaAsync(dynamic schema,
      {SchemaVersion schemaVersion, Uri fetchedFromUri, RefProviderAsync refProvider}) {
    // Default to assuming the schema is already a decoded, primitive dart object.
    dynamic data = schema;

    /// JSON Schemas must be [bool]s or [Map]s, so if we encounter a [String], we're looking at encoded JSON.
    /// https://json-schema.org/latest/json-schema-core.html#rfc.section.4.3.1
    if (schema is String) {
      try {
        data = json.decode(schema);
      } catch (e) {
        throw new ArgumentError('String data provided to createSchemaAsync is not valid JSON.');
      }
    }

    /// Set the Schema version before doing anything else, since almost everything depends on it.
    final version = _getSchemaVersion(schemaVersion, data);

    if (data is Map) {
      return new JsonSchema._fromRootMap(data, schemaVersion,
              fetchedFromUri: fetchedFromUri, refProviderAsync: refProvider)
          ._thisCompleter
          .future;

      // Boolean schemas are only supported in draft 6 and later.
    } else if (data is bool && version == SchemaVersion.draft6) {
      return new JsonSchema._fromRootBool(data, schemaVersion,
              fetchedFromUri: fetchedFromUri, refProviderAsync: refProvider)
          ._thisCompleter
          .future;
    }
    throw new ArgumentError(
        'Data provided to createSchemaAsync is not valid: Data must be, or parse to a Map (or bool in draft6 or later). | $data');
  }

  /// Create a schema from JSON [data].
  ///
  /// This method is synchronous, and doesn't support fetching of remote references, properties, and sub-properties of the
  /// schema. If you need remote reference support use [createSchemaAsync].
  ///
  /// The [schema] can either be a decoded JSON object (Only [Map] or [bool] per the spec),
  /// or alternatively, a [String] may be passed in and JSON decoding will be handled automatically.
  static JsonSchema createSchema(dynamic schema,
      {SchemaVersion schemaVersion, Uri fetchedFromUri, RefProvider refProvider}) {
    // Default to assuming the schema is already a decoded, primitive dart object.
    dynamic data = schema;

    /// JSON Schemas must be [bool]s or [Map]s, so if we encounter a [String], we're looking at encoded JSON.
    /// https://json-schema.org/latest/json-schema-core.html#rfc.section.4.3.1
    if (schema is String) {
      try {
        data = json.decode(schema);
      } catch (e) {
        throw new ArgumentError('String data provided to createSchema is not valid JSON.');
      }
    }

    /// Set the Schema version before doing anything else, since almost everything depends on it.
    final version = _getSchemaVersion(schemaVersion, data);

    if (data is Map) {
      return new JsonSchema._fromRootMap(data, schemaVersion,
              fetchedFromUri: fetchedFromUri, isSync: true, refProvider: refProvider)
          .resolvePath('#');

      // Boolean schemas are only supported in draft 6 and later.
    } else if (data is bool && version == SchemaVersion.draft6) {
      return new JsonSchema._fromRootBool(data, schemaVersion,
              fetchedFromUri: fetchedFromUri, isSync: true, refProvider: refProvider)
          .resolvePath('#');
    }
    throw new ArgumentError(
        'Data provided to createSchemaAsync is not valid: Data must be, or parse to a Map (or bool in draft6 or later). | $data');
  }

  /// Create a schema from a URL.
  ///
  /// This method is asyncronous to support automatic fetching of sub-[JsonSchema]s for items,
  /// properties, and sub-properties of the root schema.
  static Future<JsonSchema> createSchemaFromUrl(String schemaUrl, {SchemaVersion schemaVersion}) {
    if (globalCreateJsonSchemaFromUrl == null) {
      throw new StateError('no globalCreateJsonSchemaFromUrl defined!');
    }
    return globalCreateJsonSchemaFromUrl(schemaUrl, schemaVersion: schemaVersion);
  }

  /// Construct and validate a JsonSchema.
  _initialize(
      {SchemaVersion schemaVersion,
      Uri fetchedFromUri,
      bool isSync = false,
      RefProvider refProvider,
      RefProviderAsync refProviderAsync}) {
    if (_root == null) {
      /// Set the Schema version before doing anything else, since almost everything depends on it.
      final version = _getSchemaVersion(schemaVersion, this._schemaMap);

      _root = this;
      _isSync = isSync;
      _refProvider = refProvider;
      _refProviderAsync = refProviderAsync;
      _schemaVersion = version;
      _fetchedFromUri = fetchedFromUri;
      try {
        _fetchedFromUriBase = JsonSchemaUtils.getBaseFromFullUri(_fetchedFromUri);
      } catch (e) {
        // ID base can't be set for schemes other than HTTP(S).
        // This is expected behavior.
      }
      _path = '#';
      _addSchemaToRefMap('#', this);
      _thisCompleter = new Completer<JsonSchema>();
    } else {
      _isSync = _root._isSync;
      _refProvider = _root._refProvider;
      _refProviderAsync = _root._refProviderAsync;
      _schemaVersion = _root.schemaVersion;
      _schemaRefs = _root._schemaRefs;
      _refMap = _root._refMap;
      _freeFormMap = _root._freeFormMap;
      _thisCompleter = _root._thisCompleter;
      _schemaAssignments = _root._schemaAssignments;
    }

    if (_root._isSync) {
      _validateSchemaSync();
      if (_root == this) {
        _thisCompleter.complete(this);
      }
    } else {
      _validateSchemaAsync();
    }
  }

  /// Calculate, validate and set all properties defined in the JSON Schema spec.
  ///
  /// Doesn't validate interdependent properties. See [_validateInterdependentProperties]
  void _validateAndSetIndividualProperties() {
    var accessMap;
    // Set the access map based on features used in the currently set version.
    if (_root.schemaVersion == SchemaVersion.draft4) {
      accessMap = _accessMapV4;
    } else {
      accessMap = _accessMapV6;
    }

    // Iterate over all string keys of the root JSON Schema Map. Calculate, validate and
    // set all properties according to spec.
    _schemaMap.forEach((k, v) {
      /// Get the _set<X> method from the [accessMap] based on the [Map] string key.
      final SchemaPropertySetter accessor = accessMap[k];
      if (accessor != null) {
        accessor(this, v);
      } else {
        // Attempt to create a schema out of the property and register the ref, but don't error if it's not a valid schema.
        _makeSchema('$_path/$k', v, (rhs) => _refMap[k] = rhs, mustBeValid: false);
        // Add the prop to the free form map just in case.
        _freeFormMap[path_lib.join(_path, JsonSchemaUtils.normalizePath(k))] = v;
      }
    });
  }

  void _validateInterdependentProperties() {
    // Check that a minimum is set if both exclusiveMinimum and minimum properties are set.
    if (_exclusiveMinimum != null && _minimum == null)
      throw FormatExceptions.error('exclusiveMinimum requires minimum');

    // Check that a minimum is set if both exclusiveMaximum and maximum properties are set.
    if (_exclusiveMaximum != null && _maximum == null)
      throw FormatExceptions.error('exclusiveMaximum requires maximum');
  }

  /// Validate, calculate and set all properties on the [JsonSchema], included properties
  /// that have interdependencies.
  void _validateAndSetAllProperties() {
    _validateAndSetIndividualProperties();

    // Interdependent properties were removed in draft6.
    if (schemaVersion == SchemaVersion.draft4) {
      _validateInterdependentProperties();
    }
  }

  void _baseResolvePaths() {
    if (_root == this) {
      _schemaAssignments.forEach((assignment) => assignment());

      // filter out requests that can be resolved locally.
      final List<RetrievalRequest> requestsToRemove = [];
      for (final retrievalRequest in _retrievalRequests) {
        JsonSchema localSchema;
        // check if the ref is actually a standard schema definition, resolve it locally.
        if (SchemaVersion.fromString(retrievalRequest.schemaUri.toString()) != null) {
          final definitionRef = retrievalRequest.schemaUri.toString();
          localSchema = JsonSchema.createSchema(getJsonSchemaDefinitionByRef(definitionRef));
          _addSchemaToRefMap(retrievalRequest.schemaUri.toString(), localSchema);
        } else {
          // attempt to get the schema from the existing schema cache.
          try {
            localSchema = _getSchemaFromPath(retrievalRequest.schemaUri.toString());
          } catch (e) {
            // DO NOTHING: if we couldn't resolve the path locally,
            // it just means we need to make a request after all
          }
        }
        if (localSchema != null) {
          requestsToRemove.add(retrievalRequest);
        }
      }
      requestsToRemove.forEach((request) => _retrievalRequests.remove(request));
    }
  }

  /// Check for refs that need to be fetched, fetch them, and return the final [JsonSchema].
  void _resolveAllPathsAsync() {
    _baseResolvePaths();

    if (_root == this) {
      if (_retrievalRequests.isNotEmpty) {
        Future.wait(_retrievalRequests.map((r) => r.asyncRetrievalOperation()))
            .then((_) => _thisCompleter.complete(_getSchemaFromPath('#')));
      } else {
        _thisCompleter.complete(_getSchemaFromPath('#'));
      }
      // _logger.info('Marked $_path complete'); TODO: re-add logger
    }
  }

  /// Check for refs that need to be fetched, fetch them, and return the final [JsonSchema].
  void _resolveAllPathsSync() {
    _baseResolvePaths();

    if (_root == this) {
      // If a ref provider is specified, use it and remove the corresponding retrieval request if
      // the provider returns a result.
      if (_refProvider != null) {
        final completedRequests = [];
        _retrievalRequests.forEach((r) {
          if (r.syncRetrievalOperation != null) {
            final schema = r.syncRetrievalOperation();
            schema != null ? completedRequests.add(r) : null;
          }
        });
        completedRequests.forEach((c) => _retrievalRequests.remove(c));
      }

      // Throw an error if there are any remaining retrieval requests the ref provider couldn't resolve.
      if (_retrievalRequests.isNotEmpty) {
        throw FormatExceptions.error(
            'When resolving schemas synchronously, all remote refs must be resolvable via a RefProvider. Found ${_retrievalRequests.length} unresolvable request(s): ${_retrievalRequests.map((r) => r.schemaUri).join(',')}');
      }
    }
  }

  void _validateSchemaBase() {
    // _logger.info('Validating schema $_path'); TODO: re-add logger

    _registerSchemaRef(_path, _schemaMap);

    if (_isRemoteRef(_schemaMap)) {
      // _logger.info('Top level schema is ref: $_schemaRefs'); TODO: re-add logger
    }

    _validateAndSetAllProperties();
  }

  /// Validate that a given [JsonSchema] conforms to the official JSON Schema spec.
  void _validateSchemaAsync() {
    _validateSchemaBase();
    _resolveAllPathsAsync();

    // _logger.info('Completed Validating schema $_path'); TODO: re-add logger
  }

  /// Validate that a given [JsonSchema] conforms to the official JSON Schema spec.
  void _validateSchemaSync() {
    _validateSchemaBase();
    _resolveAllPathsSync();

    // _logger.info('Completed Validating schema $_path'); TODO: re-add logger
  }

  /// Given a path, find the ref'd [JsonSchema] from the map.
  JsonSchema _getSchemaFromPath(String original) {
    final String path = endPath(original);
    final JsonSchema result = _refMap[path];

    if (result == null) {
      final schema = _freeFormMap[path];
      if (schema is! Map) throw FormatExceptions.schema('free-form property $original at $path', schema);
      return new JsonSchema._fromMap(_root, schema, path);
    }
    return result;
  }

  /// Create a sub-schema inside the root, using either a directly nested schema, or a definition.
  JsonSchema _createSubSchema(dynamic schemaDefinition, String path) {
    assert(!_schemaRefs.containsKey(path));
    assert(!_refMap.containsKey(path));

    if (schemaDefinition is Map) {
      return new JsonSchema._fromMap(_root, schemaDefinition, path, parent: this);

      // Boolean schemas are only supported in draft 6 and later.
    } else if (schemaDefinition is bool && schemaVersion == SchemaVersion.draft6) {
      return new JsonSchema._fromBool(_root, schemaDefinition, path, parent: this);
    }
    throw new ArgumentError(
        'Data provided to createSubSchema is not valid: Must be a Map (or bool in draft6 or later). | ${schemaDefinition}');
  }

  // --------------------------------------------------------------------------
  // Root Schema Fields
  // --------------------------------------------------------------------------

  /// The root [JsonSchema] for this [JsonSchema].
  JsonSchema _root;

  /// The parent [JsonSchema] for this [JsonSchema].
  JsonSchema _parent;

  /// JSON of the [JsonSchema] as a [Map]. Only this value or [_schemaBool] should be set, not both.
  Map<String, dynamic> _schemaMap = {};

  /// JSON of the [JsonSchema] as a [bool]. Only this value or [_schemaMap] should be set, not both.
  bool _schemaBool;

  /// JSON Schema version string.
  SchemaVersion _schemaVersion;

  /// Remote [Uri] the [JsonSchema] was fetched from, if any.
  Uri _fetchedFromUri;

  /// Base of the remote [Uri] the [JsonSchema] was fetched from, if any.
  Uri _fetchedFromUriBase;

  /// A [List<JsonSchema>] which the value must conform to all of.
  List<JsonSchema> _allOf = [];

  /// A [List<JsonSchema>] which the value must conform to at least one of.
  List<JsonSchema> _anyOf = [];

  /// Whether or not const is set, we need this since const can be null and valid.
  bool _hasConst = false;

  /// A value which the [JsonSchema] instance must exactly conform to.
  dynamic _constValue;

  /// Default value of the [JsonSchema].
  dynamic _defaultValue;

  /// Included [JsonSchema] definitions.
  Map<String, JsonSchema> _definitions = {};

  /// Description of the [JsonSchema].
  String _description;

  /// Possible values of the [JsonSchema].
  List _enumValues = [];

  /// Example values for the given schema.
  List _examples = [];

  /// Whether the maximum of the [JsonSchema] is exclusive.
  bool _exclusiveMaximum;

  /// Whether the maximum of the [JsonSchema] is exclusive.
  num _exclusiveMaximumV6;

  /// Whether the minumum of the [JsonSchema] is exclusive.
  bool _exclusiveMinimum;

  /// Whether the minumum of the [JsonSchema] is exclusive.
  num _exclusiveMinimumV6;

  /// Pre-defined format (i.e. date-time, email, etc) of the [JsonSchema] value.
  String _format;

  /// ID of the [JsonSchema].
  Uri _id;

  /// Base URI of the ID. All sub-schemas are resolved against this
  Uri _idBase;

  /// Maximum value of the [JsonSchema] value.
  num _maximum;

  /// Minimum value of the [JsonSchema] value.
  num _minimum;

  /// Maximum value of the [JsonSchema] value.
  int _maxLength;

  /// Minimum length of the [JsonSchema] value.
  int _minLength;

  /// The number which the value of the [JsonSchema] must be a multiple of.
  num _multipleOf;

  /// A [JsonSchema] which the value must NOT be.
  JsonSchema _notSchema;

  /// A [List<JsonSchema>] which the value must conform to at least one of.
  List<JsonSchema> _oneOf = [];

  /// The regular expression the [JsonSchema] value must conform to.
  RegExp _pattern;

  /// Ref to the URI of the [JsonSchema].
  Uri _ref;

  /// The path of the [JsonSchema] within the root [JsonSchema].
  String _path;

  /// Title of the [JsonSchema].
  String _title;

  /// List of allowable types for the [JsonSchema].
  List<SchemaType> _typeList;

  // --------------------------------------------------------------------------
  // Schema List Item Related Fields
  // --------------------------------------------------------------------------

  /// [JsonSchema] definition used to validate items of this schema.
  JsonSchema _items;

  /// List of [JsonSchema] used to validate items of this schema.
  List<JsonSchema> _itemsList;

  /// Whether additional items are allowed.
  bool _additionalItemsBool;

  /// [JsonSchema] additionalItems should conform to.
  JsonSchema _additionalItemsSchema;

  /// [JsonSchema] definition that at least one item must match to be valid.
  JsonSchema _contains;

  /// Maimum number of items allowed.
  int _maxItems;

  /// Maimum number of items allowed.
  int _minItems;

  /// Whether the items in the list must be unique.
  bool _uniqueItems = false;

  // --------------------------------------------------------------------------
  // Schema Sub-Property Related Fields
  // --------------------------------------------------------------------------

  /// Map of [JsonSchema]s by property key.
  Map<String, JsonSchema> _properties = {};

  /// [JsonSchema] that property names must conform to.
  JsonSchema _propertyNamesSchema;

  /// Whether additional properties, other than those specified, are allowed.
  bool _additionalProperties;

  /// [JsonSchema] that additional properties must conform to.
  JsonSchema _additionalPropertiesSchema;

  Map<String, List<String>> _propertyDependencies = {};

  Map<String, JsonSchema> _schemaDependencies = {};

  /// The maximum number of properties allowed.
  int _maxProperties;

  /// The minimum number of properties allowed.
  int _minProperties = 0;

  /// Map of [JsonSchema]s for properties, based on [RegExp]s keys.
  Map<RegExp, JsonSchema> _patternProperties = {};

  Map<String, JsonSchema> _refMap = {};

  /// List if properties that are required for the [JsonSchema] instance to be valid.
  List<String> _requiredProperties;

  // --------------------------------------------------------------------------
  // Implementation Specific Feilds
  // --------------------------------------------------------------------------

  /// Maps any unsupported top level property to its original value
  Map<String, dynamic> _freeFormMap = {};

  /// Set of strings to gaurd against path cycles
  Set<String> _pathsEncountered = new Set();

  /// HTTP(S) requests to fetch ref'd schemas.
  List<RetrievalRequest> _retrievalRequests = [];

  /// Assignments to call for resolution upon end of parse.
  List _schemaAssignments = [];

  /// For schemas with $ref maps, path of schema to $ref path
  Map<String, String> _schemaRefs = {};

  /// Completer that fires when [this] [JsonSchema] has finished building.
  Completer<JsonSchema> _thisCompleter = new Completer<JsonSchema>();

  bool _isSync = false;

  /// Synchronous ref provider used to resolve remote references in a given [JsonSchema].
  ///
  /// Note: only one ref provider should be passed in, sync or async.
  ///
  /// If [isSync] is true and a synchronous ref provided is specified: the synchronous provider will be used.
  /// If [isSync] is true and no ref provider is specified: remote refs in a schema will cause an error to be thrown.
  /// If [isSync] is false and an async ref provider is specified : the async ref provider will be used.
  /// If [isSync] is false and no ref provider is specified: the default HTTP(S) ref provider will be used.
  RefProvider _refProvider;

  /// Asynchronous ref provider used to resolve remote references in a given [JsonSchema].
  ///
  /// Note: only one ref provider should be passed in, sync or async.
  ///
  /// If [isSync] is true and a synchronous ref provided is specified: the synchronous provider will be used.
  /// If [isSync] is true and no ref provider is specified: remote refs in a schema will cause an error to be thrown.
  /// If [isSync] is false and an async ref provider is specified : the async ref provider will be used.
  /// If [isSync] is false and no ref provider is specified: the default HTTP(S) ref provider will be used.
  RefProviderAsync _refProviderAsync;

  /// Shared keywords across all versions of JSON Schema.
  static Map<String, SchemaPropertySetter> _baseAccessMap = {
    // Root Schema Properties
    'allOf': (JsonSchema s, dynamic v) => s._setAllOf(v),
    'anyOf': (JsonSchema s, dynamic v) => s._setAnyOf(v),
    'default': (JsonSchema s, dynamic v) => s._setDefault(v),
    'definitions': (JsonSchema s, dynamic v) => s._setDefinitions(v),
    'description': (JsonSchema s, dynamic v) => s._setDescription(v),
    'enum': (JsonSchema s, dynamic v) => s._setEnum(v),
    'format': (JsonSchema s, dynamic v) => s._setFormat(v),
    'maximum': (JsonSchema s, dynamic v) => s._setMaximum(v),
    'minimum': (JsonSchema s, dynamic v) => s._setMinimum(v),
    'maxLength': (JsonSchema s, dynamic v) => s._setMaxLength(v),
    'minLength': (JsonSchema s, dynamic v) => s._setMinLength(v),
    'multipleOf': (JsonSchema s, dynamic v) => s._setMultipleOf(v),
    'not': (JsonSchema s, dynamic v) => s._setNot(v),
    'oneOf': (JsonSchema s, dynamic v) => s._setOneOf(v),
    'pattern': (JsonSchema s, dynamic v) => s._setPattern(v),
    '\$ref': (JsonSchema s, dynamic v) => s._setRef(v),
    'title': (JsonSchema s, dynamic v) => s._setTitle(v),
    'type': (JsonSchema s, dynamic v) => s._setType(v),
    // Schema List Item Related Fields
    'items': (JsonSchema s, dynamic v) => s._setItems(v),
    'additionalItems': (JsonSchema s, dynamic v) => s._setAdditionalItems(v),
    'maxItems': (JsonSchema s, dynamic v) => s._setMaxItems(v),
    'minItems': (JsonSchema s, dynamic v) => s._setMinItems(v),
    'uniqueItems': (JsonSchema s, dynamic v) => s._setUniqueItems(v),
    // Schema Sub-Property Related Fields
    'properties': (JsonSchema s, dynamic v) => s._setProperties(v),
    'additionalProperties': (JsonSchema s, dynamic v) => s._setAdditionalProperties(v),
    'dependencies': (JsonSchema s, dynamic v) => s._setDependencies(v),
    'maxProperties': (JsonSchema s, dynamic v) => s._setMaxProperties(v),
    'minProperties': (JsonSchema s, dynamic v) => s._setMinProperties(v),
    'patternProperties': (JsonSchema s, dynamic v) => s._setPatternProperties(v),
  };

  /// Map to allow getters to be accessed by String key.
  static Map<String, SchemaPropertySetter> _accessMapV4 = new Map<String, SchemaPropertySetter>()
    ..addAll(_baseAccessMap)
    ..addAll({
      // Add properties that are changed incompatibly later.
      'exclusiveMaximum': (JsonSchema s, dynamic v) => s._setExclusiveMaximum(v),
      'exclusiveMinimum': (JsonSchema s, dynamic v) => s._setExclusiveMinimum(v),
      'id': (JsonSchema s, dynamic v) => s._setId(v),
      'required': (JsonSchema s, dynamic v) => s._setRequired(v),
    });

  static Map<String, SchemaPropertySetter> _accessMapV6 = new Map<String, SchemaPropertySetter>()
    ..addAll(_baseAccessMap)
    ..addAll({
      // Note: see http://json-schema.org/draft-06/json-schema-release-notes.html

      // Added in draft6
      'const': (JsonSchema s, dynamic v) => s._setConst(v),
      'contains': (JsonSchema s, dynamic v) => s._setContains(v),
      'examples': (JsonSchema s, dynamic v) => s._setExamples(v),
      'propertyNames': (JsonSchema s, dynamic v) => s._setPropertyNames(v),
      // changed (imcompatible) in draft6
      'exclusiveMaximum': (JsonSchema s, dynamic v) => s._setExclusiveMaximumV6(v),
      'exclusiveMinimum': (JsonSchema s, dynamic v) => s._setExclusiveMinimumV6(v),
      '\$id': (JsonSchema s, dynamic v) => s._setId(v),
      'required': (JsonSchema s, dynamic v) => s._setRequiredV6(v),
    });

  /// Get a nested [JsonSchema] from a path.
  JsonSchema resolvePath(String path) => _getSchemaFromPath(path);

  @override
  bool operator ==(dynamic other) =>
      other is JsonSchema && new DeepCollectionEquality().equals(schemaMap, other.schemaMap);

  @override
  int get hashCode => new DeepCollectionEquality().hash(schemaMap);

  @override
  String toString() => '${_schemaMap}';

  // --------------------------------------------------------------------------
  // Root Schema Getters
  // --------------------------------------------------------------------------

  /// The root [JsonSchema] for this [JsonSchema].
  JsonSchema get root => _root;

  /// The parent [JsonSchema] for this [JsonSchema].
  JsonSchema get parent => _parent;

  /// Get the anchestry of the current schema, up to the root [JsonSchema].
  List<JsonSchema> get _parents {
    final parents = <JsonSchema>[];

    var circularRefEscapeHatch = 0;
    var nextParent = this._parent;
    while (nextParent != null && circularRefEscapeHatch < 100) {
      circularRefEscapeHatch += 1;
      parents.add(nextParent);

      nextParent = nextParent._parent;
    }

    return parents;
  }

  /// JSON of the [JsonSchema] as a [Map]. Only this value or [_schemaBool] should be set, not both.
  Map get schemaMap => _schemaMap;

  /// JSON of the [JsonSchema] as a [bool]. Only this value or [_schemaMap] should be set, not both.
  bool get schemaBool => _schemaBool;

  /// JSON string represenatation of the schema.
  String toJson() => json.encode(_schemaMap ?? _schemaBool);

  /// JSON Schema version used.
  ///
  /// Note: Only one version can be used for a nested [JsonScehema] object.
  /// Default: [SchemaVersion.draft6]
  SchemaVersion get schemaVersion => _root._schemaVersion ?? SchemaVersion.draft6;

  /// Base [Uri] of the [JsonSchema] based on $id, or where it was fetched from, in that order, if any.
  Uri get _uriBase => _idBase ?? _fetchedFromUriBase;

  /// [Uri] from the first ancestor with an ID
  Uri get _inheritedUriBase {
    for (final parent in _parents) {
      if (parent._uriBase != null) {
        return parent._uriBase;
      }
    }

    return root._uriBase;
  }

  /// [Uri] of the [JsonSchema] based on $id, or where it was fetched from, in that order, if any.
  Uri get _uri => ((_id ?? _fetchedFromUri)?.removeFragment());

  /// [Uri] from the first ancestor with an ID
  Uri get _inheritedUri {
    for (final parent in _parents) {
      if (parent._uri != null) {
        return parent._uri;
      }
    }

    return root._uri;
  }

  /// Whether or not const is set, we need this since const can be null and valid.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.24
  bool get hasConst => _hasConst;

  /// Const value of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.24
  dynamic get constValue => _constValue;

  /// Default value of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.3
  dynamic get defaultValue => _defaultValue;

  /// Included [JsonSchema] definitions.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.1
  Map<String, JsonSchema> get definitions => _definitions;

  /// Description of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.2
  String get description => _description;

  /// Possible values of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.23
  List get enumValues => _enumValues;

  /// The value of the exclusiveMaximum for the [JsonSchema], if any exists.
  num get exclusiveMaximum {
    // If we're on draft6, the property contains the value, return it.
    if (schemaVersion == SchemaVersion.draft6) {
      return _exclusiveMaximumV6;

      // If we're on draft4, the property is a bool, so return the max instead.
    } else {
      if (hasExclusiveMaximum) {
        return _maximum;
      }
    }
    return null;
  }

  /// Whether the maximum of the [JsonSchema] is exclusive.
  bool get hasExclusiveMaximum => _exclusiveMaximum ?? _exclusiveMaximumV6 != null;

  /// The value of the exclusiveMaximum for the [JsonSchema], if any exists.
  num get exclusiveMinimum {
    // If we're on draft6, the property contains the value, return it.
    if (schemaVersion == SchemaVersion.draft6) {
      return _exclusiveMinimumV6;

      // If we're on draft4, the property is a bool, so return the min instead.
    } else {
      if (hasExclusiveMinimum) {
        return _minimum;
      }
    }
    return null;
  }

  /// Whether the minimum of the [JsonSchema] is exclusive.
  bool get hasExclusiveMinimum => _exclusiveMinimum ?? _exclusiveMinimumV6 != null;

  /// Pre-defined format (i.e. date-time, email, etc) of the [JsonSchema] value.
  String get format => _format;

  /// ID of the [JsonSchema].
  Uri get id => _id;

  /// ID from the first ancestor with an ID
  Uri get _inheritedId {
    for (final parent in _parents) {
      if (parent.id != null) {
        return parent.id;
      }
    }

    return root.id;
  }

  /// Maximum value of the [JsonSchema] value.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.2
  num get maximum => _maximum;

  /// Minimum value of the [JsonSchema] value.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.4
  num get minimum => _minimum;

  /// Maximum length of the [JsonSchema] value.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.6
  int get maxLength => _maxLength;

  /// Minimum length of the [JsonSchema] value.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.7
  int get minLength => _minLength;

  /// The number which the value of the [JsonSchema] must be a multiple of.
  ///
  /// Reference: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.1
  num get multipleOf => _multipleOf;

  /// The path of the [JsonSchema] within the root [JsonSchema].
  String get path => _path;

  /// The regular expression the [JsonSchema] value must conform to.
  ///
  /// Refernce:
  RegExp get pattern => _pattern;

  /// A [List<JsonSchema>] which the value must conform to all of.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.26
  List<JsonSchema> get allOf => _allOf;

  /// A [List<JsonSchema>] which the value must conform to at least one of.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.27
  List<JsonSchema> get anyOf => _anyOf;

  /// A [List<JsonSchema>] which the value must conform to at least one of.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.28
  List<JsonSchema> get oneOf => _oneOf;

  /// A [JsonSchema] which the value must NOT be.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.29
  JsonSchema get notSchema => _notSchema;

  /// Ref to the URI of the [JsonSchema].
  Uri get ref => _ref;

  /// Title of the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.2
  String get title => _title;

  /// List of allowable types for the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.25
  List<SchemaType> get typeList => _typeList;

  /// Single allowable type for the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.25
  SchemaType get type => _typeList.length == 1 ? _typeList.single : null;

  // --------------------------------------------------------------------------
  // Schema List Item Related Getters
  // --------------------------------------------------------------------------

  /// Single [JsonSchema] sub items of this [JsonSchema] must conform to.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.9
  JsonSchema get items => _items;

  /// Ordered list of [JsonSchema] which the value of the same index must conform to.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.9
  List<JsonSchema> get itemsList => _itemsList;

  /// Whether additional items are allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.10
  bool get additionalItemsBool => _additionalItemsBool;

  /// JsonSchema additional items should conform to.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.10
  JsonSchema get additionalItemsSchema => _additionalItemsSchema;

  /// List of example instances for the [JsonSchema].
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-7.4
  List get examples => defaultValue != null
      ? ([]
        ..addAll(_examples)
        ..add(defaultValue))
      : _examples;

  /// The maximum number of items allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.11
  int get maxItems => _maxItems;

  /// The minimum number of items allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.12
  int get minItems => _minItems;

  /// Whether the items in the list must be unique.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.13
  bool get uniqueItems => _uniqueItems;

  // --------------------------------------------------------------------------
  // Schema Sub-Property Related Getters
  // --------------------------------------------------------------------------

  /// Map of [JsonSchema]s for properties, by [String] key.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.18
  Map<String, JsonSchema> get properties => _properties;

  /// [JsonSchema] that property names must conform to.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.22
  JsonSchema get propertyNamesSchema => _propertyNamesSchema;

  /// Whether additional properties, other than those specified, are allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.20
  bool get additionalPropertiesBool => _additionalProperties;

  /// [JsonSchema] that additional properties must conform to.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.20
  JsonSchema get additionalPropertiesSchema => _additionalPropertiesSchema;

  /// [JsonSchema] definition that at least one item must match to be valid.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.14
  JsonSchema get contains => _contains;

  /// The maximum number of properties allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.15
  int get maxProperties => _maxProperties;

  /// The minimum number of properties allowed.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.16
  int get minProperties => _minProperties;

  /// Map of [JsonSchema]s for properties, based on [RegExp]s keys.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.19
  Map<RegExp, JsonSchema> get patternProperties => _patternProperties;

  /// Map of property dependencies by property name.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.21
  Map<String, List<String>> get propertyDependencies => _propertyDependencies;

  /// Map of sub-properties' and references' [JsonSchema]s by path.
  ///
  /// Note: This is useful for drawing dependency graphs, etc, but should not be used for general
  /// validation or traversal. Use [endPath] to get the absolute [String] path and [resolvePath]
  /// to get the [JsonSchema] at any path, instead.
  @Deprecated('''
Note: This information is useful for drawing dependency graphs, etc, but should not be used for general
validation or traversal. Use [endPath] to get the absolute [String] path and [resolvePath]
to get the [JsonSchema] at any path, instead.

This functionality will be removed in 3.0.
  ''')
  Map<String, JsonSchema> get refMap => _refMap;

  /// Properties that must be inclueded for the [JsonSchema] to be valid.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.17
  List<String> get requiredProperties => _requiredProperties;

  /// Map of schema dependencies by property name.
  ///
  /// Spec: https://tools.ietf.org/html/draft-wright-json-schema-validation-01#section-6.21
  Map<String, JsonSchema> get schemaDependencies => _schemaDependencies;

  // --------------------------------------------------------------------------
  // Convenience Methods
  // --------------------------------------------------------------------------

  /// Given a path within the schema, follow all references to an end path pointing to a [JsonSchema].
  String endPath(String path) {
    _pathsEncountered.clear();
    return _endPath(path);
  }

  /// Recursive inner-function for [endPath].
  String _endPath(String path) {
    // TODO: We probably shouldn't throw here, and properly support cyclical schemas, since they
    // are allowed in the spec.
    if (_pathsEncountered.contains(path))
      throw FormatExceptions.error('Encountered path cycle ${_pathsEncountered}, adding $path');

    final referredTo = _schemaRefs[path];
    if (referredTo == null) {
      return path;
    } else {
      _pathsEncountered.add(path);
      return _endPath(referredTo);
    }
  }

  /// Name of the property of the current [JsonSchema] within its parent.
  String get propertyName {
    final pathUri = Uri.parse(path);
    final pathFragments = pathUri.fragment?.split('/');
    return pathFragments.length > 2 ? pathFragments.last : null;
  }

  /// Whether a given property is required for the [JsonSchema] instance to be valid.
  bool propertyRequired(String property) => _requiredProperties != null && _requiredProperties.contains(property);

  /// Whether the [JsonSchema] is required on its parent.
  bool get requiredOnParent => _parent?.propertyRequired(propertyName) ?? false;

  /// Validate [instance] against this schema, returning a boolean indicating whether
  /// validation succeeded or failed.
  bool validate(dynamic instance, {bool reportMultipleErrors = false, bool parseJson = false}) =>
      new Validator(this).validate(instance, reportMultipleErrors: reportMultipleErrors, parseJson: parseJson);

  /// Validate [instance] against this schema, returning a list of [ValidationError]
  /// objects with information about any validation errors that occurred.
  List<ValidationError> validateWithErrors(dynamic instance, {bool parseJson = false}) {
    final validator = new Validator(this);
    validator.validate(instance, reportMultipleErrors: true, parseJson: parseJson);
    return validator.errorObjects;
  }

  // --------------------------------------------------------------------------
  // JSON Schema Internal Operations
  // --------------------------------------------------------------------------

  /// Function to determine whether a given [schemaDefinition] is a remote $ref.
  bool _isRemoteRef(dynamic schemaDefinition) {
    Map schemaDefinitionMap;
    try {
      schemaDefinitionMap = TypeValidators.object('NA', schemaDefinition);
    } catch (e) {
      // If the schema definition isn't an object, return early, since it can't be a ref.
      return false;
    }

    final dynamic ref = schemaDefinitionMap[r'$ref'];
    if (ref != null) {
      TypeValidators.nonEmptyString(r'$ref', ref);
      // If the ref begins with "#" it is a local ref, so we return false.
      if (ref[0] != '#') return false;
      return true;
    }
    return false;
  }

  /// Checks if a [schemaDefinition] has a $ref.
  /// If it does, it adds the $ref to [_schemaRefs] at the path key and returns true.
  void _registerSchemaRef(String path, dynamic schemaDefinition) {
    if (_isRemoteRef(schemaDefinition)) {
      final schemaDefinitionMap = TypeValidators.object(path, schemaDefinition);
      final ref = schemaDefinitionMap[r'$ref'];
      // _logger.info('Linking $path to $ref'); TODO: re-add logger
      _schemaRefs[path] = ref;
    }
  }

  /// Add a ref'd JsonSchema to the map of available Schemas.
  JsonSchema _addSchemaToRefMap(String path, JsonSchema schema) => _refMap[path] = schema;

  // Create a [JsonSchema] from a sub-schema of the root.
  _makeSchema(String path, dynamic schema, SchemaAssigner assigner, {mustBeValid: true}) {
    var throwError;

    if (schema is bool && schemaVersion != SchemaVersion.draft6)
      throwError = () => throw FormatExceptions.schema(path, schema);
    if (schema is! Map && schema is! bool) throwError = () => throw FormatExceptions.schema(path, schema);

    if (throwError != null) {
      if (mustBeValid) throwError();
      return;
    }

    _registerSchemaRef(path, schema);

    final isRemoteReference = _isRemoteRef(schema);

    /// If this sub-schema is a ref within the root schema,
    /// add it to the map of local schema assignments.
    /// Otherwise, call the assigner function and create a new [JsonSchema].
    if (isRemoteReference) {
      _schemaAssignments.add(() => assigner(_getSchemaFromPath(path)));
    } else {
      assigner(_createSubSchema(schema, path));
    }
  }

  // --------------------------------------------------------------------------
  // Internal Property Validators
  // --------------------------------------------------------------------------

  _validateListOfSchema(String key, dynamic value, SchemaAdder schemaAdder) {
    TypeValidators.nonEmptyList(key, value);
    for (int i = 0; i < value.length; i++) {
      _makeSchema('$_path/$key/$i', value[i], (rhs) => schemaAdder(rhs));
    }
  }

  // --------------------------------------------------------------------------
  // Root Schema Property Setters
  // --------------------------------------------------------------------------

  /// Validate, calculate and set the value of the 'allOf' JSON Schema prop.
  _setAllOf(dynamic value) => _validateListOfSchema('allOf', value, (schema) => _allOf.add(schema));

  /// Validate, calculate and set the value of the 'anyOf' JSON Schema prop.
  _setAnyOf(dynamic value) => _validateListOfSchema('anyOf', value, (schema) => _anyOf.add(schema));

  /// Validate, calculate and set the value of the 'const' JSON Schema prop.
  _setConst(dynamic value) {
    _hasConst = true;
    _constValue = value; // Any value is valid for const, even null.
  }

  /// Validate, calculate and set the value of the 'defaultValue' JSON Schema prop.
  _setDefault(dynamic value) => _defaultValue = value;

  /// Validate, calculate and set the value of the 'definitions' JSON Schema prop.
  _setDefinitions(dynamic value) => (TypeValidators.object('definition', value))
      .forEach((k, v) => _makeSchema('$_path/definitions/$k', v, (rhs) => _definitions[k] = rhs));

  /// Validate, calculate and set the value of the 'description' JSON Schema prop.
  _setDescription(dynamic value) => _description = TypeValidators.string('description', value);

  /// Validate, calculate and set the value of the 'enum' JSON Schema prop.
  _setEnum(dynamic value) => _enumValues = TypeValidators.uniqueList('enum', value);

  /// Validate, calculate and set the value of the 'exclusiveMaximum' JSON Schema prop.
  _setExclusiveMaximum(dynamic value) => _exclusiveMaximum = TypeValidators.boolean('exclusiveMaximum', value);

  /// Validate, calculate and set the value of the 'exclusiveMaximum' JSON Schema prop.
  _setExclusiveMaximumV6(dynamic value) => _exclusiveMaximumV6 = TypeValidators.number('exclusiveMaximum', value);

  /// Validate, calculate and set the value of the 'exclusiveMinimum' JSON Schema prop.
  _setExclusiveMinimum(dynamic value) => _exclusiveMinimum = TypeValidators.boolean('exclusiveMinimum', value);

  /// Validate, calculate and set the value of the 'exclusiveMinimum' JSON Schema prop.
  _setExclusiveMinimumV6(dynamic value) => _exclusiveMinimumV6 = TypeValidators.number('exclusiveMinimum', value);

  /// Validate, calculate and set the value of the 'format' JSON Schema prop.
  _setFormat(dynamic value) => _format = TypeValidators.string('format', value);

  /// Validate, calculate and set the value of the 'id' JSON Schema prop.
  _setId(dynamic value) {
    // First, just add the ref directly, as a fallback, and in case the ID has its own
    // unique origin (i.e. http://example1.com vs http://example2.com/)
    _id = TypeValidators.uri('id', value);

    // If the current schema $id has no scheme.
    if (_id.scheme.isEmpty) {
      // If the $id has a path and the root has a base, append it to the base.
      if (_inheritedUriBase != null && _id.path != null && _id.path != '/' && _id.path.isNotEmpty) {
        final path = _id.path.startsWith('/') ? _id.path : '/${_id.path}';
        _id = Uri.parse('${_inheritedUriBase.toString()}$path');

        // If the $id has a fragment, append it to the base, or use it alone.
      } else if (_id.fragment != null && _id.fragment.isNotEmpty) {
        _id = Uri.parse('${_inheritedId ?? ''}#${_id.fragment}');
      }
    }

    try {
      _idBase = JsonSchemaUtils.getBaseFromFullUri(_id);
    } catch (e) {
      // ID base can't be set for schemes other than HTTP(S).
      // This is expected behavior.
    }

    // Add the current schema to the ref map by its id, so it can be referenced elsewhere.
    _addSchemaToRefMap(_id.toString(), this);
    return _id;
  }

  /// Validate, calculate and set the value of the 'minimum' JSON Schema prop.
  _setMinimum(dynamic value) => _minimum = TypeValidators.number('minimum', value);

  /// Validate, calculate and set the value of the 'maximum' JSON Schema prop.
  _setMaximum(dynamic value) => _maximum = TypeValidators.number('maximum', value);

  /// Validate, calculate and set the value of the 'maxLength' JSON Schema prop.
  _setMaxLength(dynamic value) => _maxLength = TypeValidators.nonNegativeInt('maxLength', value);

  /// Validate, calculate and set the value of the 'minLength' JSON Schema prop.
  _setMinLength(dynamic value) => _minLength = TypeValidators.nonNegativeInt('minLength', value);

  /// Validate, calculate and set the value of the 'multiple' JSON Schema prop.
  _setMultipleOf(dynamic value) => _multipleOf = TypeValidators.nonNegativeNum('multiple', value);

  /// Validate, calculate and set the value of the 'not' JSON Schema prop.
  _setNot(dynamic value) {
    if (value is Map || value is bool && schemaVersion == SchemaVersion.draft6) {
      _makeSchema('$_path/not', value, (rhs) => _notSchema = rhs);
    } else {
      throw FormatExceptions.error('items must be object (or boolean in draft6 and later): $value');
    }
  }

  /// Validate, calculate and set the value of the 'oneOf' JSON Schema prop.
  _setOneOf(dynamic value) => _validateListOfSchema('oneOf', value, (schema) => _oneOf.add(schema));

  /// Validate, calculate and set the value of the 'pattern' JSON Schema prop.
  _setPattern(dynamic value) => _pattern = new RegExp(TypeValidators.string('pattern', value));

  /// Validate, calculate and set the value of the 'propertyNames' JSON Schema prop.
  _setPropertyNames(dynamic value) {
    if (value is Map || value is bool && schemaVersion == SchemaVersion.draft6) {
      _makeSchema('$_path/propertyNames', value, (rhs) => _propertyNamesSchema = rhs);
    } else {
      throw FormatExceptions.error('items must be object (or boolean in draft6 and later): $value');
    }
  }

  /// Validate, calculate and set the value of the '$ref' JSON Schema prop.
  _setRef(dynamic value) {
    _ref = TypeValidators.uri(r'$ref', value);
    final Uri originalRef = Uri.parse(_ref.toString());
    // TODO: add a more advanced check to find out if the $ref is local.
    // Does it have a fragment? Append the base and check if it exists in the _refMap
    // Does it have a path? Append the base and check if it exists in the _refMap
    if (_ref.scheme.isEmpty) {
      /// If the $id has a path and the root has a base, append it to the base.
      if (_inheritedUriBase != null && _ref.path != null && _ref.path != '/' && _ref.path.isNotEmpty) {
        final path = _ref.path.startsWith('/') ? _ref.path : '/${_ref.path}';
        var template = '${_inheritedUriBase.toString()}$path';
        if (_ref.fragment != null && _ref.fragment.isNotEmpty) {
          template += '#${_ref.fragment}';
        }
        _ref = Uri.parse(template);
        // If the $id has a fragment, append it to the base, or use it alone.
      } else if (_ref.fragment != null && _ref.fragment.isNotEmpty) {
        _ref = Uri.parse('${_inheritedUri ?? ''}#${_ref.fragment}');
      }
    }

    // The ref's base is a relative file path, so it should be treated as a relative file URI
    final isRelativeFileUri = _inheritedUriBase != null && _inheritedUriBase.scheme.isEmpty;
    if (_ref.scheme.isNotEmpty || isRelativeFileUri) {
      // TODO: should we do something if the ref is a fragment?
      final addSchemaFunction = (JsonSchema schema) {
        if (schema != null) {
          // Set referenced schema's path should be equivalent to the $ref value.
          // Otherwise it's set as `/`, which doesn't help track down
          // the source of validation errors.
          schema._path = _ref.toString() + '/';
          _addSchemaToRefMap(_ref.toString(), schema);
          return _addSchemaToRefMap(originalRef.toString(), schema);
        } else {
          throw FormatExceptions.error(
              'Couldn\'t resolve ref: ${_ref} using the ${_refProviderAsync != null ? 'provided' : 'default HTTP(S)'} ref provider.');
        }
      };

      final AsyncRetrievalOperation asyncRefSchemaOperation = _refProviderAsync == null
          ? () => createSchemaFromUrl(_ref.toString()).then(addSchemaFunction)
          : () => _refProviderAsync(_ref.toString()).then(addSchemaFunction);

      final SyncRetrievalOperation syncRefSchemaOperation =
          _refProvider != null ? () => addSchemaFunction(_refProvider(_ref.toString())) : null;

      /// Always add sub-schema retrieval requests to the [_root], as this is where the promise resolves.
      _root._retrievalRequests.add(new RetrievalRequest()
        ..schemaUri = _ref
        ..asyncRetrievalOperation = asyncRefSchemaOperation
        ..syncRetrievalOperation = syncRefSchemaOperation);
    }
  }

  /// Dertermine which schema version to use.
  ///
  /// Note: Uses the user specified version first, then the version set on the schema JSON, then the default.
  static SchemaVersion _getSchemaVersion(SchemaVersion userSchemaVersion, dynamic schema) {
    if (userSchemaVersion != null) {
      return TypeValidators.jsonSchemaVersion4Or6(r'$schema', userSchemaVersion.toString());
    } else if (schema is Map && schema[r'$schema'] is String) {
      return TypeValidators.jsonSchemaVersion4Or6(r'$schema', schema[r'$schema']);
    }
    return SchemaVersion.draft6;
  }

  /// Validate, calculate and set the value of the 'title' JSON Schema prop.
  _setTitle(dynamic value) => _title = TypeValidators.string('title', value);

  /// Validate, calculate and set the value of the 'type' JSON Schema prop.
  _setType(dynamic value) => _typeList = TypeValidators.typeList('type', value);

  // --------------------------------------------------------------------------
  // Schema List Item Related Property Setters
  // --------------------------------------------------------------------------

  /// Validate, calculate and set items of the 'pattern' JSON Schema prop that are also [JsonSchema]s.
  _setItems(dynamic value) {
    if (value is Map || value is bool && schemaVersion == SchemaVersion.draft6) {
      _makeSchema('$_path/items', value, (rhs) => _items = rhs);
    } else if (value is List) {
      int index = 0;
      _itemsList = new List(value.length);
      for (int i = 0; i < value.length; i++) {
        _makeSchema('$_path/items/${index++}', value[i], (rhs) => _itemsList[i] = rhs);
      }
    } else {
      throw FormatExceptions.error('items must be object or array (or boolean in draft6 and later): $value');
    }
  }

  /// Validate, calculate and set the value of the 'additionalItems' JSON Schema prop.
  _setAdditionalItems(dynamic value) {
    if (value is bool) {
      _additionalItemsBool = value;
    } else if (value is Map) {
      _makeSchema('$_path/additionalItems', value, (rhs) => _additionalItemsSchema = rhs);
    } else {
      throw FormatExceptions.error('additionalItems must be boolean or object: $value');
    }
  }

  /// Validate, calculate and set the value of the 'contains' JSON Schema prop.
  _setContains(dynamic value) => _makeSchema('$_path/contains', value, (rhs) => _contains = rhs);

  /// Validate, calculate and set the value of the 'examples' JSON Schema prop.
  _setExamples(dynamic value) => _examples = TypeValidators.list('examples', value);

  /// Validate, calculate and set the value of the 'maxItems' JSON Schema prop.
  _setMaxItems(dynamic value) => _maxItems = TypeValidators.nonNegativeInt('maxItems', value);

  /// Validate, calculate and set the value of the 'minItems' JSON Schema prop.
  _setMinItems(dynamic value) => _minItems = TypeValidators.nonNegativeInt('minItems', value);

  /// Validate, calculate and set the value of the 'uniqueItems' JSON Schema prop.
  _setUniqueItems(dynamic value) => _uniqueItems = TypeValidators.boolean('uniqueItems', value);

  // --------------------------------------------------------------------------
  // Schema Sub-Property Related Property Setters
  // --------------------------------------------------------------------------

  /// Validate, calculate and set sub-items or properties of the schema that are also [JsonSchema]s.
  _setProperties(dynamic value) => (TypeValidators.object('properties', value)).forEach((property, subSchema) =>
      _makeSchema('$_path/properties/$property', subSchema, (rhs) => _properties[property] = rhs));

  /// Validate, calculate and set the value of the 'additionalProperties' JSON Schema prop.
  _setAdditionalProperties(dynamic value) {
    if (value is bool) {
      _additionalProperties = value;
    } else if (value is Map) {
      _makeSchema('$_path/additionalProperties', value, (rhs) => _additionalPropertiesSchema = rhs);
    } else {
      throw FormatExceptions.error('additionalProperties must be a bool or valid schema object: $value');
    }
  }

  /// Validate, calculate and set the value of the 'dependencies' JSON Schema prop.
  _setDependencies(dynamic value) => (TypeValidators.object('dependencies', value)).forEach((k, v) {
        if (v is Map || v is bool && schemaVersion == SchemaVersion.draft6) {
          _makeSchema('$_path/dependencies/$k', v, (rhs) => _schemaDependencies[k] = rhs);
        } else if (v is List) {
          // Dependencies must have contents in draft4, but can be empty in draft6 and later
          if (schemaVersion == SchemaVersion.draft4) {
            if (v.length == 0) throw FormatExceptions.error('property dependencies must be non-empty array');
          }

          final Set uniqueDeps = new Set();
          v.forEach((propDep) {
            if (propDep is! String) throw FormatExceptions.string('propertyDependency', v);

            if (uniqueDeps.contains(propDep)) throw FormatExceptions.error('property dependencies must be unique: $v');

            _propertyDependencies.putIfAbsent(k, () => []).add(propDep);
            uniqueDeps.add(propDep);
          });
        } else {
          throw FormatExceptions.error(
              'dependency values must be object or array (or boolean in draft6 and later): $v');
        }
      });

  /// Validate, calculate and set the value of the 'maxProperties' JSON Schema prop.
  _setMaxProperties(dynamic value) => _maxProperties = TypeValidators.nonNegativeInt('maxProperties', value);

  /// Validate, calculate and set the value of the 'minProperties' JSON Schema prop.
  _setMinProperties(dynamic value) => _minProperties = TypeValidators.nonNegativeInt('minProperties', value);

  /// Validate, calculate and set the value of the 'patternProperties' JSON Schema prop.
  _setPatternProperties(dynamic value) => (TypeValidators.object('patternProperties', value)).forEach(
      (k, v) => _makeSchema('$_path/patternProperties/$k', v, (rhs) => _patternProperties[new RegExp(k)] = rhs));

  /// Validate, calculate and set the value of the 'required' JSON Schema prop.
  _setRequired(dynamic value) =>
      _requiredProperties = (TypeValidators.nonEmptyList('required', value))?.map((value) => value as String)?.toList();

  /// Validate, calculate and set the value of the 'required' JSON Schema prop.
  _setRequiredV6(dynamic value) =>
      _requiredProperties = (TypeValidators.list('required', value))?.map((value) => value as String)?.toList();
}

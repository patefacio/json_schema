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

/// Functionality to create Graphviz input dot file from schema
library json_schema.schema_dot;

import 'package:json_schema/json_schema.dart';

/// Represents one node in the schema diagram
///
@Deprecated('This functionality is not maintained, is untested, and may be removed in a future release.')
class SchemaNode {
  SchemaNode(this.schema, [this.links]) {
    if (links == null) links = [];
  }

  /// Referenced schema this node portrays
  JsonSchema schema;

  /// List of links (resulting in graph edge) from this node to another
  List<String> links;

  static bool schemaShown(JsonSchema schema) =>
      schema.properties.length > 0 ||
      schema.definitions.length > 0 ||
      schema.anyOf.length > 0 ||
      schema.oneOf.length > 0 ||
      schema.allOf.length > 0 ||
      schema.enumValues.length > 0 ||
      schema.additionalPropertiesSchema != null ||
      schema.minimum != null ||
      schema.maximum != null ||
      schema.ref != null;

  String get nodes {
    final List lines = schema.refMap.values
        .where((schema) => schemaShown(schema))
        .map((schema) => new SchemaNode(schema, links).node)
        .toList();
    lines.addAll(links.map((link) => '$link;'));
    return lines.join('\n');
  }

  String get node {
    final data = ['"${schema.path}" [']..add(label.join('\n'))..add(']');
    return data.join('\n');
  }

  static dynamic schemaType(JsonSchema schema) {
    dynamic result;
    final typeList = schema.typeList;
    if (typeList == null) {
      if (schema.oneOf.length > 0) {
        result = 'oneOf:${schema.oneOf.map((schema) => schemaType(schema)).toList()}';
      } else if (schema.anyOf.length > 0) {
        result = 'anyOf:${schema.anyOf.map((schema) => schemaType(schema)).toList()}';
      } else if (schema.allOf.length > 0) {
        result = 'allOf:${schema.allOf.map((schema) => schemaType(schema)).toList()}';
      } else if (schema.defaultValue != null) {
        result = 'default=${schema.defaultValue}';
      } else if (schema.ref != null) {
        result = 'ref=${schema.ref}';
      } else if (schema.enumValues != null && schema.enumValues.length > 0) {
        result = 'enum=${schema.enumValues}';
      } else if (schema.schemaMap.length == 0) {
        result = '{}';
      } else {
        result = '$schema';
      }
    } else {
      result = typeList.length == 1 ? typeList[0] : typeList;
    }
    if ((result is List) && result.length == 0) result = {};
    if (result == null) result = {};
    return result;
  }

  List<String> get label {
    return ['label =<']
      ..add('<table border="0" cellborder="0" cellpadding="1" bgcolor="white">')
      ..add(wrap(schema.path, port: '@path'))
      ..add(wrap(title))
      ..add(wrap(description))
      ..addAll(definitionEntries)
      ..addAll(propertyEntries)
      ..addAll(additionalPropertiesSchema)
      ..addAll(propertyDependencies)
      ..addAll(schemaDependencies)
      ..addAll(minimum)
      ..addAll(maximum)
      ..addAll(defaultValue)
      ..addAll(anyOf)
      ..addAll(oneOf)
      ..addAll(allOf)
      ..addAll(enumEntries)
      ..add('</table>')
      ..add('>');
  }

  List<String> get defaultValue {
    final List<String> result = [];
    if (schema.defaultValue != null) {
      result.add(wrapRowDistinct('default', '${schema.defaultValue}'));
    }
    return result;
  }

  List<String> get minimum {
    final List<String> result = [];
    if (schema.minimum != null) {
      result.add(wrapRowDistinct('minimum', '${schema.minimum}'));
    }
    return result;
  }

  List<String> get maximum {
    final List<String> result = [];
    if (schema.maximum != null) {
      result.add(wrapRowDistinct('maximum', '${schema.maximum}'));
    }
    return result;
  }

  List<String> get multipleOf {
    final List<String> result = [];
    if (schema.multipleOf != null) {
      result.add(wrapRowDistinct('multipleOf', '${schema.multipleOf}'));
    }
    return result;
  }

  List<String> get enumEntries {
    final List<String> enumValues = [];
    if (schema.enumValues.length > 0) {
      enumValues.add(wrap('Enum Values', color: 'beige'));
      schema.enumValues.forEach((value) {
        enumValues.add(wrap('$value', color: 'grey'));
      });
    }
    return enumValues;
  }

  List<String> get anyOf {
    final List<String> anyOf = [];
    if (schema.anyOf.length > 0) {
      anyOf.add(wrap('Any Of', color: 'beige'));
      int i = 0;
      schema.anyOf.forEach((anyOfSchema) {
        final String port = '${i++}';
        makeSchemaLink(port, schema, anyOfSchema);
        anyOf.add(wrap(abbreviatedString('${schemaType(anyOfSchema)}', 30), color: 'grey', port: port));
      });
    }
    return anyOf;
  }

  List<String> get oneOf {
    final List<String> oneOf = [];
    if (schema.oneOf.length > 0) {
      oneOf.add(wrap('One Of', color: 'beige'));
      int i = 0;
      schema.oneOf.forEach((oneOfSchema) {
        final String port = '${i++}';
        makeSchemaLink(port, schema, oneOfSchema);
        oneOf.add(wrap(abbreviatedString('${schemaType(oneOfSchema)}', 30), color: 'grey', port: port));
      });
    }
    return oneOf;
  }

  List<String> get allOf {
    final List<String> allOf = [];
    if (schema.allOf.length > 0) {
      allOf.add(wrap('All Of', color: 'beige'));
      int i = 0;
      schema.allOf.forEach((allOfSchema) {
        final String port = '${i++}';
        makeSchemaLink(port, schema, allOfSchema);
        allOf.add(wrap(abbreviatedString('${schemaType(allOfSchema)}', 30), color: 'grey', port: port));
      });
    }
    return allOf;
  }

  List<String> get propertyDependencies {
    final List<String> result = [];
    if (schema.propertyDependencies.length > 0) {
      result.add(wrap('Property Dependencies'));
      schema.propertyDependencies.forEach((key, val) {
        result.add(wrapRowDistinct(key, val.toString()));
      });
    }
    return result;
  }

  List<String> get schemaDependencies {
    final List<String> result = [];
    if (schema.schemaDependencies.length > 0) {
      result.add('Property Dependencies');
      schema.propertyDependencies.forEach((key, val) {
        result.add(wrapRowDistinct(key, val.toString()));
      });
    }
    return result;
  }

  makeSchemaPort(String port, JsonSchema schema) => '"${schema.path}":"$port"';

  makeSchemaLink(String port, JsonSchema src, JsonSchema target) {
    if (schemaShown(target)) links.add('${makeSchemaPort(port, src)} -> ${makeSchemaPort("@path", target)}');
  }

  List<String> get additionalPropertiesSchema {
    final List<String> result = [];
    final JsonSchema other = schema.additionalPropertiesSchema;
    if (other != null) {
      result.add(wrap('Additional Properties', color: 'lemonchiffon'));
      final String port = 'mustBe';
      makeSchemaLink(port, schema, other);
      result.add(wrapRowDistinct('Must Be: ', abbreviatedString(schemaType(other).toString(), 30), port));
    }
    return result;
  }

  List<String> get propertyEntries {
    final List<String> props = [];
    if (schema.properties.length > 0) {
      props.add(wrap('Properties'));
      final sortedProps = new List.from(schema.properties.keys)..sort();
      sortedProps.forEach((prop) {
        final propertySchema = schema.properties[prop];
        final String requiredPrefix = schema.propertyRequired(prop) ? '! ' : '? ';
        final String port = '@$prop';
        if (schemaShown(propertySchema)) {
          makeSchemaLink(port, schema, propertySchema);
        } else if (propertySchema.items is JsonSchema && schemaShown(propertySchema.items)) {
          makeSchemaLink(port, schema, propertySchema.items);
        }
        props.add(wrapRowDistinct(
            '$requiredPrefix$prop', abbreviatedString(schemaType(propertySchema).toString(), 30), port));
      });
    }
    return props;
  }

  List<String> get definitionEntries {
    final List<String> definitions = [];
    if (schema.definitions.length > 0) {
      definitions
          .add('<tr><td bgcolor="wheat" align="center" colspan="2"><font color="black">Definitions</font></td></tr>');
      final sortedDefinitions = new List.from(schema.definitions.keys)..sort();
      sortedDefinitions.forEach((key) {
        definitions.add(wrapRowDistinct(key, '', '${schema.path}@$key'));
      });
    }
    return definitions;
  }

  String wrap(String s, {String port: '', String color: 'wheat'}) => s == null
      ? ''
      : '<tr><td bgcolor="$color" align="center" colspan="2" port="$port"><font color="black">$s</font></td></tr>';

  String wrapRowDistinct(String first, String second, [String port = '']) =>
      '<tr><td align="left" port="$port">$first</td>$first<td bgcolor="grey" align="right">$second</td></tr>';

  String get title => schema.title != null ? abbreviatedString("title=${schema.title}", 30) : null;

  String get description => schema.description != null ? abbreviatedString('descr=${schema.description}', 30) : null;

  String abbreviatedString(String s, [int len = 15]) {
    if (s == null) return s;
    len -= 3;
    if (len >= s.length) {
      return s;
    } else {
      return s.substring(0, len) + '...';
    }
  }
}

/// Return a dot specification for [schema]
@Deprecated('This functionality is not maintained, is untested, and may be removed in a future release.')
String createDot(JsonSchema schema) => '''
digraph G {
  fontname = "Bitstream Vera Sans"
  fontsize = 8

  node [
    fontname = "Courier"
    fontsize = 8
    shape = "plaintext"
  ]

  edge [
    fontname = "Bitstream Vera Sans"
    fontsize = 8
  ]

${new SchemaNode(schema).nodes}


}

''';

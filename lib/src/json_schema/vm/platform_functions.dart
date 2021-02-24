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

import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:convert' as convert;


import 'package:json_schema/src/json_schema/constants.dart';
import 'package:json_schema/src/json_schema/json_schema.dart';
import 'package:json_schema/src/json_schema/utils.dart';

Future<JsonSchema> createSchemaFromUrlVm(String schemaUrl, {SchemaVersion schemaVersion}) async {
  final uriWithFrag = Uri.parse(schemaUrl);
  final uri = schemaUrl.endsWith('#') ? uriWithFrag : uriWithFrag.removeFragment();
  Map schemaMap;
  if (uri.scheme == 'http' || uri.scheme == 'https') {
    // Setup the HTTP request.
    final httpRequest = await new HttpClient().getUrl(uri);
    httpRequest.followRedirects = true;
    // Fetch the response
    final response = await httpRequest.close();
    // Convert the response into a string
    if (response.statusCode == HttpStatus.NOT_FOUND) {
      throw new ArgumentError('Schema at URL: $schemaUrl can\'t be found.');
    }
    final schemaText = await new convert.Utf8Decoder().bind(response).join();
    schemaMap = json.decode(schemaText);
  } else if (uri.scheme == 'file' || uri.scheme == '') {
    final fileString = await new File(uri.scheme == 'file' ? uri.toFilePath() : schemaUrl).readAsString();
    schemaMap = json.decode(fileString);
  } else {
    throw new FormatException('Url schema must be http, file, or empty: $schemaUrl');
  }
  // HTTP servers / file systems ignore fragments, so resolve a sub-map if a fragment was specified.
  final parentSchema = await JsonSchema.createSchemaAsync(schemaMap, schemaVersion: schemaVersion, fetchedFromUri: uri);
  final schema = JsonSchemaUtils.getSubMapFromFragment(parentSchema, uriWithFrag);
  return schema ?? parentSchema;
}

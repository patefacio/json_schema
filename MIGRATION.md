# json_schema v2.x to v3 Migration Guide

json_schema 3.0 is now here due to an issue that was found in 2.0 that caused remote refs to not get resolved correctly. This forced us to sort through the ref resolution logic in schema construction and change a few underlying assumptions. While on the surface it doesn't look like any publically exposed members or methods were modified or removed, the map of sub-properties' and references' [JsonSchema]s by path (`_refMap`) is structured differently to accommodate new logic changes in schema construction and resolution.

All tests continue to pass and most consumers will not have to make any changes, but for some more advanced use cases, these changes might break schema resolution/validation which we prefer to protect against with a 3.0 major version upgrade.


# json_schema v1.x to v2 Migration Guide

json_schema 2.0 is here, and is packed with useful updates! We've tried to minimize incompatibilities, while taking steps to build for the future. These include:

- json_schema is no longer bound to dart:io!
  - json_schema can now be used in either the browser or on a server by utilizing `configureJsonSchemaForBrowser()` or `configureBrowserForVm()`. Only necessary if you use async fetch of remote schemas via `createSchemaAsync`.
- JSON Schema draft6 compatibility
  - Allowing multiple spec versions (draft4 and draft6)
- Synchronous evaluation of schemas, by default.
  - Make fetching referenced schemas possible out-of-band and explicitly, while removing the default behavior to make HTTP calls.
- Renaming or splitting up certain keyword getters for better type-safety.
  - i.e. `bool additionalPropertiesBool` and `JsonSchema additionalPropertiesSchema` vs `dynamic addtionalProperties`.
- Automatic parsing of JSON strings when they are passed to `createSchema`, for more straightforward creation of schemas
- Optional parsing of JSON strings when they are passed to `validate`.
- The repo is now maintained by Workiva.


## Breaking Changes

- `Schema` --> `JsonSchema`
  - We've changed the name of the main class, for clarity.

- `JsonShema createSchema`
  - DON'T PANIC, we've changed the signature of the main constructor! We did this in order to allow syncronous evaluation of schemas by default.
  - There are a few paths you can take here:
    - If you were using `createSchema` to evaluate schemas that contained remote references you don't have cached locally, simply switch over to `createSchemaAsync`, which has the same behavior. If you continue to use the synchronous `createSchema`: *errors will be thrown when remote references are encountered*.
    - If you were using `createSchema` to evaluate schemas where all references can be resolved within the root schema, congrats! You can now remove all async behavior around creating schemas. No more async / await :)
    - If you were using `createSchema` to evaluate schema which have remote references, but you can cache all the remote references locally, you can use the optional `RefProvider` to allow sync resolution of those.
    - A new use case is also available: you can now use custom logic to resolve your own $refs using `RefProviderAsync` / `createSchemaAsync`.

- Platforms
  - dart:io Users: A single call to `configureBrowserForVm()` is required before using `createSchemaAsync`.
  - dart:html Users: A single call to `configureBrowserForBrowser()` is required before using `createSchemaAsync`.

- Removal of Custom Validation Logic
    - `set uriValidator` and `set emailValidator` have been removed and replaced with spec-supplied logical constraints.
    - This was removed because it was one-off for these two formats. Look for generic custom format validation in the future.

- `exclusiveMaximum` and `exclusiveMinimum`
  - changed `bool get exclusiveMinimum` --> `num get exclusiveMinimum` and
  `bool get exclusiveMaximum` --> `num get exclusiveMaximum`. The old boolean values are available under `bool get hasExclusiveMinimum` and `bool get hasExclusiveMaximum`, while the new values contain the actual value of the min / max. This is consistent with how the spec was changes, see the release notes: https://json-schema.org/draft-06/json-schema-release-notes.html

- `String get ref` --> `Uri get ref`
  - Since the spec specifies that $refs MUST be a URI, we've given refs some additional type safety.(https://tools.ietf.org/html/draft-wright-json-schema-01#section-8).

## Notable Deprecations

- `JsonSchema.refMap`
  - Note: This information is useful for drawing dependency graphs, etc, but should not be used for general 
validation or traversal. Use `endPath` to get the absolute `String` path and `resolvePath` to get the `JsonSchema` at any path, instead. This functionality will be removed in 3.0.

- All `schema_dot.dart` exports including `SchemaNode` and `createDot`
  - Unfortunetly, we don't have the resources to maintain this part of the codebase, as such, it has been untested against the major changes in 2.0, and is marked for future removal. Raise an issue or submit a PR if this was important to you.
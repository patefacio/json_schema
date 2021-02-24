class FormatExceptions {
  static FormatException error(String msg, [String path]) {
    msg = '${path ?? ''}: $msg';
    // if (logFormatExceptions) _logger.warning(msg); TODO: re-add logger
    return FormatException(msg);
  }

  static FormatException bool(String key, dynamic instance, [String path]) =>
      error('$key must be boolean: $instance', path);
  static FormatException num(String key, dynamic instance, [String path]) => error('$key must be num: $instance', path);
  static FormatException nonNegativeNum(String key, dynamic instance, [String path]) =>
      error('multipleOf must be > 0: $instance');
  static FormatException int(String key, dynamic instance, [String path]) => error('$key must be int: $instance', path);
  static FormatException string(String key, dynamic instance, [String path]) =>
      error('$key must be string: $instance', path);
  static FormatException object(String key, dynamic instance, [String path]) =>
      error('$key must be object: $instance', path);
  static FormatException list(String key, dynamic instance, [String path]) =>
      error('$key must be array: $instance', path);
  static FormatException schema(String key, dynamic instance, [String path]) =>
      error('$key must be valid schema object or boolean: $instance', path);
}

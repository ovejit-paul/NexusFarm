import 'dart:math';

final _random = Random();

/// A short unique id for a record.
///
/// Time plus randomness is enough here: records are created by one
/// person on one device, a few at a time. No uuid package needed.
String newId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
    '${_random.nextInt(1 << 30).toRadixString(36)}';

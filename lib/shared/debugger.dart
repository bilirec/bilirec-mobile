import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

void debugLog(String message) {
  if (kDebugMode) {
    developer.log(message, name: 'bilirec');
  }
}
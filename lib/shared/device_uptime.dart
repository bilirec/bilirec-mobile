import 'dart:io';

Future<String?> readBootId() async {
  try {
    final bootId =
        (await File('/proc/sys/kernel/random/boot_id').readAsString()).trim();
    if (bootId.isEmpty) {
      return null;
    }
    return bootId;
  } catch (_) {
    return null;
  }
}

import 'package:file_picker/file_picker.dart';

/// Replaces [FilePicker.platform] to return a fixed directory path in tests.
class MockDirectoryFilePicker extends FilePicker {
  MockDirectoryFilePicker(this._directoryPath);

  final String _directoryPath;
  FilePicker? _previous;

  void install() {
    _previous = FilePicker.platform;
    FilePicker.platform = this;
  }

  void restore() {
    final previous = _previous;
    if (previous != null) {
      FilePicker.platform = previous;
    }
    _previous = null;
  }

  @override
  Future<String?> getDirectoryPath({
    String? dialogTitle,
    bool lockParentWindow = false,
    String? initialDirectory,
  }) async {
    return _directoryPath;
  }
}

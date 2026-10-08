import 'dart:io';

import 'package:home_widget/home_widget.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'widget_store.dart';

Future<String?> loadAvatarPath() async {
  final path = await HomeWidget.getWidgetData<String>(WidgetKeys.avatarPath);
  if (path == null || !File(path).existsSync()) return null;
  return path;
}

/// Lets the user pick a photo and keeps a copy in app storage, where the
/// widget can read it. Returns the new path, or null if nothing was picked.
Future<String?> pickAvatar() async {
  final picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 90,
  );
  if (picked == null) return null;

  final dir = await getApplicationDocumentsDirectory();
  // A new name each time so the widget and the app never show a cached old photo.
  final saved = await File(
    picked.path,
  ).copy('${dir.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg');
  await _deleteStoredAvatar();
  await HomeWidget.saveWidgetData<String>(WidgetKeys.avatarPath, saved.path);
  return saved.path;
}

Future<void> removeAvatar() async {
  await _deleteStoredAvatar();
  await HomeWidget.saveWidgetData<String>(WidgetKeys.avatarPath, null);
}

Future<void> _deleteStoredAvatar() async {
  final old = await HomeWidget.getWidgetData<String>(WidgetKeys.avatarPath);
  if (old == null) return;
  try {
    await File(old).delete();
  } on FileSystemException {
    // Already gone.
  }
}

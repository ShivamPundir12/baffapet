import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> requestCommonPermissions() async {
  if (!kIsWeb && Platform.isAndroid) {
    await [Permission.camera, Permission.microphone, Permission.photos].request();
  }
}

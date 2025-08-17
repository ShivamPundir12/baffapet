import 'dart:io';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

Future<void> handleDownload(
  BuildContext context,
  InAppWebViewController controller,
  Uri url,
) async {
  try {
    final dir = Platform.isAndroid
        ? (await getExternalStorageDirectory())
        : await getApplicationDocumentsDirectory();
    if (dir == null) return;

    final filename = url.pathSegments.isNotEmpty
        ? url.pathSegments.last
        : "file_${DateTime.now().millisecondsSinceEpoch}";
    final savePath = "${dir.path}/$filename";

    final data = await controller
        .callAsyncJavaScript(
          functionBody: """
          async function downloadFile(u){
            const res = await fetch(u, {credentials: 'include'});
            const buf = await res.arrayBuffer();
            return Array.from(new Uint8Array(buf));
          }
        """,
        )
        .then(
          (_) => controller.callAsyncJavaScript(
            functionBody:
                "return await downloadFile('${url.toString().replaceAll("'", "\\'")}');",
          ),
        );

    if (data?.value is List) {
      final bytes = List<int>.from(data!.value);
      final file = File(savePath);
      await file.writeAsBytes(bytes);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Saved: $filename")));
      }
      await OpenFilex.open(savePath);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Download failed")));
    }
  }
}

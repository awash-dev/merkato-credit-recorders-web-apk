// ignore_for_file: deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

Future<bool> shareOrSaveImageBytesFromDevice(
  Uint8List bytes,
  String filename, {
  String? title,
}) async {
  try {
    // 1. Try modern Web Share API if supported by browser (e.g. Chrome on Android or Desktop)
    try {
      final nav = html.window.navigator;
      final file = html.File([bytes], filename, {'type': 'image/png'});
      final shareData = {
        'files': [file],
        'title': title ?? 'Account Statement',
      };
      await nav.share(shareData);
      return true;
    } catch (_) {
      // Fallback to direct download below
    }

    // 2. Direct browser download of the clean PNG image
    final blob = html.Blob([bytes], 'image/png');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', filename)
      ..style.display = 'none';
    html.document.body?.children.add(anchor);
    anchor.click();
    html.document.body?.children.remove(anchor);
    html.Url.revokeObjectUrl(url);
    return true;
  } catch (e) {
    return false;
  }
}

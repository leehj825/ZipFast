import 'dart:convert';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

/// Full-screen preview of an image or text entry read from an archive.
class PreviewPage extends StatelessWidget {
  const PreviewPage.image({super.key, required this.title, required Uint8List this.bytes})
      : _isImage = true;
  const PreviewPage.text({super.key, required this.title, required Uint8List this.bytes})
      : _isImage = false;

  final String title;
  final Uint8List? bytes;
  final bool _isImage;

  static const imageExtensions = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'bmp'};
  static const textExtensions = {
    'txt', 'md', 'json', 'xml', 'csv', 'log', 'yaml', 'yml', 'ini', 'html',
    'css', 'js', 'dart', 'java', 'kt', 'py', 'c', 'h', 'cpp', 'sh', 'srt', 'properties',
  };

  /// Maximum number of bytes of a text file that is rendered.
  static const maxTextBytes = 1024 * 1024;

  static String extensionOf(String name) {
    final i = name.lastIndexOf('.');
    return i < 0 ? '' : name.substring(i + 1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final data = bytes!;
    return Scaffold(
      appBar: AppBar(title: Text(title, overflow: TextOverflow.ellipsis)),
      body: _isImage
          ? InteractiveViewer(
              maxScale: 8,
              child: Center(
                child: Image.memory(
                  data,
                  errorBuilder: (_, _, _) => const Icon(Icons.broken_image, size: 64),
                ),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                utf8.decode(
                  data.length > maxTextBytes ? data.sublist(0, maxTextBytes) : data,
                  allowMalformed: true,
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
    );
  }
}

import 'dart:io';

import 'package:eros_app/core/constants/media_constants.dart';
import 'package:mime/mime.dart';

/// Number of leading bytes read from a file to recognise its format.
const int imageHeaderBytesLength = 64;

/// Works out a photo's content type, returning it only if uploads allow it.
///
/// Checked in this order:
/// 1. The file's leading bytes ([headerBytes]). This is the most reliable, because pickers can
///    re-encode a photo without changing its name.
/// 2. [reportedMimeType], e.g. `XFile.mimeType`. image_picker usually leaves it null on iOS
///    and Android.
/// 3. The extension in [path].
///
/// The first of these that gives an answer decides. The result is lower-cased, and `image/jpg`
/// becomes `image/jpeg`. Returns null when nothing is recognised, or when the type isn't in
/// [MediaConstants.allowedContentTypes]. Never guesses `image/jpeg` as a fallback.
String? detectImageContentType({
  required String path,
  List<int>? headerBytes,
  String? reportedMimeType,
}) {
  final sniffed = (headerBytes == null || headerBytes.isEmpty)
      ? null
      : lookupMimeType('', headerBytes: headerBytes);
  final reported = (reportedMimeType == null || reportedMimeType.trim().isEmpty)
      ? null
      : reportedMimeType.trim();
  final detected = sniffed ?? reported ?? lookupMimeType(path);
  if (detected == null) return null;

  final normalised = detected.toLowerCase() == 'image/jpg' ? 'image/jpeg' : detected.toLowerCase();
  return MediaConstants.isContentTypeAllowed(normalised) ? normalised : null;
}

/// Reads the start of [file] and calls [detectImageContentType].
Future<String?> detectFileContentType(File file, {String? reportedMimeType}) async {
  final header = <int>[];
  await for (final chunk in file.openRead(0, imageHeaderBytesLength)) {
    header.addAll(chunk);
  }
  return detectImageContentType(
    path: file.path,
    headerBytes: header,
    reportedMimeType: reportedMimeType,
  );
}

import 'dart:typed_data';

class LocalMediaPayload {
  const LocalMediaPayload({
    required this.localUrl,
    required this.bytes,
  });

  final String localUrl;
  final Uint8List bytes;
}

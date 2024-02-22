/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'dart:convert';
import 'dart:typed_data';

/// A upload request
///
/// A POJO style model representing a JSON object for
/// the hosted storage.
class StorageModelUpload {
  String? key;
  Uint8List? content;

  StorageModelUpload({this.key, this.content});

  StorageModelUpload.fromMap(Map<String, dynamic>? map) {
    if (map != null) {
      key = map['key'];
      if (map['content'] != null) content = base64Decode(map['content']);
    }
  }

  Map<String, dynamic> toMap() =>
      {'key': key, 'content': content != null ? base64Encode(content!) : null};

  @override
  String toString() {
    return 'StorageModelUpload{key: $key, content: ${content != null ? base64Encode(content!) : null}';
  }
}

/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'dart:convert';
import 'dart:typed_data';

/// Utility methods to work with raw bytes data.
class Bytes {
  /// Encode a BigInt into bytes using big-endian encoding.
  /// It encodes the integer to a minimal twos-compliment integer as defined by
  /// ASN.1
  /// From pointycastle/src/utils
  static Uint8List encodeBigInt(BigInt? number) {
    if (number == BigInt.zero) {
      return Uint8List.fromList([0]);
    }

    int needsPaddingByte;
    int rawSize;

    if (number! > BigInt.zero) {
      rawSize = (number.bitLength + 7) >> 3;
      needsPaddingByte = ((number >> (rawSize - 1) * 8) & BigInt.from(0x80)) ==
              BigInt.from(0x80)
          ? 1
          : 0;
    } else {
      needsPaddingByte = 0;
      rawSize = (number.bitLength + 8) >> 3;
    }

    final size = rawSize + needsPaddingByte;
    var result = Uint8List(size);
    for (var i = 0; i < rawSize; i++) {
      result[size - i - 1] = (number! & BigInt.from(0xff)).toInt();
      number = number >> 8;
    }
    return result;
  }

  /// Decode a BigInt from bytes in big-endian encoding.
  /// Twos compliment.
  /// From pointycastle/src/utils
  static BigInt decodeBigInt(List<int> bytes) {
    var negative = bytes.isNotEmpty && bytes[0] & 0x80 == 0x80;

    BigInt result;

    if (bytes.length == 1) {
      result = BigInt.from(bytes[0]);
    } else {
      result = BigInt.zero;
      for (var i = 0; i < bytes.length; i++) {
        var item = bytes[bytes.length - i - 1];
        result |= (BigInt.from(item) << (8 * i));
      }
    }
    return result != BigInt.zero
        ? negative
            ? result.toSigned(result.bitLength)
            : result
        : BigInt.zero;
  }

  /// Compares two [Uint8List]s for equality
  /// From: https://api.flutter.dev/flutter/foundation/listEquals.html.
  static bool memEquals(Uint8List? a, Uint8List? b) {
    if (a == null) {
      return b == null;
    }
    if (b == null || a.length != b.length) {
      return false;
    }
    if (identical(a, b)) {
      return true;
    }
    for (int index = 0; index < a.length; index += 1) {
      if (a[index] != b[index]) {
        return false;
      }
    }
    return true;
  }

  /// Encodes bytes to hex
  static String hexEncode(Uint8List bytes) =>
      bytes.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

  /// Encodes bytes to url-safe base64 string without padding.
  static String base64UrlEncode(Uint8List bytes) {
    String b64 = base64Url.encode(bytes);
    return b64.replaceAll("=", '');
  }

  /// Decodes url-safe base64 string without padding into bytes.
  static Uint8List base64UrlDecode(String b64String) {
    int extra = b64String.length % 4;
    int length = extra > 0 ? b64String.length + (4 - extra) : 0;
    return base64Url.decode(b64String.padRight(length, "="));
  }

  // Encodes a UTF-8 string as Uint8List
  static Uint8List utf8Encode(String s) => Uint8List.fromList(utf8.encode(s));

  // Decodes a Uint8List to a UTF-8 string
  static String utf8Decode(Uint8List bytes) => utf8.decode(bytes.toList());
}

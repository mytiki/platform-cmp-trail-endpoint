/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'dart:convert';
import 'dart:typed_data';

import 'package:pointycastle/api.dart';

import '../../utils/bytes.dart';
import '../../utils/compact_size.dart';
import '../block/block_model.dart';
import 'transaction_repository.dart';

/// A transaction in the blockchain.
class TransactionModel {
  /// The version number indicating the set of validation rules to follow.
  late final int version;

  /// The SHA-3 hash of the public key used for signature.
  late final Uint8List address;

  /// The timestamp of the creation of this.
  late final DateTime timestamp;

  /// The path of the asset to which this refers to. '' if null.
  late final String assetRef;

  /// The binary encoded transaction payload.
  ///
  /// There is no max contents size, but contents are encouraged to stay under
  /// 100kB for performance.
  late final Uint8List contents;

  /// The SHA-3 256 hash of the [serialize] Uint8List.
  ///
  /// Should include signature.
  Uint8List? id;

  /// The list of hashes that is used in [MerkelTree.validate] to verify that
  /// this [TransactionModel] is included in [block].
  Uint8List? merkelProof;

  /// The [BlockModel] in which this [TransactionModel] is included.
  BlockModel? block;

  /// The asymmetric user's digital signature (RSA) for the transaction.
  Uint8List? userSignature;

  /// The asymmetric app's digital signature (RSA) for the transaction.
  Uint8List? appSignature;

  /// Builds a new [TransactionModel]
  ///
  /// If no [timestamp] is provided, the object creation time is used.
  /// If no [assetRef] is provided, it uses '' as [assetRef] value.
  TransactionModel(
      {this.id,
      this.version = 2,
      required this.address,
      required this.contents,
      this.assetRef = '',
      DateTime? timestamp,
      this.merkelProof,
      this.block,
      this.userSignature,
      this.appSignature})
      : timestamp = timestamp ?? DateTime.now();

  /// Builds a [BlockModel] from a [map].
  ///
  /// It is used mainly for retrieving data from [BlockRepository].
  /// The map structure is
  /// ```
  ///   Map<String, dynamic> map = {
  ///     TransactionRepository.columnId : String,
  ///     TransactionRepository.columnVersion : int,
  ///     TransactionRepository.columnAddress : Uint8List,
  ///     TransactionRepository.columnContents : Uint8List,
  ///     TransactionRepository.columnAssetRef : String,
  ///     TransactionRepository.columnMerkelProof : Uint8List,
  ///     TransactionRepository.columnTimestamp : int, // seconds since epoch
  ///     TransactionRepository.columnSignature : Uint8List,
  ///    }
  /// ```
  TransactionModel.fromMap(Map<String, dynamic> map)
      : id = map[TransactionRepository.columnId],
        version = map[TransactionRepository.columnVersion],
        address = map[TransactionRepository.columnAddress],
        contents = map[TransactionRepository.columnContents],
        assetRef = map[TransactionRepository.columnAssetRef],
        merkelProof = map[TransactionRepository.columnMerkelProof],
        block = map['block'],
        timestamp = DateTime.fromMillisecondsSinceEpoch(
            map[TransactionRepository.columnTimestamp]),
        userSignature = map[TransactionRepository.columnUserSignature],
        appSignature = map[TransactionRepository.columnAppSignature];

  /// Builds a [TransactionModel] from a [transaction] list of bytes.
  ///
  /// Check [serialize] for more information on how the [transaction] is built.
  TransactionModel.deserialize(Uint8List transaction) {
    List<Uint8List> extractedBytes = CompactSize.decode(transaction);
    version = Bytes.decodeBigInt(extractedBytes[0]).toInt();
    address = extractedBytes[1];
    timestamp = DateTime.fromMillisecondsSinceEpoch(
        Bytes.decodeBigInt(extractedBytes[2]).toInt() * 1000);
    assetRef = utf8.decode(extractedBytes[3]);
    userSignature = extractedBytes[4];
    appSignature = extractedBytes[5];
    contents = extractedBytes[6];
    id = Digest("SHA3-256").process(serialize());
  }

  /// Creates a [Uint8List] representation of this.
  ///
  /// The Uint8List is built by a list of the transaction properties, prepended
  /// by its size obtained from [CompactSize.encode].
  /// Use with [includeSignature] to false, to sign or verify the signature.
  ///
  /// ```
  /// Uint8List serialized =  (BytesBuilder()
  ///        ..add(serializedVersion)
  ///        ..add(serializedAddress)
  ///        ..add(serializedTimestamp)
  ///        ..add(serializedAssetRef)
  ///        ..add(serializedSignature)
  ///        ..add(serializedContents)).toBytes()
  /// ]);
  /// ```
  Uint8List serialize({includeSignature = true}) {
    Uint8List versionBytes = Bytes.encodeBigInt(BigInt.from(version));
    Uint8List serializedVersion = CompactSize.encode(versionBytes);
    Uint8List serializedAddress = CompactSize.encode(address);
    Uint8List timestampBytes = Bytes.encodeBigInt(
        BigInt.from(timestamp.millisecondsSinceEpoch ~/ 1000));
    Uint8List serializedTimestamp = CompactSize.encode(timestampBytes);
    Uint8List assetRefBytes = Uint8List.fromList(utf8.encode(assetRef));
    Uint8List serializedAssetRef = CompactSize.encode(assetRefBytes);
    Uint8List serializedUserSignature = CompactSize.encode(
        includeSignature && userSignature != null
            ? userSignature!
            : Uint8List(0));
    Uint8List serializedAppSignature = CompactSize.encode(
        includeSignature && appSignature != null
            ? appSignature!
            : Uint8List(0));
    Uint8List serializedContents = CompactSize.encode(contents);
    return (BytesBuilder()
          ..add(serializedVersion)
          ..add(serializedAddress)
          ..add(serializedTimestamp)
          ..add(serializedAssetRef)
          ..add(serializedUserSignature)
          ..add(serializedAppSignature)
          ..add(serializedContents))
        .toBytes();
  }

  /// Overrides [==] operator to use [id] as the differentiation parameter.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  /// Overrides toString() method for useful error messages
  @override
  String toString() => ''''
      TransactionModel - 
      id : $id,
      version : $version,
      address : $address,
      asset_ref : $assetRef,
      block : ${block?.id ?? 'null'},
      timestamp : $timestamp,
      userSignature : $userSignature,
      appSignature: $appSignature
    ''';

  @override
  int get hashCode => id.hashCode;
}

/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

/// {@category Node}
/// Handles transactions in the chain.
library transaction;

import 'dart:typed_data';

import 'package:pointycastle/export.dart';
import 'package:idb_sqflite/idb_sqflite.dart' if (dart.library.ffi) 'package:sqlite3/sqlite3.dart';

import '../../utils/utils.dart';
import '../block/block_model.dart';
import '../key/key_model.dart';
import 'transaction_model.dart';
import 'transaction_repository.dart';

export 'transaction_model.dart';
export 'transaction_repository.dart';

/// The service to manage transactions in the chain.
class TransactionService {
  final TransactionRepository _repository;

  TransactionService(Database db) : _repository = TransactionRepository(db);

  /// Creates a [TransactionModel] with [contents].
  ///
  /// Uses the [KeyModel.privateKey] from [key] to sign the transaction. If the
  /// [assetRef] is not set, it defaults to AA==. The return is an uncommitted
  /// [TransactionModel]. The [TransactionModel] should be added to a
  /// [BlockModel] by setting the [TransactionModel.block] and
  /// [TransactionModel.merkelProof] values and calling the [commit] method.
  TransactionModel create(Uint8List contents, KeyModel key,
      {String assetRef = 'AA=='}) {
    TransactionModel txn = TransactionModel(
        address: key.address, contents: contents, assetRef: assetRef);
    txn.signature =
        Rsa.sign(key.privateKey, txn.serialize(includeSignature: false));
    txn.id = Digest("SHA3-256").process(txn.serialize());
    _repository.save(txn);
    return txn;
  }

  /// Commits a [TransactionModel] by persisting its [TransactionModel.block]
  /// and [TransactionModel.merkelProof] values.
  void commit(
      Uint8List transactionId, BlockModel block, Uint8List merkelProof) {
    _repository.commit(transactionId, block, merkelProof);
  }

  /// Validates the [TransactionModel] inclusion in [TransactionModel.block] by
  /// validating its [TransactionModel.merkelProof] with [MerkelTree.validate].
  static bool validateInclusion(TransactionModel transaction, Uint8List root) =>
      MerkelTree.validate(transaction.id!, transaction.merkelProof!, root);

  /// Validates the [TransactionModel] integrity by rebuilding its hash [TransactionModel.id].
  static bool validateIntegrity(TransactionModel transaction) =>
      Bytes.memEquals(
          Digest("SHA3-256").process(transaction.serialize()), transaction.id!);

  /// Validates the author of the [TransactionModel] by calling [Rsa.verify] with
  /// its [TransactionModel.signature].
  static bool validateAuthor(
          TransactionModel transaction, RsaPublicKey pubKey) =>
      Rsa.verify(pubKey, transaction.serialize(includeSignature: false),
          transaction.signature!);

  /// Gets all the transactions from a [BlockModel] by its [BlockModel.id].
  List<TransactionModel> getByBlock(Uint8List id) =>
      _repository.getByBlockId(id);

  /// Gets all the transactions that were not committed by [commit].
  List<TransactionModel> getPending() => _repository.getByBlockId(null);
}

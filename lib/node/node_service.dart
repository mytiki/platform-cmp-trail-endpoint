/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

/// The core of the Blockchain.
/// {@category Node}
library node;

import 'dart:async';
import 'dart:typed_data';

import 'package:idb_sqflite/idb_sqflite.dart' if (dart.library.ffi) 'package:sqlite3/sqlite3.dart';

import '../utils/utils.dart';
import 'backup/backup_service.dart';
import 'block/block_service.dart';
import 'key/key_service.dart';
import 'transaction/transaction_service.dart';

/// The node slice is responsible for orchestrating the other slices to keep the
/// blockchain locally, persist blocks and syncing with remote backup and other
/// blockchains in the network.
class NodeService {
  late final TransactionService _transactionService;
  late final BlockService _blockService;
  late final KeyModel _primaryKey;
  late final BackupService _backupService;
  late final Duration _blockInterval;
  late final int _maxTransactions;

  Timer? _blockTimer;

  String get address => Bytes.base64UrlEncode(_primaryKey.address);
  Database get database => _blockService.database;

  set blockInterval(Duration val) => _blockInterval = val;
  set maxTransactions(int val) => _maxTransactions = val;
  set transactionService(TransactionService val) => _transactionService = val;
  set blockService(BlockService val) => _blockService = val;
  set backupService(BackupService val) => _backupService = val;
  set primaryKey(KeyModel val) => _primaryKey = val;

  startBlockTimer() => _blockTimer == null ? _startBlockTimer() : null;

  Future<void> init() async {
    _startBlockTimer();
  }

  /// Creates a [TransactionModel] with the [contents] and save to local database.
  ///
  /// When a [TransactionModel] is created it is not added to the next block
  /// immediately. It needs to wait until the [_blockTimer] runs again to check if
  /// the oldest transaction was created more than [_blockInterval] duration or
  /// if there are more than [_maxTransactions] waiting to be added to a
  /// [BlockModel].
  Future<TransactionModel> write(Uint8List contents) async {
    TransactionModel transaction =
        _transactionService.create(contents, _primaryKey);
    List<TransactionModel> transactions = _transactionService.getPending();
    if (transactions.length >= _maxTransactions) {
      await _createBlock(transactions);
    }
    return transaction;
  }

  /// Gets a serialized block by its [id].
  Uint8List? getBlock(Uint8List id) {
    BlockModel? block = _blockService.get(id);
    if (block == null) return null;

    List<TransactionModel> transactions = _transactionService.getByBlock(id);
    if (transactions.isEmpty) return null;

    return _serializeBlock(block, transactions);
  }

  void _startBlockTimer() {
    if (_blockTimer == null || !_blockTimer!.isActive) {
      _blockTimer = Timer.periodic(_blockInterval, (_) async {
        List<TransactionModel> transactions = _transactionService.getPending();
        if (transactions.isNotEmpty) {
          await _createBlock(transactions);
        }
      });
    }
  }

  Future<void> _createBlock(List<TransactionModel> transactions) async {
    List<Uint8List> hashes = transactions.map((e) => e.id!).toList();
    MerkelTree merkelTree = MerkelTree.build(hashes);
    BlockModel header = _blockService.create(merkelTree.root!);

    for (TransactionModel transaction in transactions) {
      _transactionService.commit(
          transaction.id!, header, merkelTree.proofs[transaction.id]!);
    }
    _blockService.commit(header);
    _backupService.block(header.id!);
  }

  Uint8List? _serializeBlock(
      BlockModel block, List<TransactionModel> transactions) {
    BytesBuilder bytes = BytesBuilder();
    bytes.add(block.serialize());
    bytes.add(CompactSize.encode(
        Bytes.encodeBigInt(BigInt.from(transactions.length))));
    for (TransactionModel transaction in transactions) {
      bytes.add(CompactSize.encode(transaction.serialize()));
    }
    return bytes.toBytes();
  }
}

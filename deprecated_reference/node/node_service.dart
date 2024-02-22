/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'dart:async';
import 'dart:typed_data';

import 'package:sqlite3/common.dart';

import '../key.dart';
import '../utils/bytes.dart';
import '../utils/compact_size.dart';
import '../utils/merkel_tree.dart';
import 'backup/backup_service.dart';
import 'block/block_model.dart';
import 'block/block_service.dart';
import 'transaction/transaction_model.dart';
import 'transaction/transaction_service.dart';
import 'xchain/xchain_service.dart';

/// The node service is responsible for orchestrating the other service to
/// keep the blockchain locally, persist blocks and syncing with
/// remote backup and other blockchains in the network.
class NodeService {
  late final TransactionService _transactionService;
  late final BlockService _blockService;
  late final BackupService _backupService;
  late final Duration _blockInterval;
  late final int _maxTransactions;
  late final XChainService _xChainService;
  late final Key _key;

  Timer? _blockTimer;

  /// Returns the in-use [address]
  String get address => _key.address;

  /// Returns the in-use [id]
  String get id => _key.id;

  /// Returns the in-use [database]
  CommonDatabase get database => _blockService.database;

  /// Set the interval on which to create a block if there
  /// are any pending transactions
  set blockInterval(Duration duration) => _blockInterval = duration;

  /// Set limit of pending transactions at which to automatically
  /// create a block
  set maxTransactions(int max) => _maxTransactions = max;

  /// The [TransactionService] to use
  set transactionService(TransactionService service) =>
      _transactionService = service;

  /// The [BlockService] to use
  set blockService(BlockService service) => _blockService = service;

  /// The [BackupService] to use
  set backupService(BackupService service) => _backupService = service;

  /// The [Key] for the wallet to use
  set key(Key key) => _key = key;

  /// The [XChainService] to use
  set xChainService(XChainService val) => _xChainService = val;

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
  Future<TransactionModel> write(Uint8List contents,
      {String assetRef = ''}) async {
    TransactionModel transaction =
        await _transactionService.create(contents, _key, assetRef: assetRef);
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

  /// Sync an [address] adding new blocks and transactions to the
  /// local [database].
  ///
  /// Use [onTxnAdded] to asynchronously interact with synced transactions.
  Future<void> sync(
      String address, Function(TransactionModel) onTxnAdded) async {
    if (address != this.address) {
      await _xChainService.sync(address,
          (BlockModel block, List<TransactionModel> txns) {
        for (TransactionModel txn in txns) {
          _transactionService.tryAdd(txn);
          onTxnAdded(txn);
        }
        _blockService.tryAdd(block);
      });
    }
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

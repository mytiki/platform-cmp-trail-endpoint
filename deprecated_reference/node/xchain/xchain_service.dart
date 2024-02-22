/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'dart:convert';
import 'dart:typed_data';

import 'package:sqlite3/common.dart';
import 'package:tiki_idp/tiki_idp.dart';

import '../../utils/bytes.dart';
import '../../utils/compact_size.dart';
import '../../utils/merkel_tree.dart';
import '../block/block_model.dart';
import '../transaction/transaction_model.dart';
import '../transaction/transaction_service.dart';
import 'xchain_client.dart';
import 'xchain_model.dart';
import 'xchain_repository.dart';

/// A service to retrieve blocks (and transactions) from other
/// addresses (WITHIN the app scope)
class XChainService {
  final XChainRepository _repository;
  final XChainClient _client;
  final TikiIdp _idp;
  final Set<String> _knownAddresses = {};

  /// Creates a new XChainService
  ///
  /// Requires a [_client] compatible service and [db] compatible
  /// database.
  XChainService(this._client, this._idp, CommonDatabase db)
      : _repository = XChainRepository(db);

  /// Fetch and verify all blocks and transactions for an
  /// [address] that are not already in local database.
  ///
  /// Use [onBlockAdded] to asynchronously interact with each
  /// new block identified.
  Future<void> sync(String address,
      Function(BlockModel, List<TransactionModel>) onBlockAdded) async {
    await _getPublicKey(address);
    if (_knownAddresses.contains(address)) {
      List<String> blockIds = await _getBlockIds(address);
      List<String> existing = _repository
          .getAllByAddress(Bytes.base64UrlDecode(address))
          .where((xc) => xc.blockId != null)
          .map((xc) => Bytes.base64UrlEncode(xc.blockId!))
          .toList();
      blockIds.removeWhere(
          (id) => existing.contains(id.replaceAll(".block", "").split("/")[1]));
      List<Future> fetches = [];
      for (String key in blockIds) {
        fetches.add(_fetchBlock(key, address, onBlockAdded));
      }
      await Future.wait(fetches);
    }
  }

  /// Returns the [RsaPublicKey] for the [address]. If
  /// the public key is not already in local memory, retrieve it
  /// from storage.
  Future<void> _getPublicKey(String address) async {
    if (!_knownAddresses.contains(address)) {
      Uint8List? pubKeyBytes = await _client.read('$address/public.key');
      if (pubKeyBytes == null) return;
      _idp.import(address, base64.encode(pubKeyBytes), public: true);
      _knownAddresses.add(address);
    }
  }

  /// Returns a List of block ids that are not already synced.
  Future<List<String>> _getBlockIds(String address) async {
    Set<String> allBlockIds = (await _client.list(address))
        .where((key) => key.endsWith('.block'))
        .toSet();
    Set<String> syncedBlockIds = _repository
        .getAllByAddress(Bytes.base64UrlDecode(address))
        .map((xc) => xc.src)
        .toSet();
    return allBlockIds.where((key) => !syncedBlockIds.contains(key)).toList();
  }

  /// Fetches and verifies ([publicKey]) a block using it's storage [key]
  Future<void> _fetchBlock(String key, String address,
      Function(BlockModel, List<TransactionModel>) onBlockAdded) async {
    Uint8List? bytes = await _client.read(key);
    if (bytes != null) {
      List<Uint8List> signedBlock = CompactSize.decode(bytes);
      List<Uint8List> decodedBlock =
          CompactSize.decode(signedBlock.elementAt(1));
      String id = key.split("/").last.replaceAll('.block', '');
      BlockModel block = BlockModel(
          id: Bytes.base64UrlDecode(id),
          version: Bytes.decodeBigInt(decodedBlock[0]).toInt(),
          timestamp: DateTime.fromMillisecondsSinceEpoch(
              Bytes.decodeBigInt(decodedBlock[1]).toInt() * 1000),
          previousHash: decodedBlock[2],
          transactionRoot: decodedBlock[3]);

      List<TransactionModel> txns =
          await _decodeAndVerifyTxns(decodedBlock, address, block);

      if (txns.isNotEmpty) {
        onBlockAdded(block, txns);
        _repository.save(XChainModel(key,
            address: txns.elementAt(0).address,
            blockId: block.id,
            fetchedOn: DateTime.now()));
      }
    }
  }

  /// Returns decoded and verified transactions for a [decodedBlock]
  Future<List<TransactionModel>> _decodeAndVerifyTxns(
      List<Uint8List> decodedBlock, String address, BlockModel block) async {
    int txnCount = Bytes.decodeBigInt(decodedBlock[4]).toInt();
    List<TransactionModel> all = [];
    List<TransactionModel> verified = [];
    for (int i = 0; i < txnCount; i++) {
      TransactionModel txn = TransactionModel.deserialize(decodedBlock[i + 5]);
      txn.block = block;
      all.add(txn);
    }
    MerkelTree merkelTree =
        MerkelTree.build(all.map((txn) => txn.id!).toList());
    for (int i = 0; i < txnCount; i++) {
      all.elementAt(i).merkelProof = merkelTree.proofs[all[i].id];
      if (await TransactionService.validateAuthor(
              all.elementAt(i), address, _idp) &&
          TransactionService.validateInclusion(
              all.elementAt(i), block.transactionRoot)) {
        verified.add(all.elementAt(i));
      }
    }
    return verified;
  }
}

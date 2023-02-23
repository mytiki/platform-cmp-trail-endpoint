/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */
/// {@category Node}
import 'dart:typed_data';

import 'package:idb_sqflite/idb_sqflite.dart' if (dart.library.ffi) 'package:sqlite3/sqlite3.dart';

import '../../utils/bytes.dart';
import '../block/block_model.dart';
import '../block/block_repository.dart';
import 'transaction_model.dart';

/// The repository for [TransactionModel] persistence in [Database].
class TransactionRepository {
  /// The [TransactionModel] table name in [_db].
  ///
  /// It could not be 'transaction' to avoid protected terms usage in sqlite.
  static const table = 'txn';

  /// The [TransactionModel.id] column.
  static const columnId = 'id';

  /// The [TransactionModel.merkelProof] column.
  static const columnMerkelProof = 'merkel_proof';

  /// The [TransactionModel.version] column.
  static const columnVersion = 'version';

  /// The [TransactionModel.address] column.
  static const columnAddress = 'address';

  /// The [TransactionModel.contents] column.
  static const columnContents = 'contents';

  /// The [TransactionModel.assetRef] column.
  static const columnAssetRef = 'asset_ref';

  /// The [TransactionModel.block] column identified by [BlockModel.id].
  static const columnBlockId = 'block_id';

  /// The [TransactionModel.timestamp] column.
  static const columnTimestamp = 'timestamp';

  /// The [TransactionModel.signature] column.
  static const columnSignature = 'signature';

  /// The [Database] used to persist [TransactionModel].
  final Database _db;

  /// Builds a [TransactionRepository] that will use [_db] for persistence.
  ///
  /// It calls [_createTable] to make sure the table exists.
  TransactionRepository(this._db) {
    _createTable();
  }

  /// Creates the [TransactionRepository.table] if it does not exist.
  void _createTable() => _db.execute('''
    CREATE TABLE IF NOT EXISTS $table (
      $columnId BLOB PRIMARY KEY NOT NULL,
      $columnMerkelProof BLOB,
      $columnVersion INTEGER NOT NULL,
      $columnAddress BLOB NOT NULL,
      $columnContents BLOB NOT NULL,
      $columnAssetRef TEXT NOT NULL,
      $columnBlockId BLOB, 
      $columnTimestamp INTEGER NOT NULL,
      $columnSignature BlOB NOT NULL,
      FOREIGN KEY($columnBlockId) 
        REFERENCES ${BlockRepository.table}(${BlockRepository.columnId})
     ); 
    ''');

  /// Persists a [transaction] in [_db].
  void save(TransactionModel transaction) => _db.execute('''
    INSERT INTO $table 
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    ''', [
        transaction.id,
        transaction.merkelProof,
        transaction.version,
        transaction.address,
        transaction.contents,
        transaction.assetRef,
        transaction.block?.id,
        transaction.timestamp.millisecondsSinceEpoch,
        transaction.signature,
      ]);

  /// Commits the [transaction] by saving its [TransactionModel.merkelProof] and
  /// [TransactionModel.block]
  void commit(Uint8List id, BlockModel block, Uint8List proof) =>
      _db.execute('''
    UPDATE $table 
    SET $columnMerkelProof = x'${Bytes.hexEncode(proof)}', 
    $columnBlockId =  x'${Bytes.hexEncode(block.id!)}' 
    WHERE $columnId = x'${Bytes.hexEncode(id)}'; ''');

  /// Gets the [List] of [TransactionModel] from the [BlockModel] from its [BlockModel.id].
  List<TransactionModel> getByBlockId(Uint8List? id) => _select(
      whereStmt: id == null
          ? 'WHERE $columnBlockId IS NULL'
          : "WHERE $columnBlockId = x'${Bytes.hexEncode(id)}'");

  /// Gets a [TransactionModel] by its [id]
  TransactionModel? getById(Uint8List id) {
    List<TransactionModel> txns = _select(
        whereStmt: "WHERE $table.$columnId = x'${Bytes.hexEncode(id)}'");
    return txns.isEmpty ? null : txns.first;
  }

  List<TransactionModel> _select(
      {String? whereStmt, int? page, int pageSize = 100}) {
    ResultSet results = _db.select('''
      SELECT 
        $table.$columnId as '$table.$columnId',
        $table.$columnVersion as '$table.$columnVersion',
        $table.$columnAddress as '$table.$columnAddress',
        $table.$columnContents as '$table.$columnContents',
        $table.$columnAssetRef as '$table.$columnAssetRef',
        $table.$columnMerkelProof as '$table.$columnMerkelProof',
        $table.$columnBlockId as '$table.$columnBlockId',
        $table.$columnTimestamp as '$table.$columnTimestamp',
        $table.$columnSignature as '$table.$columnSignature',
        $table.oid as 'oid',
        ${BlockRepository.table}.${BlockRepository.columnId} as '${BlockRepository.table}.${BlockRepository.columnId}',
        ${BlockRepository.table}.${BlockRepository.columnVersion} as '${BlockRepository.table}.${BlockRepository.columnVersion}',
        ${BlockRepository.table}.${BlockRepository.columnPreviousHash} as '${BlockRepository.table}.${BlockRepository.columnPreviousHash}',
        ${BlockRepository.table}.${BlockRepository.columnTransactionRoot} as '${BlockRepository.table}.${BlockRepository.columnTransactionRoot}',
        ${BlockRepository.table}.${BlockRepository.columnTimestamp} as '${BlockRepository.table}.${BlockRepository.columnTimestamp}'
      FROM $table
      LEFT JOIN ${BlockRepository.table}
      ON $table.$columnBlockId = ${BlockRepository.table}.${BlockRepository.columnId}
      ${whereStmt ?? ''}
      ORDER BY oid ASC
      ${page == null ? '' : 'LIMIT ${page * pageSize},$pageSize'};
      ''');
    List<TransactionModel> transactions = [];
    for (final Row row in results) {
      Map<String, dynamic>? blockMap =
          row['${BlockRepository.table}.${BlockRepository.columnId}'] == null
              ? null
              : {
                  BlockRepository.columnId: row[
                      '${BlockRepository.table}.${BlockRepository.columnId}'],
                  BlockRepository.columnVersion: row[
                      '${BlockRepository.table}.${BlockRepository.columnVersion}'],
                  BlockRepository.columnPreviousHash: row[
                      '${BlockRepository.table}.${BlockRepository.columnPreviousHash}'],
                  BlockRepository.columnTransactionRoot: row[
                      '${BlockRepository.table}.${BlockRepository.columnTransactionRoot}'],
                  BlockRepository.columnTimestamp:
                      row['${BlockRepository.table}.$columnTimestamp'],
                };
      Map<String, dynamic>? transactionMap = {
        columnId: row['$table.$columnId'],
        columnMerkelProof: row['$table.$columnMerkelProof'],
        columnVersion: row['$table.$columnVersion'],
        columnAddress: row['$table.$columnAddress'],
        columnContents: row['$table.$columnContents'],
        columnAssetRef: row['$table.$columnAssetRef'],
        'block': blockMap != null ? BlockModel.fromMap(blockMap) : null,
        columnTimestamp: row['$table.$columnTimestamp'],
        columnSignature: row['$table.$columnSignature'],
      };
      TransactionModel transaction = TransactionModel.fromMap(transactionMap);
      transactions.add(transaction);
    }
    return transactions;
  }
}

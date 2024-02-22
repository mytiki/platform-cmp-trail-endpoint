/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */

import 'dart:typed_data';

import 'package:sqlite3/common.dart';

import '../../utils/bytes.dart';
import 'block_model.dart';

/// The repository for [BlockModel] persistence in [CommonDatabase].
class BlockRepository {
  /// The [BlockModel] table name in [db].
  static const table = 'block';

  /// The [BlockModel.id] column.
  static const columnId = 'id';

  /// The [BlockModel.version] column.
  static const columnVersion = 'version';

  /// The [BlockModel.previousHash] column.
  static const columnPreviousHash = 'previous_hash';

  /// The [BlockModel.transactionRoot] column.
  static const columnTransactionRoot = 'transaction_root';

  /// The [BlockModel.timestamp] column.
  static const columnTimestamp = 'timestamp';

  /// The [CommonDatabase] used to persist [BlockModel].
  final CommonDatabase db;

  /// Builds a [BlockRepository] that will use [db] for persistence.
  ///
  /// It calls [createTable] to make sure the table exists.
  BlockRepository(this.db) {
    createTable();
  }

  /// Creates the [BlockRepository.table] if it does not exist.
  void createTable() => db.execute('''
    CREATE TABLE IF NOT EXISTS $table (
      $columnId BLOB PRIMARY KEY NOT NULL,
      $columnVersion INTEGER NOT NULL,
      $columnPreviousHash BLOB,
      $columnTransactionRoot BLOB,
      $columnTimestamp INTEGER);
    ''');

  /// Persists a [block] in the local [db].
  void save(BlockModel block) => db.execute('''
    INSERT INTO $table 
    VALUES (?, ?, ?, ?, ?);
    ''', [
        block.id,
        block.version,
        block.previousHash,
        block.transactionRoot,
        block.timestamp.millisecondsSinceEpoch
      ]);

  /// Gets a [BlockModel] by its [BlockModel.id].
  BlockModel? getById(Uint8List id) {
    List<BlockModel> blocks = _select(
        whereStmt: "WHERE $table.$columnId = x'${Bytes.hexEncode(id)}'");
    return blocks.isNotEmpty ? blocks[0] : null;
  }

  /// Gets the last persisted [BlockModel].
  BlockModel? getLast() {
    List<BlockModel> blocks = _select(last: true, page: 0, pageSize: 1);
    return blocks.isNotEmpty ? blocks.first : null;
  }

  List<BlockModel> _select(
      {int? page, int pageSize = 100, String? whereStmt, bool last = false}) {
    String limit = page != null ? 'LIMIT ${page * pageSize},$pageSize' : '';
    ResultSet results = db.select('''
      SELECT 
        $table.$columnId as '$table.$columnId',
        $table.$columnVersion as '$table.$columnVersion',
        $table.$columnPreviousHash as '$table.$columnPreviousHash',
        $table.$columnTransactionRoot as '$table.$columnTransactionRoot',
        $table.$columnTimestamp as '$table.$columnTimestamp'
      FROM $table
      ${whereStmt ?? ''}
      ORDER BY oid ${last ? 'DESC' : 'ASC'};
      $limit
      ''');
    List<BlockModel> blocks = [];
    for (final Row row in results) {
      Map<String, dynamic> blockMap = {
        columnId: row['$table.$columnId'],
        columnVersion: row['$table.$columnVersion'],
        columnPreviousHash: row['$table.$columnPreviousHash'],
        columnTransactionRoot: row['$table.$columnTransactionRoot'],
        columnTimestamp: row['$table.$columnTimestamp'],
      };
      BlockModel block = BlockModel.fromMap(blockMap);
      blocks.add(block);
    }
    return blocks;
  }
}

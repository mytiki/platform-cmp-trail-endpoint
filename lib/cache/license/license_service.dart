/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */
/// Manage License Records
/// {@category Cache}
library license;

import 'dart:convert';
import 'dart:typed_data';

import '../../node/node_service.dart';
import '../../node/transaction/transaction_model.dart';
import '../content_schema.dart';
import 'license_model.dart';
import 'license_repository.dart';
import 'license_use.dart';

export 'license_model.dart';
export 'license_repository.dart';
export 'license_use.dart';
export 'license_usecase.dart';
export 'license_usecase_enum.dart';

/// The service to manage [LicenseModel]s
class LicenseService {
  final LicenseRepository _repository;

  final NodeService _nodeService;

  LicenseService(db, this._nodeService) : _repository = LicenseRepository(db);

  /// Create a new on-chain [LicenseModel]
  ///
  /// This method creates a new pending transaction that will be committed
  /// during assembly of the next block in the chain.
  Future<LicenseModel> create(
      Uint8List title, List<LicenseUse> uses, String terms,
      {String? description, DateTime? expiry}) async {
    LicenseModel license = LicenseModel(title, uses, terms,
        description: description, expiry: expiry);

    Uint8List contents = (BytesBuilder()
          ..add(ContentSchema.license.toCompactSize())
          ..add(license.serialize()))
        .toBytes();
    TransactionModel transaction =
        await _nodeService.write(contents, assetRef: base64.encode(title));

    license.transactionId = transaction.id!;
    _repository.save(license);
    return license;
  }

  /// Returns the latest consent for a [title].
  LicenseModel? getLatest(Uint8List title) =>
      _repository.getLatestByTitle(title);

  /// Returns the latest consent for a [title].
  List<LicenseModel> getAll(Uint8List title) =>
      _repository.getAllByTitle(title);

  /// Returns the consent for a [id].
  LicenseModel? getById(Uint8List id) => _repository.getById(id);
}
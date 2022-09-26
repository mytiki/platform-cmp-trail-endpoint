// ignore_for_file: unused_field

/*
 * Copyright (c) TIKI Inc.
 * MIT license. See LICENSE file in root directory.
 */
/// {@category SDK}
import '../node/l0_storage.dart';
import '../tiki_sdk.dart';
import 'ownership_model.dart';
import 'ownership_repository.dart';

/// The service to manage ownership registries.
class OwnershipService {
  /// The default origin for all ownerships.
  final String _origin;

  final OwnershipRepository ownershipRepository;

  final L0Storage l0storage;

  OwnershipService(this._origin, db, this.l0storage)
      : ownershipRepository = OwnershipRepository(db);

  /// Creates a ownership register in the blockchain.
  ///
  /// This method creates a new transcation that will be commited in the
  /// next block in the chain. The [OwnershipModel.path] will be null until
  /// the transaction is commited through [updatePending].
  /// If no [origin] is provided the default [_origin] will be used
  void registerOwnership(
      {required String source,
      required List<TikiSdkDataTypeEnum> type,
      String? origin,
      String? about}) {
    throw UnimplementedError();
  }

  /// Updates the [OwnershipModel.path] of pending [OwnershipModel].
  ///
  /// Queries the [NodeService] for each [OwnershipModel.transactionId] and check
  /// if it was commited to update the [OwnershipModel.path].
  /// It uses the FIFO order to update the [OwnershipModel] and stops in the first
  /// one that was not updated yet, since the transactions are updated in FIFO order
  /// too.
  void updatePending() {
    throw UnimplementedError();
  }

  /// Gets a [OwnershipModel] by its [source] and [origin] from local database.
  ///
  /// If no [origin] is provided the default will be used
  OwnershipModel? getLocalBySource(String source, {String? origin}) {
    throw UnimplementedError();
  }

  /// Checks from [backupStorage] if an [address] has [OwnershipModel] over a [source] and [origin].
  OwnershipModel? checkOwnership(String address, String source,
      {String? origin}) {
    throw UnimplementedError();
  }
}
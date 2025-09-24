// dashboard/bloc/organization_bloc.dart
import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:untitled/dashboard/model/organization.dart';
import 'package:web3dart/web3dart.dart';

part 'organization_event.dart';
part 'organization_state.dart';

class OrganizationBloc extends Bloc<OrganizationEvent, OrganizationState> {
  final Web3Client _web3client;
  final DeployedContract _deployedContract;
  final EthPrivateKey _credentials;

  late ContractFunction _getOrganizationFunction;
  late ContractFunction _addAssociateFunction;
  late ContractFunction _removeAssociateFunction;

  OrganizationBloc({
    required Web3Client web3client,
    required DeployedContract deployedContract,
    required EthPrivateKey credentials,
  }) : _web3client = web3client,
       _deployedContract = deployedContract,
       _credentials = credentials,
       super(OrganizationInitial()) {
    _getOrganizationFunction = _deployedContract.function('getOrganization');
    _addAssociateFunction = _deployedContract.function(
      'addAssociateToOrganization',
    );
    _removeAssociateFunction = _deployedContract.function(
      'removeAssociateFromOrganization',
    );

    on<FetchOrganizationDetails>(_onFetchOrganizationDetails);
    on<AddMemberToOrganization>(_onAddMember);
    on<RemoveMemberFromOrganization>(_onRemoveMember);
  }

  Future<void> _onFetchOrganizationDetails(
    FetchOrganizationDetails event,
    Emitter<OrganizationState> emit,
  ) async {
    emit(OrganizationLoading());
    try {
      final ownerAddress = await _credentials.extractAddress();
      final orgData = await _web3client.call(
        contract: _deployedContract,
        function: _getOrganizationFunction,
        params: [ownerAddress],
      );

      // FIX: Access the inner list (orgData[0]) because web3dart can wrap single struct returns in an extra list.
      // The first element of the inner list (orgData[0][0]) is the organization name (a String).
      if ((orgData[0][0] as String).isEmpty) {
        // TRANSLATION: Changed the error message to English.
        emit(
          OrganizationError("Organization does not exist for your address."),
        );
        return;
      }

      // FIX: Pass the inner list (orgData[0]) to the factory method.
      final organization = Organization.fromContract(orgData[0]);

      emit(OrganizationLoaded(organization));
    } catch (e) {
      // TRANSLATION: Changed the error message to English.
      emit(OrganizationError("Error loading data: ${e.toString()}"));
    }
  }

  Future<void> _onAddMember(
    AddMemberToOrganization event,
    Emitter<OrganizationState> emit,
  ) async {
    try {
      final ownerAddress = await _credentials.extractAddress();
      final memberEthAddress = EthereumAddress.fromHex(event.memberAddress);

      await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _addAssociateFunction,
          parameters: [ownerAddress, memberEthAddress],
        ),
        chainId: 1337,
      );
      // TRANSLATION: Changed the success message to English.
      emit(OrganizationActionSuccess("Member added successfully!"));
    } catch (e) {
      // TRANSLATION: Changed the error message to English.
      emit(OrganizationError("Failed to add member: ${e.toString()}"));
    }
  }

  Future<void> _onRemoveMember(
    RemoveMemberFromOrganization event,
    Emitter<OrganizationState> emit,
  ) async {
    try {
      final memberEthAddress = EthereumAddress.fromHex(event.memberAddress);

      await _web3client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _deployedContract,
          function: _removeAssociateFunction,
          parameters: [memberEthAddress],
        ),
        chainId: 1337,
      );
      // TRANSLATION: Changed the success message to English.
      emit(OrganizationActionSuccess("Member removed successfully!"));
    } catch (e) {
      // TRANSLATION: Changed the error message to English.
      emit(OrganizationError("Failed to remove member: ${e.toString()}"));
    }
  }
}

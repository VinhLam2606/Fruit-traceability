import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:untitled/dashboard/model/organization.dart';
import 'package:untitled/dashboard/model/product.dart';
import 'package:web3dart/web3dart.dart';

part 'organization_event.dart';
part 'organization_state.dart';

class OrganizationBloc extends Bloc<OrganizationEvent, OrganizationState> {
  // Các biến này giờ đây sẽ được truyền từ bên ngoài vào
  final Web3Client _web3client;
  final DeployedContract _deployedContract;
  final EthPrivateKey _credentials;

  // Khai báo các hàm contract
  late ContractFunction _getOrganizationFunction;
  late ContractFunction _getProductsByOrgFunction;
  late ContractFunction _addAssociateFunction;
  late ContractFunction _removeAssociateFunction;

  // Cập nhật constructor để nhận các đối tượng Web3
  OrganizationBloc({
    required Web3Client web3client,
    required DeployedContract deployedContract,
    required EthPrivateKey credentials,
  }) : _web3client = web3client,
       _deployedContract = deployedContract,
       _credentials = credentials,
       super(OrganizationInitial()) {
    // Khởi tạo các hàm contract ngay tại đây
    _getOrganizationFunction = _deployedContract.function('getOrganization');
    // Lưu ý: getProductsByOrg có thể không tồn tại trong Users.sol, hãy đảm bảo contract ABI của bạn có hàm này
    _getProductsByOrgFunction = _deployedContract.function('getProductsByOrg');
    _addAssociateFunction = _deployedContract.function(
      'addAssociateToOrganization',
    );
    _removeAssociateFunction = _deployedContract.function(
      'removeAssociateFromOrganization',
    );

    // Đăng ký các event handlers
    on<FetchOrganizationDetails>(_onFetchOrganizationDetails);
    on<AddMemberToOrganization>(_onAddMember);
    on<RemoveMemberFromOrganization>(_onRemoveMember);
  }

  // Bỏ hoàn toàn hàm _initWeb3() cũ đi

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

      // Kiểm tra nếu tổ chức không tồn tại
      if ((orgData.first as String).isEmpty) {
        emit(OrganizationError("Tổ chức không tồn tại cho địa chỉ của bạn."));
        return;
      }

      final organization = Organization.fromContract(orgData);

      // Giả sử hàm getProductsByOrgFunction tồn tại để lấy sản phẩm
      // Nếu không, bạn có thể bỏ qua phần này
      final productsData = await _web3client.call(
        contract: _deployedContract,
        function: _getProductsByOrgFunction,
        params: [organization.organizationName],
      );

      final List<Product> products = (productsData.first as List<dynamic>)
          .map((p) => Product.fromContract(p as List<dynamic>))
          .toList();

      emit(OrganizationLoaded(organization, products));
    } catch (e) {
      emit(OrganizationError("Lỗi tải dữ liệu: ${e.toString()}"));
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
          parameters: [
            ownerAddress,
            memberEthAddress,
          ], // addAssociate cần 2 tham số: orgAddr, userAddr
        ),
        chainId: 1337,
      );
      emit(OrganizationActionSuccess("Thêm thành viên thành công!"));
    } catch (e) {
      emit(OrganizationError("Thêm thành viên thất bại: ${e.toString()}"));
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
          parameters: [
            memberEthAddress,
          ], // removeAssociate chỉ cần 1 tham số: userAddr
        ),
        chainId: 1337,
      );
      emit(OrganizationActionSuccess("Xóa thành viên thành công!"));
    } catch (e) {
      emit(OrganizationError("Xóa thành viên thất bại: ${e.toString()}"));
    }
  }
}

// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Types.sol";
import "./Users.sol";
import "./ProductLibrary.sol";

contract Products is Users {
    using ProductLibrary for mapping(string => Types.ProductHistory[]);
    using ProductLibrary for mapping(address => uint256[]);

    // --- STATE ---
    Types.Product[] internal products;
    mapping(string => uint256) internal productIndexByBatchId;
    mapping(string => bool) internal batchIdExists;
    mapping(address => uint256[]) internal userOwnedProductIndices;
    mapping(string => Types.ProductHistory[]) internal productHistories;

    // --- EVENTS ---
    event ProductAdded(string batchId, string name, string orgName, address creator, uint256 time);
    event ProductTransferred(string batchId, address from, address to, uint256 time);
    event ProductInfoUpdated(string batchId, string desc, address updater, uint256 time);
    error NotRegistered();
    error NotManufacturer();
    error NotInOrg();
    error BatchExists();
    error BatchNotExist();
    error InvalidRecipient();
    error NotOwner();
    error NotOrgMember();

    // --- MODIFIERS ---
    modifier onlyOrganizationManufacturer() {
        if (!isRegisteredAuth(msg.sender)) revert NotRegistered();
        Types.UserDetails memory u = getUser(msg.sender);
        if (u.role != Types.UserRole.Manufacturer) revert NotManufacturer();
        if (!u.isAlreadyInAnyOrganization) revert NotInOrg();
        _;
    }

    // --- CORE ---
    // THAY ĐỔI: Cập nhật chữ ký hàm để nhận một tham số 'date_'
    function addAProduct(
        string memory batchId,
        string memory name_,
        uint256 date_
    ) public onlyOrganizationManufacturer {
        if (bytes(batchId).length == 0) revert BatchNotExist();
        if (batchIdExists[batchId]) revert BatchExists();

        Types.UserDetails memory creator = getUser(msg.sender);
        address orgOwner = memberToOrganizationOwner[creator.userID];
        if (orgOwner == address(0)) revert NotInOrg();

        string memory orgName = organizations[orgOwner].organizationName;
        if (bytes(orgName).length == 0) revert NotInOrg();

        // THAY ĐỔI: Cập nhật việc khởi tạo Product
        Types.Product memory p = Types.Product({
            batchId: batchId,
            name: name_,
            organizationName: orgName,
            creator: msg.sender,
            date: date_, // Sử dụng trường 'date' mới
            currentOwner: msg.sender
        });

        uint256 idx = products.length;
        products.push(p);
        productIndexByBatchId[batchId] = idx;
        batchIdExists[batchId] = true;
        userOwnedProductIndices[msg.sender].push(idx);

        productHistories.addProductHistory(batchId, address(0), msg.sender, "Created");
        emit ProductAdded(batchId, name_, orgName, msg.sender, block.timestamp);
    }

    function transferProduct(string memory batchId, address to) public onlyRegisteredUser {
        if (!batchIdExists[batchId]) revert BatchNotExist();
        if (to == address(0)) revert InvalidRecipient();
        if (!isRegisteredAuth(to)) revert NotRegistered();

        uint256 idx = productIndexByBatchId[batchId];
        Types.Product storage p = products[idx];
        if (p.currentOwner != msg.sender) revert NotOwner();

        address from = p.currentOwner;
        p.currentOwner = to;
        userOwnedProductIndices.removeProductIndexFromUser(from, idx);
        userOwnedProductIndices[to].push(idx);

        productHistories.addProductHistory(batchId, from, to, "Transferred");
        emit ProductTransferred(batchId, from, to, block.timestamp);
    }

    function updateProductDescription(string memory batchId, string memory desc) public onlyRegisteredUser {
        if (!batchIdExists[batchId]) revert BatchNotExist();
        if (!users[msg.sender].isAlreadyInAnyOrganization) revert NotInOrg();

        Types.Product storage p = products[productIndexByBatchId[batchId]];
        address productOrgOwner = memberToOrganizationOwner[p.creator];
        address updaterOrgOwner = memberToOrganizationOwner[msg.sender];
        if (updaterOrgOwner != productOrgOwner) revert NotOrgMember();

        productHistories.addProductHistory(batchId, msg.sender, p.currentOwner, desc);
        emit ProductInfoUpdated(batchId, desc, msg.sender, block.timestamp);
    }

    // --- VIEW ---
    // Các hàm view không cần thay đổi vì chúng trả về toàn bộ struct,
    // và struct đã được cập nhật trong Types.sol
    function getProduct(string memory batchId) public view returns (Types.Product memory) {
        if (!batchIdExists[batchId]) revert BatchNotExist();
        return products[productIndexByBatchId[batchId]];
    }

    function getProductHistory(string memory batchId) public view onlyRegisteredUser returns (Types.ProductHistory[] memory) {
        if (!batchIdExists[batchId]) revert BatchNotExist();
        return productHistories[batchId];
    }

    function getAllProducts() public view returns (Types.Product[] memory) {
        return products;
    }

    function getProductsByUser(address user) public view returns (Types.Product[] memory) {
        uint256[] memory indices = userOwnedProductIndices[user];
        Types.Product[] memory res = new Types.Product[](indices.length);
        for (uint i = 0; i < indices.length; i++) res[i] = products[indices[i]];
        return res;
    }

    function getProductsByOrg(string memory orgName) public view returns (Types.Product[] memory) {
        uint count = 0;
        for (uint i = 0; i < products.length; i++) {
            if (keccak256(bytes(products[i].organizationName)) == keccak256(bytes(orgName))) {
                count++;
            }
        }

        Types.Product[] memory res = new Types.Product[](count);
        uint index = 0;
        for (uint i = 0; i < products.length; i++) {
            if (keccak256(bytes(products[i].organizationName)) == keccak256(bytes(orgName))) {
                res[index] = products[i];
                index++;
            }
        }

        return res;
    }
}
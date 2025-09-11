// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Types.sol";
import "./Users.sol";
import "./ProductLibrary.sol";

contract Products is Users {
    using ProductLibrary for mapping(string => Types.ProductHistory[]);
    using ProductLibrary for mapping(address => uint256[]);

    // --- STATE VARIABLES ---
    Types.Product[] internal products;
    mapping(string => uint256) internal productIndexByBatchId;
    mapping(string => bool) internal batchIdExists;
    mapping(address => uint256[]) internal userOwnedProductIndices;
    mapping(string => Types.ProductHistory[]) internal productHistories;
    // --- EVENTS ---
    event ProductAdded(string batchId, string name, string organizationName, address creator, uint256 timestamp);
    event ProductTransferred(string batchId, address from, address to, uint256 timestamp);
    event ProductInfoUpdated(string batchId, string description, address updater, uint256 timestamp);
    // --- MODIFIERS ---
    modifier onlyOrganizationManufacturer() {
        require(isRegistered(msg.sender), "Caller not registered");
        Types.UserDetails memory u = getUser(msg.sender);
        require(u.role == Types.UserRole.Manufacturer, "Caller is not a Manufacturer");
        require(u.isAlreadyInAnyOrganization, "Caller is not in any organization");
        _;
    }
    
    // --- CORE FUNCTIONS ---
    function addAProduct(
        string memory batchId,
        string memory name_,
        uint256 harvestDate_,
        uint256 expiryDate_
    ) public onlyOrganizationManufacturer {
        require(bytes(batchId).length > 0, "Batch ID required");
        require(!batchIdExists[batchId], "Batch ID already exists");

        Types.UserDetails memory creator = getUser(msg.sender);
        
        address orgOwnerAddress = memberToOrganizationOwner[creator.userID];
        require(orgOwnerAddress != address(0), "User is not associated with any organization");

        string memory orgName = organizations[orgOwnerAddress].organizationName;
        require(bytes(orgName).length > 0, "Creator's organization not found");

        Types.Product memory p = Types.Product({
            batchId: batchId,
            name: name_,
            organizationName: orgName,
            creator: msg.sender,
            harvestDate: harvestDate_,
            expiryDate: expiryDate_,
           
            currentOwner: msg.sender
        });

        uint256 newProductIndex = products.length;
        products.push(p);
        productIndexByBatchId[batchId] = newProductIndex;
        batchIdExists[batchId] = true;
        userOwnedProductIndices[msg.sender].push(newProductIndex);

        productHistories.addProductHistory(batchId, address(0), msg.sender, "Created");
        emit ProductAdded(batchId, name_, orgName, msg.sender, block.timestamp);
    }

    function transferProduct(string memory batchId, address to) public onlyRegisteredUser {
        require(batchIdExists[batchId], "Product does not exist");
        require(to != address(0), "Recipient is invalid");
        require(isRegistered(to), "Recipient must be a registered user");

        uint256 productIndex = productIndexByBatchId[batchId];
        Types.Product storage p = products[productIndex];
        
        require(p.currentOwner == msg.sender, "Caller is not the current owner");

        address from = p.currentOwner;
        p.currentOwner = to;
        
        userOwnedProductIndices.removeProductIndexFromUser(from, productIndex);
        userOwnedProductIndices[to].push(productIndex);

        productHistories.addProductHistory(batchId, from, to, "Transferred");
        emit ProductTransferred(batchId, from, to, block.timestamp);
    }

    /**
     * @notice Updates the product history with a new description/note.
     * @dev Allows any member of the product's original organization to add to its history.
     * @param batchId The batch ID of the product to update.
     * @param description A new description or note to add to the product's history.
     */
    function updateProductDescription(string memory batchId, string memory description) public onlyRegisteredUser {
        require(batchIdExists[batchId], "Product does not exist");

        // KIỂM TRA 1: Người gọi phải là thành viên của một tổ chức.
        require(users[msg.sender].isAlreadyInAnyOrganization, "Caller must be a member of an organization");

        // Lấy thông tin sản phẩm
        Types.Product storage p = products[productIndexByBatchId[batchId]];
        
        // KIỂM TRA 2: Người gọi phải thuộc cùng tổ chức đã tạo ra sản phẩm.
        // Chúng ta so sánh địa chỉ chủ sở hữu tổ chức của người gọi và người tạo sản phẩm.
        address productOrgOwner = memberToOrganizationOwner[p.creator];
        address updaterOrgOwner = memberToOrganizationOwner[msg.sender];
        
        require(updaterOrgOwner == productOrgOwner, "Caller is not a member of the product's organization");

        // Thêm thông tin cập nhật vào lịch sử sản phẩm
        productHistories.addProductHistory(batchId, msg.sender, p.currentOwner, description);
        emit ProductInfoUpdated(batchId, description, msg.sender, block.timestamp);
    }

    // --- VIEW FUNCTIONS ---
    function getProduct(string memory batchId) public view returns (Types.Product memory) {
        require(batchIdExists[batchId], "Product does not exist");
        return products[productIndexByBatchId[batchId]];
    }
    
    function getProductHistory(string memory batchId) public view onlyRegisteredUser returns (Types.ProductHistory[] memory) {
        require(batchIdExists[batchId], "Product does not exist");
        return productHistories[batchId];
    }
    
    function getAllProducts() public view returns (Types.Product[] memory) {
        return products;
    }

    function getProductsByUser(address user) public view returns (Types.Product[] memory) {
        uint256[] memory indices = userOwnedProductIndices[user];
        Types.Product[] memory userProducts = new Types.Product[](indices.length);

        for (uint i = 0; i < indices.length; i++) {
            userProducts[i] = products[indices[i]];
        }
        
        return userProducts;
    }
}
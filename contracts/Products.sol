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
    mapping(string => Types.ProcessStep[]) internal productProcesses;

    // --- EVENTS ---
    event ProductAdded(string indexed batchId, string name, string orgName, address indexed creator, uint256 time);
    event ProductTransferred(string indexed batchId, address indexed from, address indexed to, uint256 time);
    event ProductInfoUpdated(string indexed batchId, string desc, address indexed updater, uint256 time);
    event ProductProcessAdded(string indexed batchId, string processName, uint8 processType, string orgName, address indexed performer, uint256 time);

    // --- ERRORS ---
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

    modifier onlySameOrgOrOwner(address currentOwner) {
        // determine organization owner for the product owner
        address productOwnerOrgOwner = memberToOrganizationOwner[currentOwner];
        if (productOwnerOrgOwner == address(0) && organizations[currentOwner].ownerAddress != address(0)) {
            productOwnerOrgOwner = currentOwner;
        }

        // determine organization owner for the updater (msg.sender)
        address updaterOrgOwner = memberToOrganizationOwner[msg.sender];
        if (updaterOrgOwner == address(0) && organizations[msg.sender].ownerAddress != address(0)) {
            updaterOrgOwner = msg.sender;
        }

        bool sameOrg = (productOwnerOrgOwner != address(0) &&
                        updaterOrgOwner != address(0) &&
                        productOwnerOrgOwner == updaterOrgOwner);

        if (msg.sender != currentOwner && !sameOrg) revert NotOrgMember();
        _;
    }

    // --- CORE ---
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

        uint256 idx = products.length;
        products.push();

        Types.Product storage p = products[idx];
        p.batchId = batchId;
        p.name = name_;
        p.organizationName = orgName;
        p.creator = msg.sender;
        p.date = date_;
        p.currentOwner = msg.sender;
        p.status = "Created";
        // processSteps is automatically empty when created

        productIndexByBatchId[batchId] = idx;
        batchIdExists[batchId] = true;
        userOwnedProductIndices[msg.sender].push(idx);

        productHistories.addProductHistory(batchId, address(0), msg.sender, "Product Created");
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
        p.status = "Transferred";

        address recipientOrgOwner = memberToOrganizationOwner[to];
        if (recipientOrgOwner != address(0)) {
            string memory newOrgName = organizations[recipientOrgOwner].organizationName;
            if (bytes(newOrgName).length != 0) p.organizationName = newOrgName;
        }

        userOwnedProductIndices.removeProductIndexFromUser(from, idx);
        userOwnedProductIndices[to].push(idx);

        productHistories.addProductHistory(batchId, from, to, "Transferred");
        emit ProductTransferred(batchId, from, to, block.timestamp);
    }

    function addProcessStep(
        string memory batchId,
        string memory processName,
        Types.ProcessType processType,
        string memory description
    ) public onlyRegisteredUser onlySameOrgOrOwner(products[productIndexByBatchId[batchId]].currentOwner) {
        if (!batchIdExists[batchId]) revert BatchNotExist();
        if (!users[msg.sender].isAlreadyInAnyOrganization) revert NotInOrg();

        uint256 idx = productIndexByBatchId[batchId];
        Types.Product storage p = products[idx];

        address orgOwner = memberToOrganizationOwner[msg.sender];
        string memory orgName = organizations[orgOwner].organizationName;

        Types.ProcessStep memory ps = Types.ProcessStep({
            processName: processName,
            processType: processType,
            description: description,
            date: block.timestamp,
            organizationName: orgName
        });

        productProcesses[batchId].push(ps);

        // record history (performed by msg.sender, to = msg.sender for process action)
        productHistories.addProductHistory(batchId, msg.sender, msg.sender, string(abi.encodePacked("Process added: ", processName)));

        emit ProductProcessAdded(batchId, processName, uint8(processType), orgName, msg.sender, block.timestamp);
    }

    // --- VIEW FUNCTIONS ---
    function getProduct(string memory batchId) public view returns (Types.Product memory) {
        if (!batchIdExists[batchId]) revert BatchNotExist();

        Types.Product memory p = products[productIndexByBatchId[batchId]];

        p.processSteps = productProcesses[batchId];

        return p;
    }

    function getProductHistory(string memory batchId) public view returns (Types.ProductHistory[] memory) {
        if (!batchIdExists[batchId]) revert BatchNotExist();
        return productHistories[batchId];
    }

    function getProductProcesses(string memory batchId) public view returns (Types.ProcessStep[] memory) {
        if (!batchIdExists[batchId]) revert BatchNotExist();
        return productProcesses[batchId];
    }

    function getProcessesByType(string memory batchId, Types.ProcessType pType) public view returns (Types.ProcessStep[] memory) {
        if (!batchIdExists[batchId]) revert BatchNotExist();

        Types.ProcessStep[] storage all = productProcesses[batchId];
        uint256 count = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].processType == pType) count++;
        }

        Types.ProcessStep[] memory res = new Types.ProcessStep[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < all.length; i++) {
            if (all[i].processType == pType) {
                res[idx++] = all[i];
            }
        }
        return res;
    }

    function getLastProcessType(string memory batchId) public view returns (Types.ProcessType) {
        if (!batchIdExists[batchId]) revert BatchNotExist();
        Types.ProcessStep[] storage all = productProcesses[batchId];
        require(all.length > 0, "No processes recorded");
        return all[all.length - 1].processType;
    }

    function getAllProducts() public view returns (Types.Product[] memory) {
        return products;
    }

    function getProductsByUser(address user) public view returns (Types.Product[] memory) {
        uint256[] memory indices = userOwnedProductIndices[user];
        Types.Product[] memory res = new Types.Product[](indices.length);
        for (uint256 i = 0; i < indices.length; i++) res[i] = products[indices[i]];
        return res;
    }

    function getProductsByOrg(string memory orgName) public view returns (Types.Product[] memory) {
        uint256 count = 0;
        for (uint256 i = 0; i < products.length; i++) {
            if (keccak256(bytes(products[i].organizationName)) == keccak256(bytes(orgName))) {
                count++;
            }
        }

        Types.Product[] memory res = new Types.Product[](count);
        uint256 index = 0;
        for (uint256 i = 0; i < products.length; i++) {
            if (keccak256(bytes(products[i].organizationName)) == keccak256(bytes(orgName))) {
                res[index] = products[i];
                index++;
            }
        }

        return res;
    }
}

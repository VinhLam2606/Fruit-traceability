// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Types.sol";

contract Users {
    mapping(address => Types.UserDetails) internal users;
    mapping(address => Types.Organization) internal organizations;
    mapping(string => address) internal organizationNameToOwner;
    address[] internal organizationAddresses;

    mapping(address => address) internal memberToOrganizationOwner;

    event UserAdded(address indexed userAddr, string name, Types.UserRole role, uint256 date);
    event OrganizationAdded(address indexed orgAddr, string orgName, address owner, uint256 date);
    event AssociateAdded(address indexed orgAddr, address indexed userAddr, string userName);
    // MỚI: Event khi một thành viên bị xóa
    event AssociateRemoved(address indexed orgAddr, address indexed userAddr, string userName);

    modifier onlyRegisteredUser() {
        require(users[msg.sender].userID != address(0), "Caller is not a registered user");
        _;
    }

    modifier onlyOrganizationOwner(address orgAddr) {
        require(organizations[orgAddr].ownerAddress != address(0), "Organization does not exist");
        require(organizations[orgAddr].ownerAddress == msg.sender, "Caller is not organization owner");
        _;
    }

    function addUser(Types.UserDetails memory user) public {
        require(user.userID != address(0), "Invalid user address");
        require(users[user.userID].userID == address(0), "User already exists");
        users[user.userID] = Types.UserDetails({
            userID: user.userID,
            userName: user.userName,
            role: user.role,
            isAlreadyInAnyOrganization: false
        });
        emit UserAdded(user.userID, user.userName, user.role, block.timestamp);
    }

    function addUserThroughAddress(address userAddr, string memory name_, Types.UserRole role) public {
        addUser(Types.UserDetails({
            userID: userAddr,
            userName: name_,
            role: role,
            isAlreadyInAnyOrganization: false
        }));
    }

    function getUser(address userAddr) public view returns (Types.UserDetails memory) {
        return users[userAddr];
    }

    function addOrganization(string memory name_, uint256 date_) public onlyRegisteredUser {
        require(organizationNameToOwner[name_] == address(0), "Organization name is already taken");

        Types.Organization storage newOrg = organizations[msg.sender];
        newOrg.organizationName = name_;
        newOrg.ownerName = users[msg.sender].userName;
        newOrg.ownerAddress = msg.sender;
        newOrg.establishedDate = date_;
        newOrg.organizationStatus = Types.AuthorizationStatus.Approved;

        // Add the owner as the first member
        users[msg.sender].isAlreadyInAnyOrganization = true;
        newOrg.organizationMembers.push(users[msg.sender]);
        memberToOrganizationOwner[msg.sender] = msg.sender;

        organizationNameToOwner[name_] = msg.sender;
        organizationAddresses.push(msg.sender);

        emit OrganizationAdded(msg.sender, name_, msg.sender, date_);
    }

    function addAssociateToOrganization(address orgAddr, address userAddr) public onlyOrganizationOwner(orgAddr) {
        require(users[userAddr].userID != address(0), "User is not registered");
        require(!users[userAddr].isAlreadyInAnyOrganization, "User is already in another organization");

        Types.Organization storage org = organizations[orgAddr];

        for (uint i = 0; i < org.organizationMembers.length; i++) {
            require(org.organizationMembers[i].userID != userAddr, "User is already a member of this organization");
        }

        users[userAddr].isAlreadyInAnyOrganization = true;
        org.organizationMembers.push(users[userAddr]);
        memberToOrganizationOwner[userAddr] = orgAddr;

        emit AssociateAdded(orgAddr, userAddr, users[userAddr].userName);
    }

    // MỚI: Hàm xóa thành viên khỏi tổ chức
    function removeAssociateFromOrganization(address userAddr) public {
        address orgAddr = msg.sender; // Chỉ chủ tổ chức (cũng là địa chỉ của tổ chức) mới có thể gọi
        require(organizations[orgAddr].ownerAddress == msg.sender, "Caller is not organization owner");
        require(users[userAddr].userID != address(0), "User is not registered");
        require(memberToOrganizationOwner[userAddr] == orgAddr, "User is not a member of this organization");
        require(userAddr != msg.sender, "Cannot remove the organization owner");

        Types.Organization storage org = organizations[orgAddr];

        // Tìm và xóa thành viên khỏi mảng organizationMembers
        for (uint i = 0; i < org.organizationMembers.length; i++) {
            if (org.organizationMembers[i].userID == userAddr) {
                // Sử dụng kỹ thuật "swap and pop"
                org.organizationMembers[i] = org.organizationMembers[org.organizationMembers.length - 1];
                org.organizationMembers.pop();
                break;
            }
        }

        // Cập nhật trạng thái của người dùng
        users[userAddr].isAlreadyInAnyOrganization = false;
        delete memberToOrganizationOwner[userAddr];

        emit AssociateRemoved(orgAddr, userAddr, users[userAddr].userName);
    }

    function getOrganization(address orgAddr) public view returns (Types.Organization memory) {
        return organizations[orgAddr];
    }

    function getOrganizationByName(string memory name_) public view returns (Types.Organization memory) {
        address orgAddr = organizationNameToOwner[name_];
        require(orgAddr != address(0), "Organization not found");
        return organizations[orgAddr];
    }

    function isRegistered(address account) public view returns (bool) {
        return users[account].userID != address(0);
    }

    function isOrganizationExists(string memory name_) public view returns (bool) {
        return organizationNameToOwner[name_] != address(0);
    }

    function getOrganizationAddresses() public view returns (address[] memory) {
        return organizationAddresses;
    }
}
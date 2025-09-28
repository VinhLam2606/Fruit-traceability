// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Types.sol";

contract Users {
    // --- AUTH STRUCT ---
    struct UserAuth {
        string username;
        string email;
        string privateKey; // Private key Ganache cung cấp
        bool isRegistered;
    }

    mapping(address => UserAuth) internal userAuths;

        // --- MODIFIERS ---
    modifier onlyRegisteredUser() {
        require(userAuths[msg.sender].isRegistered, "Caller is not a registered user");
        _;
    }

    // Giữ nguyên các mapping cho tổ chức & role
    mapping(address => Types.UserDetails) internal users;
    mapping(address => Types.Organization) internal organizations;
    mapping(string => address) internal organizationNameToOwner;
    address[] internal organizationAddresses;
    address[] internal userAddresses;

    mapping(address => address) internal memberToOrganizationOwner;

    // --- EVENTS ---
    event UserRegistered(address indexed userAddr, string username, string email);
    event UserAdded(address indexed userAddr, string name, Types.UserRole role, uint256 date);
    event OrganizationAdded(address indexed orgAddr, string orgName, address owner, uint256 date);
    event AssociateAdded(address indexed orgAddr, address indexed userAddr, string userName);

    // --- REGISTER AUTH ---
    function registerUser(
    address _userAddress,
    string memory _username,
    string memory _email
    ) public {
        require(!userAuths[_userAddress].isRegistered, "User already registered");

        userAuths[_userAddress] = UserAuth({
            username: _username,
            email: _email,
            privateKey: "", // bỏ đi, không cần lưu
            isRegistered: true
        });

        emit UserRegistered(_userAddress, _username, _email);
    }



    function getUserAuth(address _userAddress) public view returns (UserAuth memory) {
        return userAuths[_userAddress];
    }

    function isRegisteredAuth(address _userAddress) public view returns (bool) {
        return userAuths[_userAddress].isRegistered;
    }

    function addUser(Types.UserDetails memory user) public {
        require(user.userID != address(0), "Invalid user address");
        require(users[user.userID].userID == address(0), "User already exists");
        users[user.userID] = Types.UserDetails({
            userID: user.userID,
            userName: user.userName,
            role: user.role,
            isAlreadyInAnyOrganization: user.isAlreadyInAnyOrganization
        });
        userAddresses.push(user.userID);
        emit UserAdded(user.userID, user.userName, user.role, block.timestamp);
    }

    function addUserThroughAddress(address account, string memory name, Types.UserRole role) public {
        require(account != address(0), "Invalid address");
        require(users[account].userID == address(0), "User already exists");
        users[account] = Types.UserDetails({
            userID: account,
            userName: name,
            role: role,
            isAlreadyInAnyOrganization: false
        });
        userAddresses.push(account);
        emit UserAdded(account, name, role, block.timestamp);
    }

    function getUser(address account) public view returns (Types.UserDetails memory) {
        return users[account];
    }

    function getAllUsers() public view returns (Types.UserDetails[] memory) {
        Types.UserDetails[] memory allUsers = new Types.UserDetails[](userAddresses.length);
        for (uint i = 0; i < userAddresses.length; i++) {
            allUsers[i] = users[userAddresses[i]];
        }
        return allUsers;
    }

    function addOrganization(string memory name_, uint256 establishedDate_) public {
        require(msg.sender != address(0), "Invalid sender");
        require(users[msg.sender].userID != address(0), "Caller must be a registered user");
        require(!users[msg.sender].isAlreadyInAnyOrganization, "User already in an organization");

        Types.Organization storage org = organizations[msg.sender];
        org.organizationName = name_;
        org.ownerName = users[msg.sender].userName;
        org.ownerAddress = users[msg.sender].userID;
        org.establishedDate = establishedDate_;
        org.organizationStatus = Types.AuthorizationStatus.Pending;

        Types.UserDetails memory creator = users[msg.sender];
        creator.isAlreadyInAnyOrganization = true;
        org.organizationMembers.push(creator);

        users[msg.sender].isAlreadyInAnyOrganization = true;
        organizationAddresses.push(msg.sender);

        memberToOrganizationOwner[msg.sender] = msg.sender;

        organizationNameToOwner[name_] = msg.sender;
        emit OrganizationAdded(msg.sender, name_, msg.sender, block.timestamp);
        emit AssociateAdded(msg.sender, msg.sender, users[msg.sender].userName);
    }

    function addAssociateToOrganization(address userAddr) public onlyRegisteredUser {
        address orgAddr = msg.sender;

        require(organizations[orgAddr].ownerAddress == msg.sender, "Caller does not own an organization");
        require(userAddr != address(0), "Invalid user address");
        require(users[userAddr].userID != address(0), "User must be registered before adding to organization");
        require(!users[userAddr].isAlreadyInAnyOrganization, "User is already in another organization");

        Types.Organization storage org = organizations[orgAddr];

        for (uint i = 0; i < org.organizationMembers.length; i++) {
            if (org.organizationMembers[i].userID == userAddr) {
                revert("User is already a member of this organization");
            }
        }

        users[userAddr].isAlreadyInAnyOrganization = true;
        org.organizationMembers.push(users[userAddr]);

        memberToOrganizationOwner[userAddr] = orgAddr;

        emit AssociateAdded(orgAddr, userAddr, users[userAddr].userName);
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

    // ✅ New helper
    function isOrganizationExists(string memory name_) public view returns (bool) {
        return organizationNameToOwner[name_] != address(0);
    }

    function getOrganizationAddresses() public view returns (address[] memory) {
        return organizationAddresses;
    }
}

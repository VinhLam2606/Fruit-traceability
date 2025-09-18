// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Types.sol";

contract Users {
    mapping(address => Types.UserDetails) internal users;
    mapping(address => Types.Organization) internal organizations;
    mapping(string => address) internal organizationNameToOwner;
    address[] internal organizationAddresses;

    // Link a member's address to their organization's owner address for easy lookup
    mapping(address => address) internal memberToOrganizationOwner;

    event UserAdded(address indexed userAddr, string name, Types.UserRole role, uint256 date);
    event OrganizationAdded(address indexed orgAddr, string orgName, address owner, uint256 date);
    event AssociateAdded(address indexed orgAddr, address indexed userAddr, string userName);

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
            isAlreadyInAnyOrganization: user.isAlreadyInAnyOrganization
        });
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
        emit UserAdded(account, name, role, block.timestamp);
    }

    function getUser(address account) public view returns (Types.UserDetails memory) {
        return users[account];
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

    // --- FUNCTION HAS BEEN REPLACED FOR BETTER SECURITY ---
    /**
     * @notice Allows an organization owner to add a new associate to THEIR OWN organization.
     * @dev The organization is implicitly identified by msg.sender. The orgAddr parameter is removed.
     * @param userAddr The address of the new user to be added.
     */
    function addAssociateToOrganization(address userAddr) public onlyRegisteredUser {
        // The organization's address is determined by the caller's address (the owner)
        address orgAddr = msg.sender;

        // 1. Check if the caller actually owns an organization.
        require(organizations[orgAddr].ownerAddress == msg.sender, "Caller does not own an organization");

        // 2. Validate the user being added.
        require(userAddr != address(0), "Invalid user address");
        require(users[userAddr].userID != address(0), "User must be registered before adding to organization");
        require(!users[userAddr].isAlreadyInAnyOrganization, "User is already in another organization");

        Types.Organization storage org = organizations[orgAddr];

        // 3. Check for duplicate members.
        for (uint i = 0; i < org.organizationMembers.length; i++) {
            if (org.organizationMembers[i].userID == userAddr) {
                revert("User is already a member of this organization");
            }
        }

        // 4. Add the new member.
        users[userAddr].isAlreadyInAnyOrganization = true;
        org.organizationMembers.push(users[userAddr]);

        // Map the new member's address to the organization's owner address
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

    function getOrganizationAddresses() public view returns (address[] memory) {
        return organizationAddresses;
    }
}
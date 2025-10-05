// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Types.sol";

contract Users {
    struct UserAuth {
        string username;
        string email;
        bool isRegistered;
    }

    mapping(address => UserAuth) internal userAuths;

    modifier onlyRegisteredUser() {
        require(userAuths[msg.sender].isRegistered, "Caller is not a registered user");
        _;
    }

    mapping(address => Types.UserDetails) internal users;
    mapping(address => Types.Organization) internal organizations;
    mapping(string => address) internal organizationNameToOwner;
    address[] internal organizationAddresses;
    address[] internal userAddresses;
    mapping(address => address) internal memberToOrganizationOwner;

    event UserRegistered(address indexed userAddr, string username, string email, Types.UserRole role);
    event UserAdded(address indexed userAddr, string name, Types.UserRole role, uint256 date);
    event OrganizationAdded(address indexed orgAddr, string orgName, address owner, uint256 date);
    event AssociateAdded(address indexed orgAddr, address indexed userAddr, string userName);

    function registerUser(
        string memory _username,
        string memory _email
    ) public {
        address _userAddress = msg.sender;
        require(!userAuths[_userAddress].isRegistered, "User already registered");

        userAuths[_userAddress] = UserAuth({
            username: _username,
            email: _email,
            isRegistered: true
        });

        // 👉 Mặc định luôn là Customer
        users[_userAddress] = Types.UserDetails({
            userID: _userAddress,
            userName: _username,
            role: Types.UserRole.Customer,
            isAlreadyInAnyOrganization: false
        });
        userAddresses.push(_userAddress);

        emit UserRegistered(_userAddress, _username, _email, Types.UserRole.Customer);
        emit UserAdded(_userAddress, _username, Types.UserRole.Customer, block.timestamp);
    }

    function addOrganization(string memory name_, uint256 establishedDate_) public onlyRegisteredUser {
        require(!users[msg.sender].isAlreadyInAnyOrganization, "User already in an organization");

        Types.Organization storage org = organizations[msg.sender];
        org.organizationName = name_;
        org.ownerName = users[msg.sender].userName;
        org.ownerAddress = msg.sender;
        org.establishedDate = establishedDate_;
        org.organizationStatus = Types.AuthorizationStatus.Pending;

        // 👉 Upgrade role từ Customer -> Manufacturer
        users[msg.sender].role = Types.UserRole.Manufacturer;
        users[msg.sender].isAlreadyInAnyOrganization = true;

        org.organizationMembers.push(users[msg.sender]);
        organizationAddresses.push(msg.sender);
        memberToOrganizationOwner[msg.sender] = msg.sender;
        organizationNameToOwner[name_] = msg.sender;

        emit OrganizationAdded(msg.sender, name_, msg.sender, block.timestamp);
        emit AssociateAdded(msg.sender, msg.sender, users[msg.sender].userName);
    }
    function getOrganization(address _ownerAddress) public view returns (Types.Organization memory) {
        // Trả về dữ liệu của tổ chức dựa trên địa chỉ của chủ sở hữu
        // Nếu không tìm thấy, Solidity sẽ trả về một struct rỗng (các giá trị bằng 0 hoặc false)
        return organizations[_ownerAddress];
    }

    function getUser(address account) public view returns (Types.UserDetails memory) {
        return users[account];
    }

    /// 👉 FIX: thêm hàm helper để Products.sol gọi
    function isRegisteredAuth(address account) public view returns (bool) {
        return userAuths[account].isRegistered;
    }
}

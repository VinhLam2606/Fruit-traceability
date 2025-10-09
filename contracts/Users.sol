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
        address _userAddress, 
        string memory _email
    ) 
    public {
        require(!userAuths[_userAddress].isRegistered, "User already registered");

        userAuths[_userAddress] = UserAuth({
            username: "",
            email: _email,
            isRegistered: true
        });

        users[_userAddress] = Types.UserDetails({
            userID: _userAddress,
            userName: "",
            role: Types.UserRole.Customer,
            isAlreadyInAnyOrganization: false
        });
        userAddresses.push(_userAddress);

        emit UserRegistered(_userAddress, "", _email, Types.UserRole.Customer);
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
    function addAssociateToOrganization(address associate) public onlyRegisteredUser {
        // Đảm bảo caller là chủ tổ chức
        require(users[msg.sender].role == Types.UserRole.Manufacturer, "Caller is not an organization owner");
        require(users[associate].isAlreadyInAnyOrganization == false, "User already in an organization");
        require(userAuths[associate].isRegistered, "User not registered");

        // Lấy tổ chức của chủ sở hữu
        Types.Organization storage org = organizations[msg.sender];

        // Cập nhật trạng thái user
        users[associate].isAlreadyInAnyOrganization = true;

        // Thêm vào danh sách thành viên tổ chức
        org.organizationMembers.push(users[associate]);
        memberToOrganizationOwner[associate] = msg.sender;

        emit AssociateAdded(msg.sender, associate, users[associate].userName);
    }
    function getOrganizationByMember(address _member) public view returns (Types.Organization memory) {
        address owner = memberToOrganizationOwner[_member];
        return organizations[owner];
    }
    function leaveOrganization() public onlyRegisteredUser {
        // Lấy chủ sở hữu của tổ chức mà user đang ở
        address owner = memberToOrganizationOwner[msg.sender];
        require(owner != address(0), "You are not in any organization");

        // Không cho phép owner rời tổ chức của chính họ
        require(owner != msg.sender, "Owner cannot leave their own organization");

        Types.Organization storage org = organizations[owner];
        uint256 memberCount = org.organizationMembers.length;
        bool removed = false;

        // Xóa member khỏi danh sách organizationMembers
        for (uint256 i = 0; i < memberCount; i++) {
            if (org.organizationMembers[i].userID == msg.sender) {
                // Gán phần tử cuối cùng vào vị trí bị xoá (swap & pop)
                org.organizationMembers[i] = org.organizationMembers[memberCount - 1];
                org.organizationMembers.pop();
                removed = true;
                break;
            }
        }

        require(removed, "Member not found in organization");

        // Cập nhật trạng thái user
        users[msg.sender].isAlreadyInAnyOrganization = false;
        memberToOrganizationOwner[msg.sender] = address(0);

        emit AssociateRemoved(owner, msg.sender, users[msg.sender].userName);
    }

    event AssociateRemoved(address indexed orgAddr, address indexed userAddr, string userName);

    function getOrganizationOwner(string memory orgName) public view returns (address) {
        return organizationNameToOwner[orgName];
    }
    function removeAssociateFromOrganization(address associateToRemove) public onlyRegisteredUser {
        address owner = msg.sender;
        require(users[owner].role == Types.UserRole.Manufacturer, "Caller is not an organization owner");

        address associateOwner = memberToOrganizationOwner[associateToRemove];
        require(associateOwner == owner, "Associate not found or does not belong to your organization");

        require(owner != associateToRemove, "Owner cannot remove themselves using this function");

        Types.Organization storage org = organizations[owner];
        uint256 memberCount = org.organizationMembers.length;
        bool removed = false;

        for (uint256 i = 0; i < memberCount; i++) {
            if (org.organizationMembers[i].userID == associateToRemove) {
                // Gán phần tử cuối cùng vào vị trí bị xoá (swap & pop)
                org.organizationMembers[i] = org.organizationMembers[memberCount - 1];
                org.organizationMembers.pop();
                removed = true;
                break;
            }
        }

        require(removed, "Associate structure mismatch or not found");

        users[associateToRemove].isAlreadyInAnyOrganization = false;
        memberToOrganizationOwner[associateToRemove] = address(0);

        emit AssociateRemoved(owner, associateToRemove, users[associateToRemove].userName);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library Types {

    // Declare all roles for user to authorize permissions
    enum UserRole {
        Admin, // 0
        Manufacturer, // 1
        Customer // 2
    }

    enum AuthorizationStatus {
        Pending, // 0
        Approved, // 1
        Rejected // 2
    }

    struct UserHistory {
        address _userID;
        uint256 _timestamp;
    }

    struct UserDetails {
        address userID;
        string userName;
        UserRole role;
        bool isAlreadyInAnyOrganization;
    }

    struct Organization {
        string organizationName;
        string ownerName;
        address ownerAddress;
        UserDetails[] organizationMembers;
        uint256 establishedDate;
        AuthorizationStatus organizationStatus;
    }

    struct Product {
        string batchId;
        string name;
        string organizationName;
        address creator;
        uint256 harvestDate;
        uint256 expiryDate;
        address currentOwner;
    }

    struct ProductHistory {
        string batchId;
        address from;
        address to;
        uint256 timestamp;
        string note;
    }
}

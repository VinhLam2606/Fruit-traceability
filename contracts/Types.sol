// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

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

    enum ProcessType {
        Cultivation,   // Trồng trọt
        Processing,    // Sơ chế
        Packaging,     // Đóng gói
        Transport,     // Vận chuyển
        Distribution   // Phân phối
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

    struct ProcessStep {
        string processName;
        ProcessType processType;
        string description;
        uint256 date;
        string organizationName;
    }

    struct Product {
        string batchId;
        string name;
        string organizationName;
        address creator;
        uint256 date;
        address currentOwner;
        string status;
        Types.ProcessStep[] processSteps;
    }

    struct ProductHistory {
        string batchId;
        address from;
        address to;
        uint256 timestamp;
        string note;
    }
}
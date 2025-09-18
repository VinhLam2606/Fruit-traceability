// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Types.sol";
import "./Products.sol";
import "./Users.sol";

contract Chain is Products {
    constructor() {
        // create admin user as contract deployer
        Types.UserDetails memory admin_ = Types.UserDetails({
            userID: msg.sender,
            userName: "admin",
            role: Types.UserRole.Admin,
            isAlreadyInAnyOrganization: false
        });
        addUser(admin_);
    }
}

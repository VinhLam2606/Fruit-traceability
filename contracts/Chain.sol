// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Types.sol";
import "./Users.sol";
import "./Products.sol";

contract Chain is Products {
    constructor() {
        // Tạo admin user mặc định (deployer)
        users[msg.sender] = Types.UserDetails({
            userID: msg.sender,
            userName: "admin",
            role: Types.UserRole.Admin,
            isAlreadyInAnyOrganization: false
        });

        userAuths[msg.sender] = UserAuth({
            username: "admin",
            email: "admin@system",
            isRegistered: true
        });

        userAddresses.push(msg.sender);

        emit UserRegistered(msg.sender, "admin", "admin@system", Types.UserRole.Admin);
        emit UserAdded(msg.sender, "admin", Types.UserRole.Admin, block.timestamp);
    }
}

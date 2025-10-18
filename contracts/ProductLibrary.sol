// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "./Types.sol";

/**
 * @title ProductLibrary
 * @author Gemini
 * @notice This library contains helper functions for the Products contract
 * to reduce its bytecode size and improve modularity.
 */
library ProductLibrary {
    /**
     * @notice Adds a new entry to a product's history.
     * @param productHistories The storage mapping of product histories from the calling contract.
     * @param batchId The batch ID of the product.
     * @param from The sender of the action.
     * @param to The receiver of the action.
     * @param note A description of the history event.
     */
    function addProductHistory(
        mapping(string => Types.ProductHistory[]) storage productHistories,
        string memory batchId,
        address from,
        address to,
        string memory note,
        Types.HistoryType historyType
    ) internal {
        productHistories[batchId].push(Types.ProductHistory({
            batchId: batchId,
            from: from,
            to: to,
            timestamp: block.timestamp,
            note: note,
            historyType: historyType
        }));
    }

    /**
     * @notice Efficiently removes a product index from a user's ownership array.
     * @dev Uses the "swap and pop" method to avoid costly array shifting.
     * @param userOwnedProductIndices The storage mapping of user-owned indices from the calling contract.
     * @param user The address of the user from whom to remove the product index.
     * @param productIndexToRemove The index of the product to remove.
     */
    function removeProductIndexFromUser(
        mapping(address => uint256[]) storage userOwnedProductIndices,
        address user,
        uint256 productIndexToRemove
    ) internal {
        uint256[] storage indices = userOwnedProductIndices[user];
        if (indices.length == 0) return;

        uint256 lastIndex = indices.length - 1;

        for (uint i = 0; i < indices.length; i++) {
            if (indices[i] == productIndexToRemove) {
                // Swap the element to remove with the last element
                indices[i] = indices[lastIndex];
                // Remove the last element
                indices.pop();
                return;
            }
        }
    }
}
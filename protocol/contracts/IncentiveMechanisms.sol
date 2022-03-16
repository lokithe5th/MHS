// SPDX-License-Identifier: MIT
// Metaverse Health Systems
pragma solidity ^0.8.4;

/// @title Metaverse Health Systems: Health Constants
/// @author @LourensLinde || lourens.eth || LokiThe5th
/// @notice The contract extends HealthEntity to allow for setting of constants needed for ERC20 incentive mechanism.
/// @dev Incentive mechanisms governing the MHS protocol can be added and stored here.
/// @custom:security-contact lourens@dao.health

import "@openzeppelin/contracts@4.5.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@4.5.0/security/Pausable.sol";
import "@openzeppelin/contracts@4.5.0/access/AccessControl.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@4.5.0/utils/Counters.sol";

contract IncentiveMechanisms is HealthEntity {

    ///  Events
    //  Emit event for new health entity registration
    event newHealthTransaction(string transactionType, uint32 baseReward, uint32 rewardModifier, address sponsor);

    //  Struct containing Health Transactions
    struct healthTransaction {
        string transactionType;
        uint32 baseReward;
        uint32 rewardModifier;
        address sponsor;
    }

    //  Array of different health transactions 
    healthTransaction[] public healthTransactions;

    /// @notice Treasury role is given to a multisig wallet which is governed by the appropriate DAO structure
    /// @custom:treasury This role is subject to transparent decision making and community oversight.
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");


    constructor() ERC721("MHS: HealthEntity", "HEALER") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(AUDITOR_ROLE, msg.sender);
        _grantRole(TREASURY_ROLE, msg.sender);

        /// Set first transactionType as "VERIFY"
        healthTransactions.push(healthTransaction({
            transactionType: "VERIFY",
            baseReward: 10,
            rewardModifier: 2,
            sponsor: msg.sender
        }));
    }

    
    //  The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}

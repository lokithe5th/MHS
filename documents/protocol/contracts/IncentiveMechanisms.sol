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
import "./HealthEntity.sol";

contract IncentiveMechanisms is HealthEntity {

    ///  Events
    //  Emit event for new health entity registration
    event newHealthTransaction(string transactionType, uint32 baseReward, uint32 rewardModifier, address sponsor);

    //  Struct containing Health Transactions
    struct healthTransaction {
        string transactionType;
        uint8 repModifier;
        uint32 baseReward;
        uint32 rewardModifier;
        address sponsor;
    }

    //  Mapping of allocated token amounts to tokenId
    mapping(uint32 => uint256) private tokenBalances;

    //  Array of different health transactions 
    healthTransaction[] public transactionTypes;

    /// @notice Treasury role is given to a multisig wallet which is governed by the appropriate DAO structure
    /// @custom:treasury This role is subject to transparent decision making and community oversight.
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");


    constructor() {
        _grantRole(TREASURY_ROLE, msg.sender);

        /// Set first transactionType as "VERIFY"
        transactionTypes.push(healthTransaction({
            transactionType: "VERIFY",
            repModifier: 1,
            baseReward: 10,
            rewardModifier: 2,
            sponsor: msg.sender
        }));
    }

    /// @notice Function to allocate tokens for health interactions or transactions
    /// @dev Adds the appropriate amount to the tokens mapping
    /// @param _tokenId TokenId which receives a token allocation
    /// @param _transactionType Type of transaction that is earning tokens
    function allocateTokens(
        uint32 _tokenId, 
        string memory _transactionType
        ) public onlyRole(MINTER_ROLE) {
            tokenBalances[_tokenId] = _tokensAllocated(_transactionType) + tokenBalances[_tokenId];
        }   

    /// Internal Functions
    
    /// @notice
    /// @dev
    /// @param _transactionType The string representing the transaction type
    function _tokensAllocated(
        string memory _transactionType
        ) internal view returns (uint32) {
            bool _transactionTypeFound = false;
            for (uint i; i < transactionTypes.length; i++) {
                if (keccak256(bytes(_transactionType)) == keccak256(bytes(transactionTypes[i].transactionType))) {
                    _transactionTypeFound = true;
                    return (transactionTypes[i].baseReward + transactionTypes[i].rewardModifier);
                }
            }
            require(_transactionTypeFound, "Transaction type not found!");
            return 0;
        }

    /// @notice View function for token balance mapped to tokenId
    /// @dev Returns the number of HEALZ held by the given tokenId
    /// @param _tokenId Uint representing the target token
    function tokenBalance(
        uint32 _tokenId
        ) external view returns (uint256) {
            require(_tokenId > healthEntities.length, "Token holder doesn't exist!");
            return tokenBalances[_tokenId];
    }
    
    //  The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(HealthEntity)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

}

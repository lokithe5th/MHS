// SPDX-License-Identifier: MIT
// Metaverse Health Systems
pragma solidity ^0.8.4;

/// @title  Metaverse Health Systems: Actions
/// @author @LourensLinde || lourens.eth || LokiThe5th
/// @notice The contract allows for the creation of an ERC721 which can represent a health system entity on chain.
/// @dev    Actions that can be completed by participants
/// @custom:security-contact lourens@dao.health

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./Transactions.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Actions is Transactions {

    IERC20 private _healToken;

    constructor(address _initialOwner, IERC20 _token) {
        _grantRole(TREASURY_ROLE, _initialOwner);
        _grantRole(MINTER_ROLE, _initialOwner);
        _grantRole(DEFAULT_ADMIN_ROLE, _initialOwner);
        _grantRole(PAUSER_ROLE, _initialOwner);
        _grantRole(MINTER_ROLE, _initialOwner);
        _grantRole(AUDITOR_ROLE, _initialOwner);
        _grantRole(MHS_DEPLOYMENT, address(this));

        _healToken = _token;
    }

    /// @notice Verify a health entity
    /// @dev    _verifyingEntity is required to make sure the sponsor address owns a valid health entity token
    /// @param  _targetEntity The uint representing the target entity
    /// @param  _verifyingEntity The uint representing the entity sponsoring the target entity
    /// @dev    Also calls _incrementReputation for sponsor
    function verify(uint32 _targetEntity, uint32 _verifyingEntity) public {
        require(msg.sender != ownerOf(_targetEntity), "Cannot self-verify");
        require(healthEntities[_targetEntity].verified == false, "Target already verified");
        require(ownerOf(_verifyingEntity) == msg.sender, "Caller must own Verifying Token");
        require(healthEntities[_verifyingEntity].verified, "Verifying token is not yet verified");

        healthEntities[_targetEntity].verified = true;
        healthEntities[_targetEntity].sponsor = msg.sender;

        emit healthEntityVerified(_targetEntity, msg.sender);
        _incrementReputation(_verifyingEntity, 1);
        allocateTokens(_verifyingEntity, "VERIFY");
    }

    /// @notice MHS Auditor actions only by DAO authority. 
    /// @dev    Emits auditorAction event.
    /// @dev    Only to be used by MHS Auditor multisig. The multisig becomes the sponsor.
    /// @param  _targetEntity Entity to be modified
    /// @param  _healthEntityType Set the target entity's type from the open-source document available in project repo.
    /// @param  _healthId Set the target token's healthId. Takes a Keccak256 hash, format is "0x[64 character hash]". 
    /// @param  _verified Set the target token's verification status.
    /// @param  _active Set the target token's "active" status. Only to be used with decommisioned or disqualified tokens.
    /// @param  _reputation Set the target token's reputation. Should only be set to current value or 0 if modified.
    /// @dev    Be aware that actions must be authorised by DAO and signed by multisig. Scope is needed to account for edge cases (verifiably stolen tokens, catastrophic loss of private keys, etc).  
    function modifyTargetHealthEntity(
        uint32 _targetEntity,
        uint32 _healthEntityType,
        bytes32 _healthId,
        bool _verified,
        bool _active,
        uint32 _reputation
         ) public onlyRole(AUDITOR_ROLE) {
            require(msg.sender != ownerOf(uint32(_targetEntity)), "Cannot self-modify");

            healthEntities[_targetEntity].healthEntityType = _healthEntityType;
            healthEntities[_targetEntity].healthId = _healthId;
            healthEntities[_targetEntity].verified = _verified;
            healthEntities[_targetEntity].sponsor = msg.sender;
            healthEntities[_targetEntity].active = _active;
            healthEntities[_targetEntity].reputation = _reputation;

            emit auditorAction(_targetEntity, msg.sender);
         }

    /// Internal Functions
    /// @notice Function to increase reputation
    /// @dev Increments the reputation by the given amount
    /// @custom:design Incentive Mechanism Design
    function _incrementReputation(
        uint256 _targetId, 
        uint32 _incrementBy
        ) internal {
            require(_incrementBy > 0);
            uint32 _reputation =  healthEntities[_targetId].reputation;
            healthEntities[_targetId].reputation = _reputation + _incrementBy;

            emit reputationEvent(uint32(_targetId), _incrementBy); 
    }

    function claimTokens(uint32 _targetId) public returns (uint256) {
        require(msg.sender == ownerOf(_targetId), "Must own token you are claiming from!");
        require(tokenBalances[_targetId] > 0, "No tokens to claim!");
        require(_healToken.transfer(ownerOf(_targetId), tokenBalances[_targetId]), "Unable to transfer");
        uint256 tokensClaimed = tokenBalances[_targetId];
        tokenBalances[_targetId] = 0;
        return (tokensClaimed);
    }

}

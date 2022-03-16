// SPDX-License-Identifier: MIT
// Metaverse Health Systems
pragma solidity ^0.8.4;

/// @title Metaverse Health Systems: Health Entity
/// @author @LourensLinde || lourens.eth || LokiThe5th
/// @notice The contract allows for the creation of an ERC721 which can represent a health system entity on chain.
/// @dev ERC721 implementation for MHS: HealthEntity
/// @custom:security-contact lourens@dao.health

import "@openzeppelin/contracts@4.5.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@4.5.0/security/Pausable.sol";
import "@openzeppelin/contracts@4.5.0/access/AccessControl.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@4.5.0/utils/Counters.sol";

contract HealthEntity is ERC721, ERC721Enumerable, Pausable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    ///  Events
    //  Emit event for new health entity registration
    event newHealthEntity(uint32 tokenId, address tokenHolder, uint32 healthEntityType);

    //  Emit event for health entity being verified
    event healthEntityVerified(uint32 tokenId, uint32 sponsor);

    //  Emit event when a MHS Auditor revokes a health entity's verification
    event revokeVerification(uint32 tokenId, address auditor);

    // Emit event when set to inactive
    event setInactive(uint32 tokenId, address auditor);

    //  Emit an event when a MHS Auditor modifies a health entity
    event auditorAction(uint32 tokenId, address auditor);

    //  Emit an event when reputation is added to a health entity
    event reputationEvent(uint32 tokenId, uint32 reputationChange);
    
    //  Emit a request when a health entity requests verification after minting or transfer
    event verificationRequest(uint32 tokenId);

    //  Struct containing Health Entities
    struct healthEntity {
        uint32 healthEntityType;        //  From list of Entity types: MD, Physio, Occ Ther, Nursing etc
        uint32 reputation;              //  Reputation accrued by Health Entity
        bytes32 healthId;               //  Keccak256 hash of ID provided by health professional's statutory body
        bool verified;                  //  Has this Health Entity been verified by another Health Entity?
        bool active;                    //  Is Health Entity active in health system at the moment?
        address sponsor;                //  Who has verified this Health Entity
    }

    //  Array of health entities 
    healthEntity[] public healthEntities;

    //  Roles for testing. Later deployments may change these roles.
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    address public constant ZERO_ADDRESS = address(0x0000000000000000000000000000000000000000);
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("MHS: HealthEntity", "HEALTH") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(AUDITOR_ROLE, msg.sender);
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }


    function safeMint(address to, uint32 _type, bytes32 _healthId) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        //Create the new healthEntity. 
        healthEntities.push(healthEntity({
            healthEntityType: _type,
            reputation: 0,
            healthId: _healthId,
            verified: false,
            active: true,
            sponsor: ZERO_ADDRESS
        }));

        emit newHealthEntity(tokenId, to, _type);
    }

    //  Create the first healthEntity. Must be a doxxed entity in order to be held accountable.
    //  Note that the bytes32 _healthId will require the keccak256 hash to be determined prior to input into contract. 
    //  This means the 64 character hash must be appended to "0x"
    function initializeFirstEntity(
        address to, 
        uint32 _type, 
        bytes32 _healthId
        ) public onlyRole(MINTER_ROLE) {
            require(healthEntities.length == 0, "Already initialized");

            uint256 tokenId = _tokenIdCounter.current();
            _tokenIdCounter.increment();
            _safeMint(to, tokenId);
 
            healthEntities.push(healthEntity({
            healthEntityType: _type,
            healthId: _healthId,
            verified: true,
            sponsor: 0x0000000000000000000000000000000000000000,
            active: true,
            reputation: 0
        }));
    }

    /// @notice Verify a health entity
    /// @dev _verifyingEntity is required to make sure the sponsor address owns a valid health entity token
    /// @param _targetEntity The uint representing the target entity
    /// @param _verifyingEntity The uint representing the entity sponsoring the target entity
    /// @custom Also calls _incrementReputation for sponsor
    function setVerification(uint32 _targetEntity, uint32 _verifyingEntity) public {
        require(msg.sender != ownerOf(_targetEntity), "Cannot self-verify");
        require(healthEntities[_targetEntity].verified == false, "Target already verified");
        require(ownerOf(_verifyingEntity) == msg.sender, "Caller must own Verifying Token");
        require(healthEntities[_verifyingEntity].verified, "Verifying token is not yet verified");

        healthEntities[_targetEntity].verified = true;
        healthEntities[_targetEntity].sponsor = msg.sender;

        emit healthEntityVerified(_targetEntity, msg.sender);
        _incrementReputation(_verifyingEntity, 1);
    }

    /// @notice MHS Auditor actions only by DAO authority. 
    /// @dev Only to be used by MHS Auditor multisig. The multisig becomes the sponsor.
    /// @param _targetEntity Entity to be modified
    /// @param _healthEntityType Set the target entity's type from the open-source document available in project repo.
    /// @param _healthId Set the target token's healthId. Takes a Keccak256 hash, format is "0x[64 character hash]". 
    /// @param _verified Set the target token's verification status.
    /// @param _active Set the target token's "active" status. Only to be used with decommisioned or disqualified tokens.
    /// @param _reputation Set the target token's reputation. Should only be set to current value or 0 if modified.
    /// @custom Be aware that actions must be authorised by DAO and signed by multisig. Scope is needed to account for edge cases (verifiably stolen tokens, catastrophic loss of private keys, etc).  
    /// @custom Emits auditorAction event.
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

            emit auditorAction(_targetId, msg.sender);
         }

    function _beforeTokenTransfer(
        address from, 
        address to, 
        uint256 tokenId
        ) internal whenNotPaused override(ERC721, ERC721Enumerable) {
            super._beforeTokenTransfer(from, to, tokenId);
        }

    ///  @notice Internal functions that should be called on transfer
    ///  @dev Verification must be reset
    ///  @custom is always followed by a reverification process to ensure health entity integrity.
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
        ) public virtual override {
            safeTransferFrom(from, to, tokenId, "");
            _revokeVerification(tokenId);
    }

    /// Internal Functions
    /// @notice Function to increase reputation
    /// @dev Increments the reputation by the given amount
    /// @custom Incentive Mechanism Design
    function _incrementReputation(
        uint256 _targetId, 
        uint32 _incrementBy
        ) internal {
            require(_incrementBy > 0);
            uint32 _reputation =  healthEntities[_targetId].reputation;
            healthEntities[_targetId].reputation = _reputation + _incrementBy;

            emit reputationEvent(_targetId, _incrementBy); 
    }

    /// @notice Sets target NFT to not verified
    /// @dev An internal function to revoke verification upon token transfer.
    /// @param _tokenId Uint256 representing tokenId that must have verification revoked
    /// @custom Incentive Mechanism Design 
    function _revokeVerification(uint32 _tokenId) internal {
        healthEntities[_tokenId].verified = false;
        emit revokeVerification(_tokenId, msg.sender);
    }
    
    /// @notice Sets target NFT to inactive
    /// @param _tokenId Uint32 representing tokenId which must be set to inactive
    /// @custom Only callable by MHS Auditor multisig
    function _setNotActive(uint32 _tokenId) internal {
        healthEntities[_tokenId].active = false;
        emit setInactive(_tokenId, msg.sender);
    }

    /// @notice Method to allow someone to verify a health entity without storing direct info on chain. 
    /// @dev Contains a keccak256 hash of compact JSON format with governing body details and unique identifier
    /// @dev Format for front-end: {"governingBody":"[governing body]","healthId":"[official health ID]"}
    /// @param _targetId Target token
    /// @param _verificationString "0x" with Keccak256 hash appended
    /// @custom The hash is used to prevent unnecessary exposure of health entity information
    /// @return bool Does health entity credentials hash provide stored hash
    function verifyHealthEntity(
        uint32 _targetId, 
        bytes memory _verificationString
        ) public view returns (bool) {
            require(_targetId > 0, "tokenId must be higher than 0");
            require(healthEntities[_targetId].healthId == keccak256(_verificationString), "Supplied information does not match records");
            return true;
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

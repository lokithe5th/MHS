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

    //  Events
    event newHealthEntity(uint32 tokenId, address tokenHolder, uint32 healthEntityType);
    event healthEntityVerified(uint32 tokenId, uint32 sponsor);
    event revokeVerification(uint32 tokenId, uint32 auditor);
    event healthEntityModified(uint32 tokenId, uint32 auditor);
    event reputationEvent(uint32 tokenId, uint32 reputationChange);
    event verificationRequest(uint32 tokenId);

    //  Struct containing Health Entities
    struct healthEntity {
        uint32 healthEntityType;        //  From list of Entity types: MD, Physio, Occ Ther, Nursing etc
        bytes32 healthId;               //  Keccak256 hash of ID provided by health professional's statutory body
        bool verified;                  //  Has this Health Entity been verified by another Health Entity?
        address sponsor;                //  Who has verified this Health Entity
        bool active;                    //  Is Health Entity active in health system at the moment?
        uint32 reputation;              //  Reputation accrued by Health Entity
    }

    healthEntity[] public healthEntities;

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
            healthId: _healthId,
            verified: false,
            sponsor: ZERO_ADDRESS,
            active: true,
            reputation: 0
        }));

        emit newHealthEntity(tokenId, to, _type);
    }

    //Create the first healthEntity. Must be a doxxed entity in order to be held accountable.
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

    //Verify a health entity
    function setVerification(uint256 _targetEntity, uint256 _verifyingEntity) public {
        require(msg.sender != ownerOf(_targetEntity), "Cannot self-verify");
        require(healthEntities[_targetEntity].verified == false, "Target already verified");
        require(ownerOf(_verifyingEntity) == msg.sender, "Caller must own Verifying Token");
        require(healthEntities[_verifyingEntity].verified, "Verifying token is not yet verified");

        healthEntities[_targetEntity].verified = true;
        healthEntities[_targetEntity].sponsor = msg.sender;

        //Reputation is gained for verifying other healthEntities
        _incrementReputation(_verifyingEntity, 1);
    }

    //Auditor actions. Only to be used by Auditor multisig. The multisig become the sponsor.
    function modifyTargetHealthEntity(
        uint256 _targetEntity,
        uint32 _healthEntityType,
        bytes32 _healthId,
        bool _verified,
        bool _active,
        uint32 _reputation
         ) public onlyRole(AUDITOR_ROLE) {
            require(msg.sender != ownerOf(uint256(_targetEntity)), "Cannot self-modify");

            healthEntities[_targetEntity].healthEntityType = _healthEntityType;
            healthEntities[_targetEntity].healthId = _healthId;
            healthEntities[_targetEntity].verified = _verified;
            healthEntities[_targetEntity].sponsor = msg.sender;
            healthEntities[_targetEntity].active = _active;
            healthEntities[_targetEntity].reputation = _reputation;
         }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId)
        internal
        whenNotPaused
        override(ERC721, ERC721Enumerable)
    {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    // Internal functions that should be called on transfer
    // On transfer the following two actions must be taken: 1) Verification must be reset, 2) Health Entity must be marked as not active
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override {
        safeTransferFrom(from, to, tokenId, "");
        _revokeVerification(tokenId);
        _setNotActive(tokenId);
    }

    //  Internal Functions
    //  Function to increase reputation
    function _incrementReputation(uint32 _targetId, uint32 _incrementBy) internal {
        require(_incrementBy > 0);
        uint32 _reputation =  healthEntities[_targetId].reputation;
        healthEntities[_targetId].reputation = _reputation + _incrementBy;

        emit reputationEvent(_targetId, _incrementBy);
    }

    //  Sets target NFT to not verified
    function _revokeVerification(uint256 _tokenId) internal {
        healthEntities[_tokenId].verified = false;

        emit revokeVerification(_tokenId, msg.sender);
    }
    
    //  Sets target NFT to not active
    function _setNotActive(uint256 _tokenId) internal {
        healthEntities[_tokenId].active = false;
    }

    //  Method to allow someone to verify a health entity without storing direct info on chain. Contains a keccak256 hash of JSON format with governing body details and unique identifier
    function verifyHealthEntity(uint32 _targetId, string memory _verificationString) public view returns (bool) {
        emit verificationRequest(_targetId);
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

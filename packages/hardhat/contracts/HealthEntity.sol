// SPDX-License-Identifier: MIT
// Metaverse Health Systems
pragma solidity ^0.8.4;

/// @title Metaverse Health Systems: Health Entity
/// @author @LourensLinde || lourens.eth || LokiThe5th
/// @notice The contract allows for the creation of an ERC721 which can represent a health system entity on chain.
/// @dev ERC721 implementation for MHS: HealthEntity
/// @custom:security-contact lourens@dao.health

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract HealthEntity is ERC721, ERC721Enumerable, Pausable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    ///  Events
    //  Emit event for new health entity registration
    event newHealthEntity(uint32 tokenId, address tokenHolder, uint32 healthEntityType);

    //  Emit event for health entity being verified
    event healthEntityVerified(uint32 tokenId, address sponsor);

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
        uint32 healthEntityType;        //  From list of Entity types: MD, Physio, Occ Ther, Nursing, Patient, Admin etc
        uint32 reputation;              //  Reputation accrued by Health Entity
        bytes32 healthId;               //  Keccak256 hash of ID provided by health professional's statutory body
        bool verified;                  //  Has this Health Entity been verified by another Health Entity?
        bool active;                    //  Is Health Entity active in health system at the moment?
        address sponsor;                //  Who has verified this Health Entity
    }

    //  Array of health entities 
    healthEntity[] public healthEntities;

    ///  Roles for testing. Later deployments may change these roles to allow for decentralizing of minting function.
    ///  @notice If minter role depracted a payable modifier must be implemented on the safeMint function to provide Sybil-resistance
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Auditor role is given to a multisig wallet which is governed by the appropriate DAO structure
    /// @custom:auditor Auditor role is subject to transparent decision making and community oversight.
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");
    bytes32 public constant MHS_DEPLOYMENT = keccak256("MHS_DEPLOYMENT");

    /// @notice Simple constant to allow the first health entity to be minted with the zero-address as sponsor
    address public constant ZERO_ADDRESS = address(0x0000000000000000000000000000000000000000);
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("MHS: HealthEntity", "HEALER") {
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

        emit newHealthEntity(uint32(tokenId), to, _type);
    }

    /// @notice Create the first healthEntity. Must be a doxxed entity in order to be held accountable.
    /// @dev Note that the bytes32 _healthId will require the keccak256 hash to be determined prior to input into contract. 
    /// @dev This means the 64 character hash must get the "0x" in front of it
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

    function _beforeTokenTransfer(
        address from, 
        address to, 
        uint256 tokenId
        ) internal whenNotPaused override(ERC721, ERC721Enumerable) {
            super._beforeTokenTransfer(from, to, tokenId);
        }

    ///  @notice Internal functions that should be called on transfer
    ///  @dev Verification must be reset
    ///  @dev is always followed by a reverification process to ensure health entity integrity.
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
        ) public virtual override(ERC721) {
            safeTransferFrom(from, to, tokenId, "");
            _revokeVerification(uint32(tokenId));
    }

    /// @notice Sets target NFT to not verified
    /// @dev An internal function to revoke verification upon token transfer.
    /// @param _tokenId Uint256 representing tokenId that must have verification revoked
    /// @custom:design Incentive Mechanism Design 
    function _revokeVerification(uint32 _tokenId) internal {
        healthEntities[_tokenId].verified = false;
        emit revokeVerification(_tokenId, msg.sender);
    }
    
    /// @notice Sets target NFT to inactive
    /// @param  _tokenId Uint32 representing tokenId which must be set to inactive
    /// @dev    Only callable by MHS Auditor multisig
    function _setNotActive(uint32 _tokenId) internal {
        healthEntities[_tokenId].active = false;
        emit setInactive(_tokenId, msg.sender);
    }

    /// @notice Method to allow someone to verify a health entity without storing direct info on chain. 
    /// @dev    Contains a keccak256 hash of compact JSON format with governing body details and unique identifier
    /// @dev    Format for front-end: {"governingBody":"[governing body]","healthId":"[official health ID]"}
    /// @param  _targetId Target token
    /// @param  _verificationString "0x" with Keccak256 hash appended
    /// @dev    The hash is used to prevent unnecessary exposure of health entity information
    /// @return bool Does health entity credentials hash provide stored hash
    function verifyCredentials(
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
        virtual
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    receive() external payable {}
    fallback() external payable {}

}

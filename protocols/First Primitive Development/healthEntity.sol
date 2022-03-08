// SPDX-License-Identifier: MIT
// Metaverse Health Systems
pragma solidity ^0.8.4;

/// @title Metaverse Health Systems: Health Entity
/// @author @LourensLinde || lourens.eth || LokiThe5th
/// @notice The contract allows for the creation of an ERC721 which can represent a health system entity on chain.
/// @dev Explain to a developer any extra details
/// @custom:security-contact lourens@dao.health

import "@openzeppelin/contracts@4.5.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@4.5.0/security/Pausable.sol";
import "@openzeppelin/contracts@4.5.0/access/AccessControl.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@4.5.0/utils/Counters.sol";

contract HealthEntity is ERC721, ERC721Enumerable, Pausable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    struct healthEntity {
        int32 healthEntityType;
        string healthId;
        string governingBody;
        bool verified;
        address sponsor;
        bool active;
        int32 reputation;
    }

    healthEntity[] public healthEntities;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant AUDITOR_ROLE = keccak256("AUDITOR_ROLE");

    address public constant ZERO_ADDRESS = address(0x0000000000000000000000000000000000000000);
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("healthEntity", "HEALTH") {
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

    function safeMint(address to, int32 _type, string memory _healthId, string memory _governingBody) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        //Create the new healthEntity. 
        healthEntities.push(healthEntity({
            healthEntityType: _type,
            healthId: _healthId,
            governingBody: _governingBody,
            verified: false,
            sponsor: ZERO_ADDRESS,
            active: true,
            reputation: 0
        }));
    }

    //Create the first healthEntity. Must be a doxxed entity in order to be held accountable.
    function initializeFirstEntity(
        address to, 
        int32 _type, 
        string memory _healthId, 
        string memory _governingBody
        ) public onlyRole(MINTER_ROLE) {
            require(healthEntities.length = 0, "Already initialized");
 
            healthEntities.push(healthEntity({
            healthEntityType: _type,
            healthId: _healthId,
            governingBody: _governingBody,
            verified: true,
            sponsor: 0x0000000000000000000000000000000000000000,
            active: true,
            reputation: 0
        }));
    }

    //Verify a health entity
    function verifyHealthEntity(int256 _targetEntity, uint256 _verifyingEntity) public {
        require(msg.sender != ownerOf(uint256(_targetEntity)), "Cannot self-verify");
        require(healthEntities[uint256(_targetEntity)].verified == false, "Target already verified");
        require(ownerOf(uint256(_verifyingEntity)) == msg.sender, "Caller must own Verifying Token");
        require(healthEntities[_verifyingEntity].verified, "Verifying token is not yet verified");

        healthEntities[uint256(_targetEntity)].verified = true;
        healthEntities[uint256(_targetEntity)].sponsor = msg.sender;

        //Reputation is gained for verifying other healthEntities
        healthEntities[uint256(_verifyingEntity)].reputation++;
    }

    //Auditor actions. Only to be used by Auditor multisig. The multisig become the sponsor.
    function modifyTargetHealthEntity(
        uint256 _targetEntity,
        uint32 _healthEntityType,
        string memory _healthId,
        string memory _governingBody,
        bool _verified,
        bool _active,
        int32 _reputation
         ) public onlyRole(AUDITOR_ROLE) {
            require(msg.sender != ownerOf(uint256(_targetEntity)), "Cannot self-modify");

            healthEntities[_targetEntity].healthEntityType = _healthEntityType;
            healthEntities[_targetEntity].healthId = _healthId;
            healthEntities[_targetEntity].governingBody = _governingBody;
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

    // The following functions are overrides required by Solidity.

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}

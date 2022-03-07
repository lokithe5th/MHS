// SPDX-License-Identifier: MIT
// Metaverse Health Systems
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.5.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts@4.5.0/security/Pausable.sol";
import "@openzeppelin/contracts@4.5.0/access/AccessControl.sol";
import "@openzeppelin/contracts@4.5.0/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts@4.5.0/utils/Counters.sol";

/// @custom:security-contact lourens@dao.health
contract HealthEntity is ERC721, ERC721Enumerable, Pausable, AccessControl, ERC721Burnable {
    using Counters for Counters.Counter;

    struct healthEntity {
        int32 healthEntityType;
        string healthId;
        string governingBody;
        bool verified;
        bool auditor;
        bool active;
        bool minter;
        int32 reputation;
    }

    healthEntity[] public healthEntities;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    Counters.Counter private _tokenIdCounter;

    constructor() ERC721("healthEntity", "HEALTH") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
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
        healthEntities.push(healthEntity({
            healthEntityType: _type,
            healthId: _healthId,
            governingBody: _governingBody,
            verified: false,
            auditor: false,
            active: true,
            minter: false,
            reputation: 0
        }));
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

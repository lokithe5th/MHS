// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/// @custom:security-contact lourens@dao.health
contract MHSHealToken is ERC20, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant DEPLOYER_ROLE = keccak256("DEPLOYER_ROLE");

    uint256 public maxSupply = 100000000;

    /// @notice Constructor function minting 1 000 000 tokens to the MHS contract.
    /// @dev    In addition, sets the admin and minter role to the MHS contract.
    /// @param  _controller: The address for the controlling MHS address.
    constructor(address _controller) ERC20("MHS HealToken", "HEALZ") {
        _mint(msg.sender, 10000000 * 10 ** decimals());
        _grantRole(DEFAULT_ADMIN_ROLE, _controller);
        _grantRole(MINTER_ROLE, _controller);
        _grantRole(DEPLOYER_ROLE, msg.sender);
    }

    function mint(address to, uint256 amount) public onlyRole(MINTER_ROLE) {
        uint256 _currentSupply = totalSupply();
        require(_currentSupply < maxSupply, "Token has reached maximum supply.");
        _mint(to, amount);

    }

    function init(address _to) public onlyRole(DEPLOYER_ROLE) returns (uint256) {
        require(transfer(_to, 10000000), "Init transfer unsuccessful");
        return (10000000);
    }

}
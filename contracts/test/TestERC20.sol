// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract TestERC20 is ERC20Upgradeable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name, string memory symbol) initializer public {
        __ERC20_init(name, symbol);
    }

    function mint(address to, uint256 value) public returns (bool) {
        _mint(to, value);
        return true;
    }
}
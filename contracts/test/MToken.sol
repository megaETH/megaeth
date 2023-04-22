// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract AToken is ERC20Upgradeable {
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

  function burn(address account, uint256 amount) public {
    _burn(account, amount);
  }

}

contract Pool {

  mapping(address => address) public assetToAToken;

  constructor() {

  }

  function addAToken(address asset, address atoken) public {
    assetToAToken[asset] = atoken;
  }

  function supply(
    address asset,
    uint256 amount,
    address onBehalfOf,
    uint16
  ) public virtual {
    IERC20(asset).transferFrom(msg.sender, address(this), amount);

    AToken atoken = AToken(assetToAToken[asset]);
    atoken.mint(onBehalfOf, amount);
  }

  function withdraw(
    address asset,
    uint256 amount,
    address to
  ) public virtual returns (uint256) {
    AToken atoken = AToken(assetToAToken[asset]);
    atoken.burn(msg.sender, amount);

    IERC20(asset).transfer(to, amount);
    return amount;
  }

}

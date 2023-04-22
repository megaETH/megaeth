// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StETH is ERC20 {
  using SafeMath for uint256;

  uint256 private _totalShares;
  uint256 private _totalPooledEther;

  /**
   * @dev StETH balances are dynamic and are calculated based on the accounts' shares
   * and the total amount of Ether controlled by the protocol. Account shares aren't
   * normalized, so the contract also stores the sum of all shares to calculate
   * each account's token balance which equals to:
   *
   *   shares[account] * _getTotalPooledEther() / _getTotalShares()
  */
  mapping (address => uint256) private shares;

  /**
   * @dev Allowances are nominated in tokens, not token shares.
   */
  mapping (address => mapping (address => uint256)) private allowances;

  /**
  * @notice An executed shares transfer from `sender` to `recipient`.
  *
  * @dev emitted in pair with an ERC20-defined `Transfer` event.
  */
  event TransferShares(
    address indexed from,
    address indexed to,
    uint256 sharesValue
  );

  /**
   * @notice An executed `burnShares` request
   *
   * @dev Reports simultaneously burnt shares amount
   * and corresponding stETH amount.
   * The stETH amount is calculated twice: before and after the burning incurred rebase.
   *
   * @param account holder of the burnt shares
   * @param preRebaseTokenAmount amount of stETH the burnt shares corresponded to before the burn
   * @param postRebaseTokenAmount amount of stETH the burnt shares corresponded to after the burn
   * @param sharesAmount amount of burnt shares
   */
  event SharesBurnt(
    address indexed account,
    uint256 preRebaseTokenAmount,
    uint256 postRebaseTokenAmount,
    uint256 sharesAmount
  );
  
  constructor() ERC20 ("Liquid staked Ether 2.0", "stETH") {}

  receive() external payable {
    submit();
  }

  /**
   * @dev Process user deposit, mints liquid tokens and increase the pool buffer
   * @return amount of StETH shares generated
   */
  function submit() public payable returns (uint256) {
    require(msg.value != 0, "ZERO_DEPOSIT");

    uint256 sharesAmount = getSharesByPooledEth(msg.value);
    if (sharesAmount == 0) {
      // totalControlledEther is 0: either the first-ever deposit or complete slashing
      // assume that shares correspond to Ether 1-to-1
      sharesAmount = msg.value;
    }
    _mintShares(msg.sender, sharesAmount);

    _totalPooledEther = _totalPooledEther.add(msg.value);

    _emitTransferAfterMintingShares(msg.sender, sharesAmount);
    return sharesAmount;
  }

 /**
  * @notice A payable function for execution layer rewards. Can be called only by ExecutionLayerRewardsVault contract
  * @dev We need a dedicated function because funds received by the default payable function
  * are treated as a user deposit
  */
  function receiveELRewards() external payable {
    _totalPooledEther = _totalPooledEther.add(msg.value);
  }

  /**
   * @return the amount of tokens in existence.
   *
   * @dev Always equals to `_getTotalPooledEther()` since token amount
   * is pegged to the total amount of Ether controlled by the protocol.
   */
  function totalSupply() public view override returns (uint256) {
    return _getTotalPooledEther();
  }

  /**
   * @return the entire amount of Ether controlled by the protocol.
   *
   * @dev The sum of all ETH balances in the protocol, equals to the total supply of stETH.
   */
  function getTotalPooledEther() public view returns (uint256) {
    return _getTotalPooledEther();
  }

  function _getTotalPooledEther() internal view returns (uint256) {
    return _totalPooledEther;
  }

  /**
   * @return the amount of tokens owned by the `_account`.
   *
   * @dev Balances are dynamic and equal the `_account`'s share in the amount of the
   * total Ether controlled by the protocol. See `sharesOf`.
   */
  function balanceOf(address _account) public view override returns (uint256) {
    return getPooledEthByShares(_sharesOf(_account));
  }

  /**
   * @notice Moves `_amount` tokens from the caller's account to the `_recipient` account.
   *
   * @return a boolean value indicating whether the operation succeeded.
   * Emits a `Transfer` event.
   * Emits a `TransferShares` event.
   *
   * Requirements:
   *
   * - `_recipient` cannot be the zero address.
   * - the caller must have a balance of at least `_amount`.
   * - the contract must not be paused.
   *
   * @dev The `_amount` argument is the amount of tokens, not shares.
   */
  function transfer(address _recipient, uint256 _amount) public override returns (bool) {
    _transfer(msg.sender, _recipient, _amount);
    return true;
  }

  /**
   * @return the remaining number of tokens that `_spender` is allowed to spend
   * on behalf of `_owner` through `transferFrom`. This is zero by default.
   *
   * @dev This value changes when `approve` or `transferFrom` is called.
   */
  function allowance(address _owner, address _spender) public view override returns (uint256) {
    return allowances[_owner][_spender];
  }

  /**
   * @notice Sets `_amount` as the allowance of `_spender` over the caller's tokens.
   *
   * @return a boolean value indicating whether the operation succeeded.
   * Emits an `Approval` event.
   *
   * Requirements:
   *
   * - `_spender` cannot be the zero address.
   * - the contract must not be paused.
   *
   * @dev The `_amount` argument is the amount of tokens, not shares.
   */
  function approve(address _spender, uint256 _amount) public override returns (bool) {
    _approve(msg.sender, _spender, _amount);
    return true;
  }

  /**
   * @notice Moves `_amount` tokens from `_sender` to `_recipient` using the
   * allowance mechanism. `_amount` is then deducted from the caller's
   * allowance.
   *
   * @return a boolean value indicating whether the operation succeeded.
   *
   * Emits a `Transfer` event.
   * Emits a `TransferShares` event.
   * Emits an `Approval` event indicating the updated allowance.
   *
   * Requirements:
   *
   * - `_sender` and `_recipient` cannot be the zero addresses.
   * - `_sender` must have a balance of at least `_amount`.
   * - the caller must have allowance for `_sender`'s tokens of at least `_amount`.
   * - the contract must not be paused.
   *
   * @dev The `_amount` argument is the amount of tokens, not shares.
   */
  function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
    uint256 currentAllowance = allowances[_sender][msg.sender];
    require(currentAllowance >= _amount, "TRANSFER_AMOUNT_EXCEEDS_ALLOWANCE");

    _transfer(_sender, _recipient, _amount);
    _approve(_sender, msg.sender, currentAllowance.sub(_amount));
    return true;
  }

  /**
   * @notice Moves `_amount` tokens from `_sender` to `_recipient`.
   * Emits a `Transfer` event.
   * Emits a `TransferShares` event.
   */
  function _transfer(address _sender, address _recipient, uint256 _amount) override internal {
    uint256 _sharesToTransfer = getSharesByPooledEth(_amount);
    _transferShares(_sender, _recipient, _sharesToTransfer);
    emit Transfer(_sender, _recipient, _amount);
    emit TransferShares(_sender, _recipient, _sharesToTransfer);
  }

  /**
   * @return the amount of shares owned by `_account`.
   */
  function _sharesOf(address _account) internal view returns (uint256) {
    return shares[_account];
  }

  /**
   * @notice Sets `_amount` as the allowance of `_spender` over the `_owner` s tokens.
   *
   * Emits an `Approval` event.
   *
   * Requirements:
   *
   * - `_owner` cannot be the zero address.
   * - `_spender` cannot be the zero address.
   * - the contract must not be paused.
   */
  function _approve(address _owner, address _spender, uint256 _amount) internal override {
    require(_owner != address(0), "APPROVE_FROM_ZERO_ADDRESS");
    require(_spender != address(0), "APPROVE_TO_ZERO_ADDRESS");

    allowances[_owner][_spender] = _amount;
    emit Approval(_owner, _spender, _amount);
  }

  /**
   * @return the amount of shares that corresponds to `_ethAmount` protocol-controlled Ether.
   */
  function getSharesByPooledEth(uint256 _ethAmount) public view returns (uint256) {
    uint256 totalPooledEther = _getTotalPooledEther();
    if (totalPooledEther == 0) {
      return 0;
    } else {
      return _ethAmount
        .mul(_getTotalShares())
        .div(totalPooledEther);
    }
  }

  /**
   * @return the amount of Ether that corresponds to `_sharesAmount` token shares.
   */
  function getPooledEthByShares(uint256 _sharesAmount) public view returns (uint256) {
    uint256 totalShares = _getTotalShares();
    if (totalShares == 0) {
      return 0;
    } else {
      return _sharesAmount
        .mul(_getTotalPooledEther())
        .div(totalShares);
    }
  }

  /**
   * @return the total amount of shares in existence.
   *
   * @dev The sum of all accounts' shares can be an arbitrary number, therefore
   * it is necessary to store it in order to calculate each account's relative share.
   */
  function getTotalShares() public view returns (uint256) {
      return _getTotalShares();
  }

  /**
   * @return the amount of shares owned by `_account`.
   */
  function sharesOf(address _account) public view returns (uint256) {
      return _sharesOf(_account);
  }

  /**
   * @return the total amount of shares in existence.
   */
  function _getTotalShares() internal view returns (uint256) {
    return _totalShares;
  }

  /**
   * @notice Moves `_sharesAmount` shares from `_sender` to `_recipient`.
   *
   * Requirements:
   *
   * - `_sender` cannot be the zero address.
   * - `_recipient` cannot be the zero address.
   * - `_sender` must hold at least `_sharesAmount` shares.
   * - the contract must not be paused.
   */
  function _transferShares(address _sender, address _recipient, uint256 _sharesAmount) internal {
    require(_sender != address(0), "TRANSFER_FROM_THE_ZERO_ADDRESS");
    require(_recipient != address(0), "TRANSFER_TO_THE_ZERO_ADDRESS");

    uint256 currentSenderShares = shares[_sender];
    require(_sharesAmount <= currentSenderShares, "TRANSFER_AMOUNT_EXCEEDS_BALANCE");

    shares[_sender] = currentSenderShares.sub(_sharesAmount);
    shares[_recipient] = shares[_recipient].add(_sharesAmount);
  }

  /**
   * @notice Creates `_sharesAmount` shares and assigns them to `_recipient`, increasing the total amount of shares.
   * @dev This doesn't increase the token total supply.
   *
   * Requirements:
   *
   * - `_recipient` cannot be the zero address.
   * - the contract must not be paused.
   */
  function _mintShares(address _recipient, uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
    require(_recipient != address(0), "MINT_TO_THE_ZERO_ADDRESS");

    newTotalShares = _getTotalShares().add(_sharesAmount);
    _totalShares = newTotalShares;

    shares[_recipient] = shares[_recipient].add(_sharesAmount);
  }

  /**
   * @notice Destroys `_sharesAmount` shares from `_account`'s holdings, decreasing the total amount of shares.
   * @dev This doesn't decrease the token total supply.
   *
   * Requirements:
   *
   * - `_account` cannot be the zero address.
   * - `_account` must hold at least `_sharesAmount` shares.
   * - the contract must not be paused.
   */
  function _burnShares(address _account, uint256 _sharesAmount) internal returns (uint256 newTotalShares) {
    require(_account != address(0), "BURN_FROM_THE_ZERO_ADDRESS");

    uint256 accountShares = shares[_account];
    require(_sharesAmount <= accountShares, "BURN_AMOUNT_EXCEEDS_BALANCE");

    uint256 preRebaseTokenAmount = getPooledEthByShares(_sharesAmount);

    newTotalShares = _getTotalShares().sub(_sharesAmount);
    _totalShares = newTotalShares;

    shares[_account] = accountShares.sub(_sharesAmount);

    uint256 postRebaseTokenAmount = getPooledEthByShares(_sharesAmount);

    emit SharesBurnt(_account, preRebaseTokenAmount, postRebaseTokenAmount, _sharesAmount);
  }

  /**
  * @dev Emits {Transfer} and {TransferShares} events where `from` is 0 address. Indicates mint events.
  */
  function _emitTransferAfterMintingShares(address _to, uint256 _sharesAmount) internal {
    emit Transfer(address(0), _to, getPooledEthByShares(_sharesAmount));
    emit TransferShares(address(0), _to, _sharesAmount);
  }

}
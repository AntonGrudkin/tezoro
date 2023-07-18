// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.9.2/access/Ownable.sol";
import "@openzeppelin/contracts@4.9.2/token/ERC20/IERC20.sol";
import "./Tezoro.sol";

contract Withdrawable is Ownable {
    error NoFundsToWithdraw();
    error NoTokensToWithdraw();
    error TransferFailed();

    function withdraw(address _receiver) external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw();
        (bool success, ) = payable(_receiver).call{value: balance}("");
        if (!success) revert TransferFailed();
    }

    function withdrawToken(address _receiver, address _tokenAddress) external onlyOwner {
        IERC20 token = IERC20(_tokenAddress);
        uint256 tokenBalance = token.balanceOf(address(this));
        if (tokenBalance == 0) revert NoTokensToWithdraw();
        token.transfer(_receiver, tokenBalance);
    }
}

contract TezoroService is Withdrawable {
    uint8 public constant version = 5;
    uint256 public constant MIN_DELAY = 2592000;

    uint256 public serviceFee;
    address public creatorAddress;

    uint256 public immutable delay;

    error InsufficientPaymentForService();
    error ZeroAddress();
    error ZeroFee();
    error InsufficientDelay();

    event DeployedBackupContract(
        address indexed backupContract,
        address indexed deployer,
        bytes32 userHash,
        bytes32 metaId
    );

    constructor(
        uint256 _initialServiceFee,
        uint256 _delay
    ) {
        if (_delay < MIN_DELAY) revert InsufficientDelay();
        serviceFee = _initialServiceFee;
        creatorAddress = msg.sender;
        delay = _delay;
    }

    function setCreator(address _newCreatorAddress) external onlyOwner {
        if (_newCreatorAddress == address(0)) revert ZeroAddress();
        creatorAddress = _newCreatorAddress;
    }

    function deployBackupContract(
        address _beneficiaryAddress,
        address _tokenAddress,
        address _executor1,
        address _executor2,
        bytes32 _userHash,
        bytes32 _metaId
    ) external payable {
        if (msg.value < serviceFee) revert InsufficientPaymentForService();
        if (_beneficiaryAddress == address(0) || _tokenAddress == address(0))
            revert ZeroAddress();

        Tezoro backupContract = new Tezoro(
            creatorAddress,
            msg.sender,
            _executor1,
            _executor2,
            _beneficiaryAddress,
            _tokenAddress,
            delay
        );

        emit DeployedBackupContract(
            address(backupContract),
            msg.sender,
            _userHash,
            _metaId
        );
    }
    
    function setFee(uint256 _newServiceFee) external onlyOwner {
        if (_newServiceFee == 0) revert ZeroFee();
        serviceFee = _newServiceFee;
    }
}

// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "./Tezoro.sol";

contract TezoroService {
    uint8 public constant version = 4;
    uint256 public immutable serviceFee;
    address public immutable creator;
    address public immutable multiSigOwner;
    uint256 public immutable delay;
    uint256 public immutable withdrawalDelay;
    uint256 public withdrawalTimestamp;

    error InsufficientPaymentForService();
    error ZeroAddress();
    error NoFundsToWithdraw();
    error TransferFailed();
    error NotOwner();
    error WithdrawalAlreadyInitiated();
    error WithdrawalNotInitiated();
    error TooEarly();

    modifier onlyOwner() {
        if (msg.sender != multiSigOwner) revert NotOwner();
        _;
    }

    event WithdrawalInitiated();
    event WithdrawalCancelled();
    event Withdrawn();

    event DeployedBackupContract(
        address indexed backupContract,
        address indexed deployer,
        bytes32 userHash,
        bytes32 metaId
    );

    constructor(
        address _multiSigOwner,
        uint256 _initialServiceFee,
        uint256 _delay,
        uint256 _withdrawalDelay
    ) {
        if (_multiSigOwner == address(0)) revert ZeroAddress();
        multiSigOwner = _multiSigOwner;
        creator = msg.sender;
        serviceFee = _initialServiceFee;
        delay = _delay;
        withdrawalDelay = _withdrawalDelay;
        withdrawalTimestamp = 0;
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
            creator,
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
    
    function initiateWithdrawal() external onlyOwner {
        if (withdrawalTimestamp != 0) revert WithdrawalAlreadyInitiated();
        withdrawalTimestamp = block.timestamp + withdrawalDelay;
        emit WithdrawalInitiated();
    }

    function cancelWithdrawal() external onlyOwner {
        if (withdrawalTimestamp == 0) revert WithdrawalNotInitiated();
        withdrawalTimestamp = 0;
        emit WithdrawalCancelled();
    }

    function withdraw() external onlyOwner {
        if (withdrawalTimestamp == 0) revert WithdrawalNotInitiated();
        if (block.timestamp < withdrawalTimestamp) revert TooEarly();

        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw();
        (bool success, ) = payable(multiSigOwner).call{value: balance}("");
        if (!success) revert TransferFailed();
        emit Withdrawn();
    }
}

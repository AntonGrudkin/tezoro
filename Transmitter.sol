// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IWithdrawable {
    function withdraw() external;
    function transferOwnership(address newOwner) external;
}

contract Transmitter is Ownable {
    address private target;
    address private receiver;

    error ZeroAddress();

    error NoFundsToWithdraw();
    error TransferFailed();

    event TargetChanged(address newTarget);
    event ReceiverChanged(address newReceiver);
    event Withdrawed(uint256 timestamp);

    constructor (
        address _target,
        address _receiver
    ) {
        setTarget(_target);
        setReceiver(_receiver);
    }

    function withdraw() external onlyOwner {
        IWithdrawable(target).withdraw();
        emit Withdrawed(block.timestamp);
    }

    function transferTargetOwnership(address _newAddress) external onlyOwner {
        IWithdrawable(target).transferOwnership(_newAddress);
    }

    function setTarget(address _newTarget) public onlyOwner {
        if (_newTarget == address(0)) revert ZeroAddress();
        target = _newTarget;
        emit TargetChanged(_newTarget);
    }

    function setReceiver(address _newReceiver) public onlyOwner {
        if (_newReceiver == address(0)) revert ZeroAddress();
        receiver = _newReceiver;
        emit ReceiverChanged(_newReceiver);
    }

    receive() external payable {
        uint256 balance = address(this).balance;
        if (balance == 0) revert NoFundsToWithdraw();
        (bool success, ) = payable(receiver).call{value: balance}("");
        if (!success) revert TransferFailed();
    }
}

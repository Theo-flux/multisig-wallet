// Layout of Contract:
// license
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract AbstractMultiSigWallet {
    // errors
    error MultiSigWallet__EmptyApprovers();
    error MultiSigWallet__ZeroConfirmers();
    error MultiSigWallet__NotOwner();
    error MultiSigWallet__InsufficientBallance();

    // events
    event MultiSigWalletDeposit(address indexed sender, uint256 amount);
}

contract MultiSigWallet is AbstractMultiSigWallet {
    // Type decleration
    struct Confirmers {
        address confirmerAddr;
        bool isConfirmed;
        uint256 dateConfirmed;
    }

    struct WalletTransaction {
        address destinationAddr;
        uint256 amount;
        uint256 dateInitiated;
        uint256 dateApproved;
        address initiatingAddr;
        uint256 numberOfConfirmations;
        Confirmers[] confirmers;
    }

    // State variables
    uint256 private immutable I_NO_OF_CONFIRMATIONS;

    address[] private sOwners;
    mapping(uint256 trnxId => WalletTransaction transaction) sTransactionHistory;

    constructor(address[] memory _owners, uint256 _noOfConfirmations) {
        if (_owners.length == 0) {
            revert MultiSigWallet__EmptyApprovers();
        }

        if (_noOfConfirmations == 0) {
            revert MultiSigWallet__ZeroConfirmers();
        }

        for (uint256 i = 0; i < _owners.length; i++) {
            sOwners.push(_owners[i]);
        }
        I_NO_OF_CONFIRMATIONS = _noOfConfirmations;
    }

    modifier isOwner() {
        _isOwner();
        _;
    }

    receive() external payable {
        emit MultiSigWalletDeposit(msg.sender, msg.value);
    }

    function _isOwner() internal view {
        bool flag = false;
        for (uint256 i = 0; i < sOwners.length; i++) {
            if (msg.sender == sOwners[i]) {
                flag = true;
                break;
            }
        }
        if (!flag) {
            revert MultiSigWallet__NotOwner();
        }
    }

    function initiateTransaction(
        address _destinationAddress,
        uint256 _amount
    ) public isOwner {}

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }
}

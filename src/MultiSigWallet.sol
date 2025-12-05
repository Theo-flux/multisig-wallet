// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract AbstractMultiSigWallet {
    // errors
    error MultiSigWallet__EmptyApprovers();
    error MultiSigWallet__ZeroConfirmers();
    error MultiSigWallet__NotOwner();
    error MultiSigWallet__InsufficientBallance();
    error MultiSigWallet__InvalidTransaction();
    error MmultiSigWaller_TransactionFailed();
    error MultiSigWallet__TransactionAlreadyExecuted();
    error MultiSigWallet__TransactionAlreadyConfirmed();
    error MultiSigWallet__TransactionPendingConfirmation();

    // events
    event TransactionDeposit(address indexed sender, uint256 amount);
    event TransactionConfirmation(
        uint256 indexed trnxId,
        address indexed confirmer
    );
    event TransactionExecuted(
        uint256 indexed trnxId,
        address indexed sender,
        address indexed receiver
    );
}

contract MultiSigWallet is AbstractMultiSigWallet {
    // Type decleration
    struct Confirmer {
        address addr;
        uint256 dateConfirmed;
    }

    struct WalletTransaction {
        address destinationAddr;
        uint256 amount;
        uint256 dateInitiated;
        uint256 dateApproved;
        address initiatingAddr;
        uint256 totalConfirmers;
        bool isExecuted;
    }

    // State variables
    uint256 private immutable I_NO_OF_CONFIRMATIONS;

    address[] private sOwners;
    uint256 private sTotalTrnxs;
    mapping(uint256 trnxId => WalletTransaction transaction)
        private sTrnxHistory;
    mapping(uint256 trnxId => mapping(address => uint256))
        private sTrnxConfirmedTime;
    mapping(uint256 trnxId => mapping(address => bool))
        private sIsTrnxConfirmed;

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

    receive() external payable {
        emit TransactionDeposit(msg.sender, msg.value);
    }

    modifier onlyOwner() {
        _isOwner();
        _;
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
    ) public onlyOwner {
        if (address(this).balance <= _amount) {
            revert MultiSigWallet__InsufficientBallance();
        }

        uint256 trnxId = sTotalTrnxs;
        sTrnxHistory[trnxId] = WalletTransaction({
            initiatingAddr: msg.sender,
            destinationAddr: _destinationAddress,
            amount: _amount,
            dateInitiated: block.timestamp,
            dateApproved: 0,
            totalConfirmers: 0,
            isExecuted: false
        });
        _confirmTrnx(trnxId, msg.sender);
        sTotalTrnxs++;
    }

    function confirmTrnx(uint256 _trnxId) internal onlyOwner {
        if (!(_trnxId < sTotalTrnxs)) {
            revert MultiSigWallet__InvalidTransaction();
        }
        if (sTrnxHistory[_trnxId].isExecuted) {
            revert MultiSigWallet__TransactionAlreadyExecuted();
        }
        if (sIsTrnxConfirmed[_trnxId][msg.sender]) {
            revert MultiSigWallet__TransactionAlreadyConfirmed();
        }
        _confirmTrnx(_trnxId, msg.sender);
    }

    function _confirmTrnx(uint256 _trnxId, address _confirmerAddr) private {
        WalletTransaction storage trnx = sTrnxHistory[_trnxId];
        sIsTrnxConfirmed[_trnxId][_confirmerAddr] = true;
        sTrnxConfirmedTime[_trnxId][_confirmerAddr] = block.timestamp;
        trnx.totalConfirmers++;

        emit TransactionConfirmation(_trnxId, _confirmerAddr);

        if (trnx.totalConfirmers >= I_NO_OF_CONFIRMATIONS) {
            _executeTrnx(_trnxId);
        }
    }

    function _executeTrnx(uint256 _trnxId) private {
        WalletTransaction storage trnx = sTrnxHistory[_trnxId];

        if (trnx.totalConfirmers < I_NO_OF_CONFIRMATIONS) {
            revert MultiSigWallet__TransactionPendingConfirmation();
        }
        if (address(this).balance <= trnx.amount) {
            revert MultiSigWallet__InsufficientBallance();
        }

        (bool success, ) = payable(trnx.destinationAddr).call{
            value: trnx.amount
        }("");

        if (!success) {
            revert MmultiSigWaller_TransactionFailed();
        }

        trnx.isExecuted = true;
        emit TransactionExecuted(
            _trnxId,
            trnx.initiatingAddr,
            trnx.destinationAddr
        );
    }

    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    function getTotalTrnxs() external view returns (uint256) {
        return sTotalTrnxs + 1;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract AbstractMultiSigWallet {
    // errors
    error MultiSigWallet__EmptyApprovers();
    error MultiSigWallet__ZeroConfirmers();
    error MultiSigWallet__InvalidThreshold();
    error MultiSigWallet__InvalidOwner();
    error MultiSigWallet__OwnerNotUnique();
    error MultiSigWallet__InsufficientBallance();
    error MultiSigWallet__NotOwner();
    error MultiSigWallet__InvalidTransaction();
    error MultiSigWallet__TransactionFailed();
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
    uint256 private sTotalTrnxs;

    mapping(address => bool) private sOwners;
    mapping(uint256 trnxId => WalletTransaction transaction)
        private sTrnxHistory;
    mapping(uint256 trnxId => mapping(address => uint256))
        private sTrnxConfirmedTime;
    mapping(uint256 trnxId => mapping(address => bool))
        private sIsTrnxConfirmed;

    constructor(address[] memory _owners, uint256 _noOfConfirmations) {
        if (_owners.length == 0) revert MultiSigWallet__EmptyApprovers();
        if (_noOfConfirmations > _owners.length)
            revert MultiSigWallet__InvalidThreshold();
        if (_noOfConfirmations == 0) revert MultiSigWallet__ZeroConfirmers();

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            if (owner == address(0)) revert MultiSigWallet__InvalidOwner();
            if (_addrExistsInOwners(owner))
                revert MultiSigWallet__OwnerNotUnique();

            sOwners[owner] = true;
        }

        I_NO_OF_CONFIRMATIONS = _noOfConfirmations;
    }

    receive() external payable {
        emit TransactionDeposit(msg.sender, msg.value);
    }

    modifier onlyOwner() {
        _onlyOwner();
        _;
    }

    function _onlyOwner() internal view {
        if (!sOwners[msg.sender]) revert MultiSigWallet__NotOwner();
    }

    modifier onlyConfirmer(address _addr) {
        _onlyConfirmer(_addr);
        _;
    }

    function _onlyConfirmer(address _addr) internal view {
        if (!sOwners[_addr]) revert MultiSigWallet__NotOwner();
    }

    modifier onlyValidTrnx(uint256 _txId) {
        _onlyValidTrnx(_txId);
        _;
    }

    function _onlyValidTrnx(uint256 _txId) internal view {
        if (!(_txId < sTotalTrnxs)) revert MultiSigWallet__InvalidTransaction();
    }

    function _addrExistsInOwners(address _addr) internal view returns (bool) {
        if (sOwners[_addr]) return true;
        return false;
    }

    function initiateTransaction(
        address _destinationAddress,
        uint256 _amount
    ) public onlyOwner {
        if (address(this).balance <= _amount)
            revert MultiSigWallet__InsufficientBallance();

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

    function confirmTrnx(
        uint256 _txId,
        address _confirmerAddr
    ) external onlyConfirmer(_confirmerAddr) onlyValidTrnx(_txId) {
        if (sTrnxHistory[_txId].isExecuted)
            revert MultiSigWallet__TransactionAlreadyExecuted();
        if (sIsTrnxConfirmed[_txId][msg.sender])
            revert MultiSigWallet__TransactionAlreadyConfirmed();
        _confirmTrnx(_txId, msg.sender);
    }

    function revokeTrnxConfirmation(
        uint256 _txId,
        address _confirmerAddr
    ) external onlyConfirmer(_confirmerAddr) onlyValidTrnx(_txId) {
        WalletTransaction storage trnx = sTrnxHistory[_txId];

        if (sIsTrnxConfirmed[_txId][_confirmerAddr]) {
            trnx.totalConfirmers--;
        }
        sIsTrnxConfirmed[_txId][_confirmerAddr] = false;
        sTrnxConfirmedTime[_txId][_confirmerAddr] = block.timestamp;

        emit TransactionConfirmation(_txId, _confirmerAddr);
    }

    function _confirmTrnx(
        uint256 _txId,
        address _confirmerAddr
    ) private onlyOwner onlyValidTrnx(_txId) {
        WalletTransaction storage trnx = sTrnxHistory[_txId];
        sIsTrnxConfirmed[_txId][_confirmerAddr] = true;
        sTrnxConfirmedTime[_txId][_confirmerAddr] = block.timestamp;
        trnx.totalConfirmers++;

        emit TransactionConfirmation(_txId, _confirmerAddr);

        if (trnx.totalConfirmers >= I_NO_OF_CONFIRMATIONS) _executeTrnx(_txId);
    }

    function _executeTrnx(uint256 _txId) private {
        WalletTransaction storage trnx = sTrnxHistory[_txId];

        if (trnx.totalConfirmers < I_NO_OF_CONFIRMATIONS)
            revert MultiSigWallet__TransactionPendingConfirmation();
        if (address(this).balance <= trnx.amount)
            revert MultiSigWallet__InsufficientBallance();

        trnx.isExecuted = true;
        (bool success, ) = payable(trnx.destinationAddr).call{
            value: trnx.amount
        }("");

        if (!success) {
            trnx.isExecuted = false;
            revert MultiSigWallet__TransactionFailed();
        }

        emit TransactionExecuted(
            _txId,
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

    function getTrnx(
        uint256 _txId
    ) external view onlyValidTrnx(_txId) returns (WalletTransaction memory) {
        return sTrnxHistory[_txId];
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./SafeMath.sol";
import "./QDAOInterfaces.sol";

contract QDAOTimelock is QDAOTimelockInterface {

    using SafeMath for uint;

    event NewDelay(uint indexed newDelay);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value, bytes data, uint eta);
    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value, bytes data, uint eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value, bytes data, uint eta);

    address public admin;

    address public pendingAdmin;

    address public delegator;

    uint public delay;

    address public contractAddress;

    mapping (bytes32 => bool) public queuedTransactions;

    constructor(uint _delay, address _admin) {

        admin = _admin;
        delay = _delay;
        contractAddress = address(this);
    }

    modifier onlyAdmin() {
        require(this.admin() == msg.sender, "QDAOTimelock::onlyAdmin: Caller is not the admin");
        _;
    }


     modifier onlyGovernorDelegator() {
        require(delegator != address(0), "QDAOTimelock::onlyGovernorDelegator: Delegator is not set");
        require(this.delegator() == msg.sender, "QDAOTimelock::onlyGovernorDelegator: Caller is not the QDAOGovernorDelegator");
        _;
    }

    
    modifier onlyTimelock() {
        require(address(this) == msg.sender, "QDAOTimelock::onlyTimelock: Caller is not the Timelock");
        _;
    }

    /// @notice Enqueue a transaction
    function queueTransaction(
        address target,
        uint value,
        bytes memory data,
        uint eta) 
        public onlyGovernorDelegator returns (bytes32)  {
            
            require(eta >= getBlockTimestamp().add(delay), "QDAOTimelock::queueTransaction: Estimated execution block must satisfy delay.");

            bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
            queuedTransactions[txHash] = true;

            emit QueueTransaction(txHash, target, value, data, eta);

            return txHash;
        }


    /// @notice Cancel a transaction
    function cancelTransaction(
        address target,
        uint value,
        bytes memory data, 
        uint eta) public onlyGovernorDelegator {
      
        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
        queuedTransactions[txHash] = false;

        emit CancelTransaction(txHash, target, value, data, eta);
    }

    /// @notice Executes queued transactions
    function executeTransaction(
        address target, 
        uint value, 
        bytes memory data, 
        uint eta) 
        public payable onlyGovernorDelegator returns (bytes memory) {

        bytes32 txHash = keccak256(abi.encode(target, value, data, eta));
       
        require(queuedTransactions[txHash], "QDAOTimelock::executeTransaction: Transaction hasn't been queued.");
        require(getBlockTimestamp() >= eta, "QDAOTimelock::executeTransaction: Transaction hasn't surpassed time lock.");

        queuedTransactions[txHash] = false;

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(data);
        require(success, "QDAOTimelock::executeTransaction: Transaction execution reverted.");

        return returnData;
    }

    /// @notice Sets delegator contract's address
    function setDelegator(address _delegator) public onlyAdmin() {
        require(delegator == address(0), "QDAOTimelock::setDelegator: Delegator already set");
        delegator = _delegator;
    }

    fallback() external payable { }

    function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }
}
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "./SafeMath.sol";
import "./QDAOGovernorInterfaces.sol";

contract QDAOTimelockController is QDAOTimelockInterface {

    using SafeMath for uint;

    // Действующий администратор
    address public admin;

    // Новый администратор в процессе перехода
    address public pendingAdmin;


    // Задержка перед выполнением транзакции
    uint public delay;

    uint public constant GRACE_PERIOD = 14 days;
    uint public constant MINIMUM_DELAY = 2 days;
    uint public constant MAXIMUM_DELAY = 30 days;


    constructor(address admin_, uint delay_) {
            require(delay_ >= MINIMUM_DELAY, "QDAOTimelockController::constructor: Delay must exceed minimum delay.");
            require(delay_ <= MAXIMUM_DELAY, "QDAOTimelockController::constructor: Delay must not exceed maximum delay.");

            admin = admin_;
            delay = delay_;
    }


    /// @dev Методы, помеченные этим модификатором могут выполняться только администратором.
    modifier onlyAdmin() {
        require(this.admin() == msg.sender, "QDAOTimelockController::onlyAdmin: Caller is not the admin");
        _;
    }

    
    /// @dev Методы, помеченные этим модификатором могут выполняться только контрактом QDAOTimelockController.
    modifier onlyTimelock() {
        require(address(this) == msg.sender, "QDAOTimelockController::onlyTimelock: Caller is not the Timelock");
        _;
    }

    // Модуль работы с выполнением предложений

    /// @notice Поставить транзакцию в очередь
    function queueTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta) 
        public onlyAdmin returns (bytes32) {

            require(eta >= getBlockTimestamp().add(delay), "QDAOTimelockController::queueTransaction: Estimated execution block must satisfy delay.");

            bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));

            emit QueueTransaction(txHash, target, value, signature, data, eta);
            return txHash;
        }


    function cancelTransaction(
        address target,
        uint value,
        string memory signature, 
        bytes memory data, 
        uint eta) public onlyAdmin {
      
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
    
        emit CancelTransaction(txHash, target, value, signature, data, eta);
    }

    // Выполнять поставленные в очередь транзакции может только администратор
    function executeTransaction(
        address target, 
        uint value, 
        string memory signature, 
        bytes memory data, 
        uint eta) 
        public payable onlyAdmin returns (bytes memory) {

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
       
        require(getBlockTimestamp() >= eta, "QDAOTimelockController::executeTransaction: Transaction hasn't surpassed time lock.");
        require(getBlockTimestamp() <= eta.add(GRACE_PERIOD), "QDAOTimelockController::executeTransaction: Transaction is stale.");

        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        // solium-disable-next-line security/no-call-value
        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, "QDAOTimelockController::executeTransaction: Transaction execution reverted.");

        emit ExecuteTransaction(txHash, target, value, signature, data, eta);

        return returnData;
    }

     function getBlockTimestamp() internal view returns (uint) {
        // solium-disable-next-line security/no-block-members
        return block.timestamp;
    }

    // Модуль работы с администрированием


    // Установить нового администратора в обработку
    function setPendingAdmin(address pendingAdmin_) public onlyTimelock {
        require(msg.sender == address(this), "QDAOTimelockController::setPendingAdmin: Call must come from Timelock.");
        pendingAdmin = pendingAdmin_;

        emit NewPendingAdmin(pendingAdmin);
    }

    // Новый администратор подтверждает и становится новым администратором
    function acceptAdmin() public {
        require(msg.sender == pendingAdmin, "QDAOTimelockController::acceptAdmin: Call must come from pendingAdmin.");
        admin = msg.sender;
        pendingAdmin = address(0);

        emit NewAdmin(admin);
    }

    // Модуль работы с кризисной ситуацией



    // Дополнительные функции
    fallback() external payable { }

}
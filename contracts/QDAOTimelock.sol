// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;


library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, reverting on overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c;
        unchecked { c = a + b; }
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting with custom message on overflow.
     */
    function add(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        uint256 c;
        unchecked { c = a + b; }
        require(c >= a, errorMessage);

        return c;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on underflow (when the result is negative).
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction underflow");
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on underflow (when the result is negative).
     */
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {

        if (a == 0) {
            return 0;
        }

        uint256 c;
        unchecked { c = a * b; }
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on overflow.
     */
    function mul(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {

        if (a == 0) {
            return 0;
        }

        uint256 c;
        unchecked { c = a * b; }
        require(c / a == b, errorMessage);

        return c;
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts on division by zero. The result is rounded towards zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    /**
     * @dev Returns the integer division of two unsigned integers.
     * Reverts with custom message on division by zero. The result is rounded towards zero.
     */
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        // Solidity only automatically asserts when dividing by 0
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts when dividing by zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * Reverts with custom message when dividing by zero.
     */
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

/**
 * @dev Блокирует на время выполнение предложений для безопасности.
 * Управляется администратором
 *
 */
contract QDAOTimelockController {
    
    using SafeMath for uint;

    // События

    event NewAdmin(address indexed newAdmin);
    event NewPendingAdmin(address indexed newPendingAdmin);
    event NewDelay(uint indexed newDelay);


    event ExecuteTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event CancelTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature,  bytes data, uint eta);
    event QueueTransaction(bytes32 indexed txHash, address indexed target, uint value, string signature, bytes data, uint eta);


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



    // Дополнительные функции
    fallback() external payable { }

}
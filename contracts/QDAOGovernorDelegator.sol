// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./QDAOInterfaces.sol";

contract QDAOGovernorDelegator is QDAOGovernorDelegatorStorage, GovernorEvents {

    event NewImplementation(address oldImplementation, address implementation);

	constructor (
			address _timelock,
			address _token,
			address _admin,
	        address _implementation,
	        uint _votingPeriod) public {
                
        admin = msg.sender;

        delegateTo(_implementation, abi.encodeWithSignature("initialize(address,address,uint256)",
                                                            _timelock,
                                                            _token,
                                                            _votingPeriod));

        setImplementation(_implementation);

        admin = _admin;
	}


	/// @notice Called by the admin to update the implementation of the delegator
    function setImplementation(address _implementation) public {
        require(msg.sender == admin, "QDAOGovernorDelegator::setImplementation: admin only");
        require( _implementation != address(0), "QDAOGovernorDelegator::setImplementation: invalid implementation address");

        address oldImplementation = implementation;
        implementation =  _implementation;

        emit NewImplementation(oldImplementation, implementation);
    }

    /// @notice Internal method to delegate execution to another contract
    function delegateTo(address callee, bytes memory data) internal {
        (bool success, bytes memory returnData) = callee.delegatecall(data);
        assembly {
            if eq(success, 0) {
                revert(add(returnData, 0x20), returndatasize())
            }
        }
    }

	/**
     * @dev Delegates execution to an implementation contract.
     * It returns to the external caller whatever the implementation returns
     * or forwards reverts.
     */
    fallback () external payable {

        // delegate all other functions to current implementation
        (bool success, ) = implementation.delegatecall(msg.data);

        assembly {
              let free_mem_ptr := mload(0x40)
              returndatacopy(free_mem_ptr, 0, returndatasize())

              switch success
              case 0 { revert(free_mem_ptr, returndatasize()) }
              default { return(free_mem_ptr, returndatasize()) }
        }
    }
}
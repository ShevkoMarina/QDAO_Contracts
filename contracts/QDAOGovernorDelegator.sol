// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./QDAOInterfaces.sol";

contract QDAOGovernorDelegator is QDAOGovernorDelegatorStorage, GovernorEvents {

    event NewImplementation(address oldImplementation, address implementation);

	constructor (
			address _timelock,
			address _token,
            address _multisig,
	        address _implementation,
	        uint _votingPeriod,
            uint _quorumNumerator) public {
                
        admin = msg.sender;

        delegateTo(_implementation, abi.encodeWithSignature("initialize(address,address,address,uint256,uint256)",
                                                            _timelock,
                                                            _token,
                                                            _multisig,
                                                            _votingPeriod,
                                                            _quorumNumerator));

        implementation = _implementation;
	}

    function setPendingImplementation(address _pendingImplementation) public {
        require(msg.sender == admin, "QDAOGovernorDelegator::setImplementation: admin only");
        require( _pendingImplementation != address(0), "QDAOGovernorDelegator::setImplementation: invalid implementation address");

        pendingImplementation = _pendingImplementation;
    }

	/// @notice Called by the admin to update the implementation of the delegator
    function setImplementation() public {
        require(msg.sender == admin, "QDAOGovernorDelegator::setImplementation: admin only");
        require(calculateApprovals(changeImplemantationMultisig) >= multisig.requiredApprovals(), "QDAOGovernorDelegator::setImplementation: not enough approvals");

        address oldImplementation = implementation;
        implementation = pendingImplementation;

        emit NewImplementation(oldImplementation, implementation);
    }

    function calculateApprovals(MultiSig storage changeImplemantationMultisig) internal view returns (uint) {
        uint8 approvals = 0;
        for (uint8 i = 0; i < multisig.getPrincipals().length; i++) 
        {
            if (changeImplemantationMultisig.principalApproved[multisig.getPrincipals()[i]]) 
            {
                approvals++;
            }
        }

        return approvals;
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
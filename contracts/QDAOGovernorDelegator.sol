// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;

import "./QDAOInterfaces.sol";

contract QDAOGovernorDelegator is QDAOGovernorDelegatorStorage, GovernorEvents {

    event NewImplementation(address oldImplementation, address implementation);
    event NewImplementationApproved();

	constructor (
			address _timelock,
			address _token,
            address _multisig,
	        address _implementation,
	        uint _votingPeriod,
            uint _quorumNumerator,
            uint _votingDelay,
            address _admin) public {
                
        admin = _admin;

        delegateTo(_implementation, abi.encodeWithSignature("initialize(address,address,address,uint256,uint256,uint256)",
                                                            _timelock,
                                                            _token,
                                                            _multisig,
                                                            _votingPeriod,
                                                            _quorumNumerator,
                                                            _votingDelay));

        implementation = _implementation;
	}

    function setPendingImplementation(address _pendingImplementation) public {
        require(msg.sender == admin, "QDAOGovernorDelegator::setImplementation: admin only");
        require( _pendingImplementation != address(0), "QDAOGovernorDelegator::setImplementation: invalid implementation address");

        pendingImplementation = _pendingImplementation;
    }

    function approveImplementationChange() public {

        require(containsValue(multisig.getPrincipals(), msg.sender), "QDAOGovernor::approve: signer is not from list of principals");
        require(changeHasApproved[msg.sender] == false, "QDAOGovernor::approve: signer has already approved");
        changeHasApproved[msg.sender] = true;

        if (calculateApprovals() >= multisig.requiredApprovals()) {
            emit NewImplementationApproved();
        }
    }

	/// @notice Called by the admin to update the implementation of the delegator
    function setImplementation() public {
        require(msg.sender == admin, "QDAOGovernorDelegator::setImplementation: admin only");
        require(calculateApprovals() >= multisig.requiredApprovals(), "QDAOGovernorDelegator::setImplementation: not enough approvals");

        address oldImplementation = implementation;
        implementation = pendingImplementation;

        pendingImplementation = address(0);
        setDefault();

        emit NewImplementation(oldImplementation, implementation);
    }

    function isPrincipalApproved(address _account) public view returns (bool) {
        return changeHasApproved[_account];
    }

    function isChangeApproved() public view returns (bool) {
        return calculateApprovals() >= multisig.requiredApprovals();
    }

    function calculateApprovals() internal view returns (uint) {
        uint8 approvals = 0;
        for (uint8 i = 0; i < multisig.getPrincipals().length; i++) 
        {
            if (changeHasApproved[multisig.getPrincipals()[i]]) 
            {
                approvals++;
            }
        }

        return approvals;
    }

    function setDefault() private {
        for (uint8 i = 0; i < multisig.getPrincipals().length; i++) 
        {
           changeHasApproved[multisig.getPrincipals()[i]] = false;
        }
    }

    function containsValue(address[] memory array, address value) public pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }
        
        return false;
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
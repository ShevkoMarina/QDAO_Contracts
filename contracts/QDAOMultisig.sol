// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;
pragma experimental ABIEncoderV2;

contract QDAOMultisig {

    address public admin;
   
    address[] public principals;

    uint8 public requiredApprovals;
    
    constructor() {
        admin = msg.sender;
    }

    function addPrincipal(
        address _principal,
        uint8 _requiredApprovals) external {
        
        require(msg.sender == admin, "QDAOMultisig: caller is not the admin");
        require(principals.length + 1 >= requiredApprovals, "QDAOMultisig: required approvals cannot be more than principals");

        principals.push(_principal);
        requiredApprovals = _requiredApprovals;
    }

    function getPrincipals() public view returns (address[] memory){
        return principals;
    }
}
    
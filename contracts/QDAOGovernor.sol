// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./QDAOGovernorInterfaces.sol";
import "./SafeMath.sol";

contract QDAOGovernor is QDAOGovernorDelegateStorageV1, GovernorEvents {

    using SafeMath for uint;

    function initialize(
        address _timelock,
        address _token,
        uint _votingPeriod) 
        public {

        timelock = QDAOTimelockInterface(_timelock);
        token = QDAOTimelockInterface(_token);
        votingPeriod = _votingPeriod;
    }


    function createProposal(
        address[] memory targets,
        uint[] memory values, 
        bytes[] memory calldatas, 
        string memory description) 
        public returns (uint) {

        // Reject proposals before initiating as Governor
        // require(initialProposalId != 0, "GovernorBravo::propose: Governor Bravo not active");
        // Allow addresses above proposal threshold and whitelisted addresses to propose
      //  require(token.getPriorVotes(msg.sender, sub256(block.number, 1)) > proposalThreshold || isWhitelisted(msg.sender), "GovernorBravo::propose: proposer votes below proposal threshold");
      //  require(targets.length == values.length && targets.length == signatures.length && targets.length == calldatas.length, "GovernorBravo::propose: proposal function information arity mismatch");
      //  require(targets.length != 0, "GovernorBravo::propose: must provide actions");
      //  require(targets.length <= proposalMaxOperations, "GovernorBravo::propose: too many actions");

        uint latestProposalId = latestProposalIds[msg.sender];
        if (latestProposalId != 0) {
          ProposalState proposersLatestProposalState = state(latestProposalId);
          require(proposersLatestProposalState != ProposalState.Active, "GovernorBravo::propose: one live proposal per proposer, found an already active proposal");
          require(proposersLatestProposalState != ProposalState.Pending, "GovernorBravo::propose: one live proposal per proposer, found an already pending proposal");
        }


        uint startBlock = block.number;
        uint endBlock = startBlock.add(votingPeriod); //add(startBlock, votingPeriod);

        proposalCount++;

        Proposal memory newProposal = Proposal({
            id: proposalCount,
            proposer: msg.sender,
            eta: 0,
            targets: targets,
            values: values,
            calldatas: calldatas,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            canceled: false,
            executed: false
        });

        proposals[newProposal.id] = newProposal;
        latestProposalIds[newProposal.proposer] = newProposal.id;

        emit ProposalCreated(newProposal.id, msg.sender, targets, values, calldatas, startBlock, endBlock, description);
        return newProposal.id;
    }

    // Надо перенести в либу
    function sub256(uint256 a, uint256 b) internal pure returns (uint) {
        require(b <= a, "subtraction underflow");
        return a - b;
    }

    function getChainIdInternal() internal pure returns (uint) {
        uint chainId;
        assembly { chainId := chainid() }
        return chainId;
    }
}
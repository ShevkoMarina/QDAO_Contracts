// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
pragma experimental ABIEncoderV2;

import "./QDAOGovernorInterfaces.sol";
import "./SafeMath.sol";


contract QDAOGovernor is QDAOGovernorDelegateStorageV1, GovernorEvents {

    using SafeMath for uint;

    function _governor() external view returns (address) {
        return address(this);
    }

    modifier onlyGovernor() {
        require(this._governor() == msg.sender, "Caller is not the DAOGovernor");
        _;
    }

    function updateVotingPeriod(uint _newValue) public onlyGovernor {
        votingPeriod = _newValue;
    }


    function initialize(
        address _timelock,
        address _token,
        uint _votingPeriod) 
        public {

        timelock = QDAOTimelockInterface(_timelock);
        token = QDAOTokenV0Interface(_token);
        votingPeriod = _votingPeriod;
        quorumNumerator = 5;
    }

    function createProposal(
        address[] memory targets,
        uint[] memory values, 
        bytes[] memory calldatas, 
        string memory description) 
        public returns (uint) {

        uint startBlock = block.number;
        uint endBlock = startBlock.add(votingPeriod); //add(startBlock, votingPeriod);

        proposalCount++;

        Proposal storage newProposal = proposals[proposalCount];

        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.calldatas = calldatas;
        newProposal.forVotes = 0;
        newProposal.againstVotes = 0;
        newProposal.executed = false;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;

        emit ProposalCreated(newProposal.id, msg.sender, targets, values, calldatas, startBlock, endBlock, description);

        return newProposal.id;
    }

    /**
      * @notice Queues a proposal of state succeeded
      * @param proposalId The id of the proposal to queue
      */
    function queue(uint proposalId) external {
        require(getState(proposalId) == ProposalState.Succeeded, "GovernorBravo::queue: proposal can only be queued if it is succeeded");
        Proposal storage proposal = proposals[proposalId];
        uint eta = block.timestamp.add(timelock.delay());

        for (uint i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(proposal.targets[i], proposal.values[i], proposal.calldatas[i], eta);
        }

        proposal.eta = eta;
    }

    // Зачем  signature?
     function queueOrRevertInternal(address target, uint value, bytes memory data, uint eta) internal {
        require(!timelock.queuedTransactions(keccak256(abi.encode(target, value, data, eta))), "GovernorBravo::queueOrRevertInternal: identical proposal action already queued at eta");
        timelock.queueTransaction(target, value, data, eta);
    }

    function execute(uint proposalId) external payable {
        require(getState(proposalId) == ProposalState.Queued, "GovernorBravo::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction(proposal.targets[i], proposal.values[i], proposal.calldatas[i], proposal.eta);
        }
    }

     function getState(uint proposalId) public view returns (ProposalState state) {

        require(proposalCount >= proposalId && proposalId > 0, "Invalid proposal id");

        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        } else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } else if (proposal.forVotes <= proposal.againstVotes || proposal.forVotes < getQuorum()) {
            return ProposalState.Defeated;
        } else if (proposal.executed) {
            return ProposalState.Executed;
        } else if (block.timestamp >= proposal.eta.add(timelock.GRACE_PERIOD())) { // Доделать
            return ProposalState.Expired;
        } else {
            return ProposalState.Queued;
        }
    }

    function vote(
        uint proposalId,
        bool support) 
        internal returns (uint256) {

        address voter = msg.sender;

        Proposal storage proposal = proposals[proposalId];
        require(getState(proposalId) == ProposalState.Active, "Proposal state must be active");

        Receipt storage receipts = proposal.receipts[voter];
        require(receipts.hasVoted == false, 'Voter already voted');

        uint256 weight = getVotes(voter);
        require(weight > 0, "Voter has no dao tokens");

        if (support) {
            proposal.forVotes += weight;
        } else {
            proposal.againstVotes += weight;
        }

        receipts.hasVoted = true;
        receipts.support = support;
        receipts.votes = weight;

        return weight;
    }


    function getVotes( address account) internal view returns (uint256) {
        return token.getCurrentVotes(account);
    }


    function getQuorum() public view returns (uint256) {
        return (token.totalSupply() * quorumNumerator) / 100;
    }

    function getChainIdInternal() internal view returns (uint) {
        return block.chainid;
    }
}
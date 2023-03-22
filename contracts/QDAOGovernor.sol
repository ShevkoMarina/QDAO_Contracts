// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;
pragma experimental ABIEncoderV2;

import "./QDAOInterfaces.sol";
import "./SafeMath.sol";


contract QDAOGovernor is QDAOGovernorDelegateStorageV1, GovernorEvents {

    using SafeMath for uint;

    function _governor() external view returns (address) {
        return address(this);
    }

    modifier onlyGovernor() {
        require(this._governor() == msg.sender, "QDAOGovernor: caller is not the governor");
        _;
    }

    modifier onlyAdmin() {
        require(admin == msg.sender, "QDAOGovernor: caller is not the admin");
        _;
    }

    function updateVotingPeriod(uint _newValue) public onlyGovernor {
        votingPeriod = _newValue;
    }

    function initialize(
        address _timelock,
        address _token,
        uint _votingPeriod,
        uint _quorumNumerator) 
        public onlyAdmin {
        
        require(address(timelock) == address(0), "QDAOGovernor::initialize: can be only be initialized once");
        require(_timelock != address(0), "QDAOGovernor::initialize: invalid timelock address");
        require(_token != address(0), "QDAOGovernor::initialize: invalid token address");

        timelock = QDAOTimelockInterface(_timelock);
        token = QDAOTokenV0Interface(_token);
        votingPeriod = _votingPeriod;
        quorumNumerator = _quorumNumerator;
    }

    function createMultisig(
        address[] memory signers,
        uint8 requiredApprovals) onlyAdmin 
        public {

        MultiSig storage newMultisig = multisig;
        newMultisig.signers = signers;
        newMultisig.requiredApprovals = requiredApprovals;
    }

    function approve(uint proposalId) public {
        Proposal storage proposal = proposals[proposalId];

        require(containsValue(multisig.signers, msg.sender), "QDAOGovernor::approve: signer is not from list of principals");
        require(proposal.hasApproved[msg.sender] == false, "QDAOGovernor::approve: signer has already approved");
        proposal.hasApproved[msg.sender] = true;
    }

    function containsValue(address[] memory array, address value) public pure returns (bool) {
        for (uint i = 0; i < array.length; i++) {
            if (array[i] == value) {
                return true;
            }
        }
        
        return false;
    }

    function createProposal(
        address[] memory targets,
        uint[] memory values, 
        bytes[] memory calldatas) 
        public returns (uint) {

        require(address(timelock) != address(0), "QDAOGovernor::createProposal: Governor is not initialized");

        uint startBlock = block.number;
        uint endBlock = startBlock.add(votingPeriod);

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

        emit ProposalCreated(newProposal.id, msg.sender, targets, values, calldatas, startBlock, endBlock);

        return newProposal.id;
    }

    function queueProposal(uint proposalId) external {

        require(getState(proposalId) == ProposalState.Succeeded, "QDAOGovernor::queue: proposal must have Succeded state");

        Proposal storage proposal = proposals[proposalId];
        uint eta = block.timestamp.add(timelock.delay());

        for (uint i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(proposal.targets[i], proposal.values[i], proposal.calldatas[i], eta);
        }

        proposal.eta = eta;
        proposal.queued = true;

        emit ProposalQueued(proposalId, eta);
    }

    function queueProposalWithNoQuorum(uint proposalId) internal onlyAdmin {
        require(multisig.signers.length > 0, "QDAOGovernor::queueForCrisisManagement: list of principals is empty");
        require(getState(proposalId) == ProposalState.NoQuorum, "QDAOGovernor::queueForCrisisManagement: proposal must have NoQuorum state");

        Proposal storage proposal = proposals[proposalId];

        uint8 approvals = calculateApprovals(proposal);
    
        require(approvals >= multisig.requiredApprovals, "QDAOGovernor::queueForCrisisManagement: not enough approvals from principals");

        uint eta = block.timestamp.add(timelock.delay());

        for (uint i = 0; i < proposal.targets.length; i++) {
            queueOrRevertInternal(proposal.targets[i], proposal.values[i], proposal.calldatas[i], eta);
        }

        proposal.eta = eta;
        proposal.queued = true;

        emit ProposalQueued(proposalId, eta);
    }

    function queueOrRevertInternal(address target, uint value, bytes memory data, uint eta) internal {
        require(!timelock.queuedTransactions(keccak256(abi.encode(target, value, data, eta))), "QDAOGovernor::queueOrRevertInternal: identical proposal action already queued at eta");
        timelock.queueTransaction(target, value, data, eta);
    }

    function calculateApprovals(Proposal storage proposal) internal view returns (uint8) {

        uint8 approvals = 0;
        for (uint8 i = 0; i < multisig.signers.length; i++) 
        {
            if (proposal.hasApproved[multisig.signers[i]]) 
            {
                approvals++;
            }
        }

        return approvals;
    }

    function executeProposal(uint proposalId) external payable {
        require(getState(proposalId) == ProposalState.Queued, "QDAOGovernor::execute: proposal can only be executed if it is queued");
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;

        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction(proposal.targets[i], proposal.values[i], proposal.calldatas[i], proposal.eta);
        }

        emit ProposalExecuted(proposalId);
    }


    function cancelProposal(uint proposalId) external {
        require(getState(proposalId) != ProposalState.Executed, "QDAOGovernor::cancel: cannot cancel executed proposal");

        Proposal storage proposal = proposals[proposalId];

        require(msg.sender == proposal.proposer || msg.sender == admin, "QDAOGovernor::cancel: only proposer or admin can cancel the proposal");
        
        proposal.canceled = true;
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.cancelTransaction(proposal.targets[i], proposal.values[i], proposal.calldatas[i], proposal.eta);
        }

        emit ProposalCanceled(proposalId);
    }


     function getState(uint proposalId) public view returns (ProposalState state) {

        require(proposalCount >= proposalId && proposalId > 0, "QDAOGovernor::getState: invalid proposal id");

        Proposal storage proposal = proposals[proposalId];

        if (proposal.canceled) {
            return ProposalState.Canceled;
        }
        else if (block.number <= proposal.endBlock) {
            return ProposalState.Active;
        } 
        else if (proposal.forVotes <= proposal.againstVotes && proposal.forVotes >= getQuorum()) {
            return ProposalState.Defeated;
        } 
        else if (proposal.eta == 0 || calculateApprovals(proposal) > multisig.requiredApprovals) {
            return ProposalState.Succeeded;
        } 
        else if (proposal.forVotes < getQuorum()) {
            return ProposalState.NoQuorum;
        }
        else if (proposal.executed) {
            return ProposalState.Executed;
        } 
        else if (block.timestamp >= proposal.eta.add(timelock.GRACE_PERIOD())) {
            return ProposalState.Expired;
        } 
        else {
            return ProposalState.Queued;
        }
    }

    function vote(
        uint proposalId,
        bool support) 
        internal returns (uint256) {

        address voter = msg.sender;

        Proposal storage proposal = proposals[proposalId];
        require(getState(proposalId) == ProposalState.Active, "QDAOGovernor::vote: proposal state must be active");

        Receipt storage receipts = proposal.receipts[voter];
        require(receipts.hasVoted == false, 'QDAOGovernor::vote: voter already voted');

        uint256 weight = getVotes(voter);
        require(weight > 0, "QDAOGovernor::vote: voter has no QDAO tokens");

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

    


    function getVotes(address account) internal view returns (uint256) {
        return token.getCurrentVotes(account);
    }

    function getQuorum() public view returns (uint256) {
        return (token.totalSupply() * quorumNumerator) / 100;
    }

    function getChainIdInternal() internal view returns (uint) {
        return block.chainid;
    }
}
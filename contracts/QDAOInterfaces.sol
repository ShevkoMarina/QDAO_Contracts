// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;


contract GovernorEvents {
    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, bytes[] calldatas, uint startBlock, uint endBlock, string name, string description);

    /// @notice An event emitted when a proposal has been canceled 
    event ProposalCanceled(uint id);

    /// @notice An event emitted when a proposal has been queued in the Timelock
    event ProposalQueued(uint id, uint eta);

    /// @notice An event emitted when a proposal has been executed in the Timelock
    event ProposalExecuted(uint id);

    /// @notice An event emitted when the voting period is set
    event VotingPeriodSet(uint oldVotingPeriod, uint newVotingPeriod);

    /// @notice An event emitted when a vote has been cast on a proposal 
    event VoteCasted(address indexed voter, uint proposalId, bool support, uint votes);

    /// @notice An event emitted when a principal approve a proposal
    event ProposalApproved(address indexed approver, uint proposalId);
}

contract QDAOGovernorDelegatorStorage {
    /// @notice Administrator for this contract
    address public admin;
    
    address public pendingImplementation;

    /// @notice Active implementation of Governor
    address public implementation;

    /// @notice Multisig with addresses of principals who approve proposals in crisis sutuation
    QDAOMultisigInterface public multisig;
    
    mapping (address => bool) changeHasApproved;
}


/**
 * @title Storage for Governor Delegator
 */
contract QDAOGovernorDelegateStorageV1 is QDAOGovernorDelegatorStorage {

    /// @notice The duration of voting on a proposal, in blocks
    uint public votingPeriod;

    /// @notice The total number of proposals
    uint public proposalCount;

    /// @notice Voting delay
    uint public votingDelay;

    /// @notice The address of the Timelock contract
    QDAOTimelockInterface public timelock;

    /// @notice The address of the QDAO token
    QDAOTokenInterface public token;

    /// @notice The record of all proposals ever proposed
    mapping (uint => Proposal) public proposals;

    struct Proposal {
        /// @notice Unique id for looking up a proposal
        uint id;

        /// @notice Creator of the proposal
        address proposer;

        /// @notice The timestamp that the proposal will be available for execution, set once the vote succeeds
        uint eta;

        /// @notice the ordered list of target addresses for calls to be made
        address[] targets;

        /// @notice The ordered list of values (i.e. msg.value) to be passed to the calls to be made
        uint[] values;

        /// @notice The ordered list of calldata to be passed to each call
        bytes[] calldatas;

        /// @notice The block at which voting begins: holders must delegate their votes prior to this block
        uint startBlock;

        /// @notice The block at which voting ends: votes must be cast prior to this block
        uint endBlock;

        /// @notice Current number of votes in favor of this proposal
        uint forVotes;

        /// @notice Current number of votes in opposition to this proposal
        uint againstVotes;

        /// @notice Flag marking whether the proposal has been canceled
        bool canceled;

        /// @notice Flag marking whether the proposal has been executed
        bool executed;

        bool queued;

        /// @notice Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;

        /// @notice Approvals from principals
        mapping(address => bool) hasApproved;
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        /// @notice Whether or not a vote has been cast
        bool hasVoted;

        /// @notice Whether or not the voter supports the proposal
        bool support;

        /// @notice The number of votes the voter had, which were cast
        uint256 votes;
    }


    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        NoQuorum,
        Succeeded,
        Queued,
        Executed
    }
    
    /// @notice Quorum numerator
    uint public quorumNumerator;
}

interface QDAOTimelockInterface {

    function delay() external view returns (uint);
    function contractAddress() external view returns (address);
    function queuedTransactions(bytes32 hash) external view returns (bool);
    function queueTransaction(address target, uint value, bytes calldata data, uint eta) external returns (bytes32);
    function cancelTransaction(address target, uint value, bytes calldata data, uint eta) external;
    function executeTransaction(address target, uint value, bytes calldata data, uint eta) external payable returns (bytes memory);
}

interface QDAOTokenInterface {
    function getPastVotes(address account, uint blockNumber) external view returns (uint96);
    function totalSupply() external view returns (uint256);
}

interface QDAOMultisigInterface {
    function getPrincipals() external view returns (address[] memory);
    function requiredApprovals() external view returns (uint);
    function addPrincipal(address _principal, uint8 _requiredApprovals) external;
}
// SPDX-License-Identifier: BSD-3-Clause
pragma solidity ^0.8.10;


contract GovernorEvents {
    /// @notice An event emitted when a new proposal is created
    event ProposalCreated(uint id, address proposer, address[] targets, uint[] values, bytes[] calldatas, uint startBlock, uint endBlock, string description);
}

contract QDAOGovernorDelegatorStorage {
    /// @notice Administrator for this contract
    address public admin;

    /// @notice Pending administrator for this contract
    address public pendingAdmin;

    /// @notice Active brains of Governor
    address public implementation;
}


/**
 * @title Storage for Governor Bravo Delegate
 * @notice For future upgrades, do not change GovernorBravoDelegateStorageV1. Create a new
 * contract which implements GovernorBravoDelegateStorageV1 and following the naming convention
 * GovernorBravoDelegateStorageVX.
 */
contract QDAOGovernorDelegateStorageV1 is QDAOGovernorDelegatorStorage {

    /// @notice The duration of voting on a proposal, in blocks
    uint public votingPeriod;

    /// @notice The total number of proposals
    uint public proposalCount;

    /// @notice The address of the Timelock contract
    QDAOTimelockInterface public timelock;

    /// @notice The address of the QDAO token
    QDAOTokenV0Interface public token;

    MultiSig public multisig;

    /// @notice The official record of all proposals ever proposed
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

       // bool approvedByPricipals;

        /// @notice Receipts of ballots for the entire set of voters
        mapping (address => Receipt) receipts;

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

    //uint256 public multisigCount;

    //mapping(uint => MultiSig) public multisigs;

    /// @notice A list of principals for crisis situation
    struct MultiSig {
        address[] signers;
        uint8 requiredApprovals;
    }

    /// @notice Possible states that a proposal may be in
    enum ProposalState {
        Active,
        Canceled,
        Defeated,
        NoQuorum,
        Succeeded,
        Queued,
        Expired,
        Executed
    }
    
    uint public quorumNumerator;
}

interface QDAOTimelockInterface {

    function delay() external view returns (uint);
    function GRACE_PERIOD() external view returns (uint);
    function acceptAdmin() external;
    function queuedTransactions(bytes32 hash) external view returns (bool);
    function queueTransaction(address target, uint value, bytes calldata data, uint eta) external returns (bytes32);
    function cancelTransaction(address target, uint value, bytes calldata data, uint eta) external;
    function executeTransaction(address target, uint value, bytes calldata data, uint eta) external payable returns (bytes memory);
}

interface QDAOTokenInterface {
    function getPastVotes(address account, uint blockNumber) external view returns (uint96);
    function totalSupply() external view returns (uint256);
}

interface QDAOTokenV0Interface {
    function getCurrentVotes(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}
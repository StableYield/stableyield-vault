// SPDX-License-Identifier: MIT
pragma solidity =0.6.10;
pragma experimental ABIEncoderV2;

import "hardhat/console.sol";

// import "./interfaces/IERC20.sol";

contract StableYieldVaultGovernance {
    uint256 private _totalStaked;
    mapping(address => uint256) private _stakedBalances;

    /***************
    GLOBAL CONSTANTS
    ***************/
    bool public processPaymentRequired;
    address public proposalSubmitToken;
    uint256 public periodDuration; // default = 17280 = 4.8 hours in seconds (5 periods per day)
    uint256 public votingPeriodLength; // default = 35 periods (7 days)
    uint256 public gracePeriodLength; // default = 35 periods (7 days)
    uint256 public proposalDeposit; // default = 10 ETH (~$1,000 worth of ETH at contract deployment)
    uint256 public dilutionBound; // default = 3 - maximum multiplier a YES voter will be obligated to pay in case of mass ragequit
    uint256 public processingReward; // default = 0.1 - amount of ETH to give to whoever processes a proposal
    uint256 public creationTime; // needed to determine the current period

    // Proposals
    uint256 public proposalCount = 0; // total proposals submitted
    uint256[] public proposalQueue;
    mapping(uint256 => Proposal) public proposals;

    // Members
    mapping(address => Member) public members;
    mapping(address => address) public memberAddressByDelegateKey;

    // Borrowers
    mapping(address => Borrower) public borrowers;
    mapping(address => bool) internal _approvedBorrowers;

    // Loans
    uint256 public loanCount = 0; // total proposals submitted
    mapping(uint256 => Loan) public loans;
    mapping(address => uint256) public totalLoans;
    mapping(uint256 => DebtUpdate) stableTokenDebt; // timestamp => (deposit/withdrawl => amount)
    mapping(uint256 => DebtUpdate) variableTokenDebt;
    uint256[] public timestampIndexQueue;

    struct DebtUpdate {
        bool updateType;
        uint256 amount;
        uint256 loanTimestamp;
    }

    /**
     * @dev Check if msg.sender is approved borrower.
     */
    modifier isBorrower() {
        require(_approvedBorrowers[msg.sender] == true);
        _;
    }

    // ***************
    // EVENTS
    // ***************
    event SubmitProposal(
        address borrower,
        address proposer,
        uint256 proposalId,
        uint256 delegationAmount,
        address delegationAsset,
        uint256 interestAmount,
        uint256 interestRateMode,
        string details,
        uint256 startingPeriod
    );

    event SponsorProposal(
        address user,
        uint256 proposalId,
        uint256 proposalIndex,
        uint256 startingPeriod
    );

    event SubmitVote(
        uint256 proposalId,
        uint256 proposalIndex,
        address user,
        uint8 vote,
        uint256 maxSharesStaked
    );

    event ProcessProposal(
        uint256 proposalIndex,
        uint256 proposalId,
        bool didPass
    );

    event LoanIssued(uint256 proposalId);

    event ProcessLoanRepayment(
        address user,
        uint256 sharesStaked,
        uint256 sharesMinted
    );

    event Withdraw(address memberAddress, address token, uint256 amount);
    event UpdateDelegateKey(address memberAddress, address newDelegateKey);
    event SharesStaked(address user, uint256 amount);
    event SharesUnlocked(address user, uint256 amount);

    enum Vote {
        Null, // default value, counted as abstention
        Yes,
        No
    }

    event CreditWithdraw(address borrower, uint256 amount, uint256 proposalId);
    event CreditRepay(
        address borrower,
        address repaymentBy,
        uint256 amount,
        uint256 proposalId
    );

    struct Borrower {
        address borrower;
        uint256 borrowLimit;
        uint256 interest;
        uint256 interestRateMode;
        uint256 creditWithdrawn;
        uint256 creditDeposited;
        address borrowAsset;
        uint256[] loans;
    }

    struct Member {
        address delegateKey; // the key responsible for submitting proposals and voting - defaults to member address unless updated
        uint256 votingShares; // the # of voting shares assigned to this member
        uint256 highestIndexYesVote; // highest proposal index # on which the member voted YES
        bool exists; // always true once a member has been created
    }

    struct YesVoteData {
        address user; // the key responsible for submitting proposals and voting - defaults to member address unless updated
        uint256 sharesLocked; // the # of voting shares assigned to this member
        bool repaymentProcessed; // Loan repayment processed
    }

    struct Proposal {
        address borrower; // the applicant who wishes to become a member - this key will be used for withdrawals (doubles as guild kick target for gkick proposals)
        address proposer; // the account that submitted the proposal (can be non-member)
        address sponsor; // the account that submitted the proposal (can be non-member)
        address delegationAsset; // Asset to loan
        uint256 delegationAmount; // Amount to loan
        uint256 interestAmount; // Amount of interest for loan (excludes the Aave fee)
        uint256 interestRateMode; // 1 = Stable or 2 = Variable
        uint256 startingPeriod; // the period in which voting can start for this proposal
        uint256 yesVotes; // the total number of YES votes for this proposal
        uint256 yesCount; // the amount of users submitting YES votes for this proposal
        uint256 noVotes; // the total number of NO votes for this proposal
        bool[4] flags; // [sponsored, processed, didPass, repaymentProcessed]
        string details; // proposal details - could be IPFS hash, plaintext, or JSON
        mapping(address => Vote) votesByMember; // the votes on this proposal by each member
        mapping(uint256 => YesVoteData) yesVoteData; // number of shares staked for credit delegation
    }

    struct Loan {
        address borrower; // the key responsible for submitting proposals and voting - defaults to member address unless updated
        address asset;
        uint256 amount;
        uint256 totalLoansAtProcess;
        uint256 timestampIndex;
        uint256 interest;
        uint256 interestRateMode;
        uint256 withdrawn;
        uint256 repayed;
        uint256 proposalId;
        bool isActive;
    }
}

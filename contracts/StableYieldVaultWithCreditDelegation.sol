// SPDX-License-Identifier: MIT
pragma solidity =0.6.10;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

import "./helpers/ReentrancyGuard.sol";
import "./interfaces/aave/IDebtToken.sol";
import "./tokens/ERC20.sol";

import "./StableYieldVaultBase.sol";
import "./StableYieldVaultGovernance.sol";

// ERC20,
contract StableYieldVaultWithCreditDelegation is
    ERC20,
    ReentrancyGuard,
    StableYieldVaultBase,
    StableYieldVaultGovernance
{
    // using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    mapping(address => uint256) private _lockedBalances;
    uint256 private _lockedTotal;
    uint256 private _lockedTimeline;

    /***********************************|
    |     		  Constructor           |
    |__________________________________*/
    /**
     * @dev Setup StableYield Smart Contracts
     */
    constructor(
        address _token,
        address _addressProvider,
        address _dataProvider,
        address[] memory _approvedTokens
    )
        public
        ERC20("StableYieldVault", "SYV")
        StableYieldVaultBase(
            _token,
            _addressProvider,
            _dataProvider,
            _approvedTokens
        )
    {
        periodDuration = 17280;
        votingPeriodLength = 35;
        gracePeriodLength = 35;
        processingReward = 0.1 ether;
        processPaymentRequired = false;

        creationTime = now;
    }

    /***********************************|
    |     	    General Public          |
    |__________________________________*/
    /**
     * @dev Deposit stablecoin into stableyield vault
     * @param asset Address of collateral to deposit
     * @param amount amount of collateral to Go
     */
    function depositCollateral(address asset, uint256 amount) public {
        uint256 shares;
        uint256 depositAmount;
        if (asset != address(token)) {
            depositAmount = _swapAssetForCurrentToken(asset, amount);
            shares = _depositCollateral(depositAmount, true);
        } else {
            depositAmount = amount;
            shares = _depositCollateral(depositAmount, false);
        }
        _addBalanceToLendingPool();
        emit DepositCollateral(depositAmount, shares, msg.sender);
    }

    /**
     * @dev Deposit stablecoin into yield
     * @param _shares Address of collateral to deposit
     */
    function withdrawCollateral(uint256 _shares) public {
        require(
            availableShares(msg.sender) > _shares,
            "shares-to-burn-exceeds-balances"
        );
        uint256 allocation = (vaultBalance().mul(_shares)).div(totalSupply());
        _burn(msg.sender, _shares);
        uint256 balance = vaultReserves();
        if (balance < allocation) {
            uint256 _withdraw = allocation.sub(balance);
            _withdrawShareFromLendingPool(_withdraw);
            uint256 _after = token.balanceOf(address(this));
            uint256 _diff = _after.sub(balance);
            if (_diff < _withdraw) {
                allocation = balance.add(_diff);
            }
        }

        token.safeTransfer(msg.sender, allocation);
        emit WithdrawCollateral(allocation, _shares, msg.sender);
    }

    /**
     * @dev Swap vault collateral
     * @param _nextToken Address of next approved token
     */
    function swapCollateral(address _nextToken) public {
        require(approvedTokens[_nextToken] = true, "unsupported-asset");

        // Asset APY Information
        (, , , uint256 liquidityRateCurrent, , , , , , ) =
            dataProvider.getReserveData(address(token));
        (, , , uint256 liquidityRateNext, , , , , , ) =
            dataProvider.getReserveData(address(_nextToken));
        require(
            liquidityRateNext > liquidityRateCurrent,
            "liquidity-rate-error"
        );

        // Reserve Token Information
        (address aTokenAddress, , ) =
            dataProvider.getReserveTokensAddresses(address(token));
        // Aave Withdraw
        IERC20 aToken = IERC20(aTokenAddress);
        uint256 balanceAToken = aToken.balanceOf(address(this));
        lendingPool.withdraw(address(token), balanceAToken, address(this));

        address pool =
            curveRegistry.find_pool_for_coins(address(token), _nextToken);
        (uint256 token_supply, uint256 token_return, ) =
            curveRegistry.get_coin_indices(pool, address(token), _nextToken);

        IERC20 token = IERC20(token);

        uint256 balanceCurrentToken = token.balanceOf(address(this));
        uint256 tokenInMin = 0x0;
        token.approve(pool, balanceCurrentToken);
        _curveExchangeUnderling(
            pool,
            int128(token_supply),
            int128(token_return),
            balanceCurrentToken,
            tokenInMin
        );

        IERC20 nextToken = IERC20(_nextToken);
        uint256 balanceNextCurrentToken = nextToken.balanceOf(address(this));

        // Aave Deposit
        _activateNextToken(_nextToken);
        lendingPool.deposit(
            _nextToken,
            balanceNextCurrentToken,
            address(this),
            referralCode
        );

        emit VaultCollateralSwap(
            address(token),
            _nextToken,
            liquidityRateCurrent,
            liquidityRateNext,
            0x0,
            msg.sender,
            block.timestamp
        );
    }

    /***********************************|
    |     	  General Internal          |
    |__________________________________*/
    function _activateNextToken(address nextToken) internal returns (uint256) {
        IERC20 token = IERC20(nextToken);
        token.approve(address(lendingPool), type(uint256).max);
        token = token;
        (address aTokenAddress, , ) =
            dataProvider.getReserveTokensAddresses(address(token));
        IERC20 _aToken = IERC20(aTokenAddress);
        aToken = _aToken;
    }

    function _addBalanceToLendingPool() internal {
        IERC20 token = IERC20(token);
        uint256 balance = token.balanceOf(address(this));

        // Aave Deposit
        lendingPool.deposit(
            address(token),
            balance,
            address(this),
            referralCode
        );
    }

    function _withdrawShareFromLendingPool(uint256 _withdraw) internal {
        uint256 balanceAToken = vaultBalance();
        lendingPool.withdraw(address(token), _withdraw, address(this));
    }

    function _swapAssetForCurrentToken(address asset, uint256 amount)
        internal
        returns (uint256)
    {
        IERC20 token = IERC20(asset);

        // Transfer asset from user to the StableYield vault.
        token.transferFrom(msg.sender, address(this), amount);

        // Curve : Identify pool and swap incoming asset for token.
        address pool = curveRegistry.find_pool_for_coins(asset, address(token));
        (uint256 token_supply, uint256 token_return, ) =
            curveRegistry.get_coin_indices(pool, asset, address(token));
        uint256 min_amount = 0x0;
        token.approve(pool, amount);
        _curveExchangeUnderling(
            pool,
            int128(token_supply),
            int128(token_return),
            amount,
            min_amount
        );
        return token.balanceOf(address(this));
    }

    function _depositCollateral(uint256 _amount, bool withSwap)
        internal
        returns (uint256)
    {
        uint256 _pool = vaultBalance();
        if (!withSwap) {
            token.safeTransferFrom(msg.sender, address(this), _amount);
        }
        uint256 shares = 0;
        if (totalSupply() == 0) {
            shares = _amount;
        } else {
            shares = (_amount.mul(totalSupply())).div(_pool);
        }
        _mint(msg.sender, shares);
        return shares;
    }

    /***********************************|
    |     		General Views           |
    |__________________________________*/
    function calculateShare(address user) public view returns (uint256) {
        if (totalSupply() > 0) {
            return balanceOf(user).mul(1e18).div(totalSupply());
        } else {
            return 0;
        }
    }

    function getPricePerFullShare() public view returns (uint256) {
        if (totalSupply() > 0) {
            return vaultBalance().mul(1e18).div(totalSupply());
        } else {
            return 0;
        }
    }

    function vaultBalance() public view returns (uint256) {
        return aToken.balanceOf(address(this));
    }

    function vaultBalance(address asset) public view returns (uint256) {
        return IERC20(asset).balanceOf(address(this));
    }

    function vaultReserves() public view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function aTokenAddress() public view returns (address) {
        return address(aToken);
    }

    /***********************************|
    |     	   Governance Public        |
    |__________________________________*/
    function stakeShares(uint256 amount) public {
        require(availableShares(msg.sender) >= amount, "stake-exceeds-balance");
        _stake(amount);
        emit SharesStaked(msg.sender, amount);
    }

    function _stake(uint256 amount) internal {
        _lockedTotal = _lockedTotal.add(amount);
        _lockedBalances[msg.sender] = _lockedBalances[msg.sender].add(amount);
        // ERC20.transferFrom(msg.sender, address(this), amount);
    }

    function unlockShares(uint256 amount) public {
        Member storage member = members[msg.sender];
        require(
            canWithdrawShares(member.highestIndexYesVote),
            "share-unlock-unavailable"
        );
        require(balanceOf(msg.sender).sub(lockedShares(msg.sender)) > amount);
        _unlockShares(amount);
        emit SharesUnlocked(msg.sender, amount);
    }

    function _unlockShares(uint256 amount) internal {
        _lockedTotal = _lockedTotal.sub(amount);
        _lockedBalances[msg.sender] = _lockedBalances[msg.sender].sub(amount);
        // ERC20.transfer(msg.sender, amount);
    }

    /**
     * @dev Submit Credit Delegation Proposal
     * @param _borrower Address of borrower to receive credit delegation
     * @param _delegationAsset Amount
     * @param _delegationAmount Amount
     * @param _details IPFS Hash
     */
    function submitProposal(
        address _borrower,
        uint256 _delegationAmount,
        address _delegationAsset,
        uint256 _interestAmount,
        uint256 _interestRateMode,
        string memory _details
    ) public {
        uint256 startingPeriod;
        // TODO : Add logic in rest of contract to handle sponsored smart contracts.
        if (processPaymentRequired) {
            require(
                IERC20(proposalSubmitToken).transferFrom(
                    msg.sender,
                    address(this),
                    0.1 ether
                ),
                "proposal-token-stake-failed"
            );
        }

        bool[4] memory flags; // [sponsored, processed, didPass, repaymentProcessed]
        Proposal memory proposal =
            Proposal({
                borrower: _borrower,
                proposer: msg.sender,
                sponsor: address(0),
                delegationAsset: _delegationAsset,
                delegationAmount: _delegationAmount,
                interestAmount: _interestAmount,
                interestRateMode: _interestRateMode,
                startingPeriod: 0,
                yesVotes: 0,
                yesCount: 0,
                noVotes: 0,
                flags: flags,
                details: _details
            });
        emit SubmitProposal(
            _borrower,
            msg.sender,
            proposalCount,
            _delegationAmount,
            _delegationAsset,
            _interestAmount,
            _interestRateMode,
            _details,
            startingPeriod
        );
        proposals[proposalCount] = proposal;
        proposalCount += 1;
    }

    function sponsorProposal(uint256 proposalId) public nonReentrant {
        require(balanceOf(msg.sender) > 0, "invalid-proposer");
        Proposal memory proposal = proposals[proposalId];

        require(
            proposal.proposer != address(0),
            "proposal must have been proposed"
        );
        require(!proposal.flags[0], "proposal has already been sponsored");

        uint256 startingPeriod =
            max(
                getCurrentPeriod(),
                proposalQueue.length == 0
                    ? 0
                    : proposals[proposalQueue[proposalQueue.length.sub(1)]]
                        .startingPeriod
            )
                .add(1);
        proposal.startingPeriod = startingPeriod;
        proposal.sponsor = msg.sender;
        proposal.flags[0] = true; // sponsored
        proposalQueue.push(proposalId);
        emit SponsorProposal(
            msg.sender,
            proposalId,
            proposalQueue.length.sub(1),
            startingPeriod
        );
    }

    /**
     * @dev Vote on Credit Delegation Proposal
     * @param _proposalIndex Address of borrower to receive credit delegation
     */
    function voteOnProposal(
        uint256 _sharesToStake,
        uint256 _proposalIndex,
        uint8 _vote
    ) public {
        require(
            availableShares(msg.sender) >= _sharesToStake,
            "stake-exceeds-balance"
        );

        _stake(_sharesToStake);

        require(
            _proposalIndex < proposalQueue.length,
            "proposal does not exist"
        );
        Proposal storage proposal = proposals[proposalQueue[_proposalIndex]];

        require(_vote < 3, "must be less than 3");
        Vote vote = Vote(_vote);

        require(
            getCurrentPeriod() >= proposal.startingPeriod,
            "voting period has not started"
        );
        require(
            !hasVotingPeriodExpired(proposal.startingPeriod),
            "proposal voting period has expired"
        );
        require(
            proposal.votesByMember[msg.sender] == Vote.Null,
            "member has already voted"
        );
        require(
            vote == Vote.Yes || vote == Vote.No,
            "vote must be either Yes or No"
        );

        proposal.votesByMember[msg.sender] = vote;

        if (vote == Vote.Yes) {
            proposal.yesVotes = proposal.yesVotes.add(_sharesToStake);
            proposal.yesCount += 1; // Track the number of individual votes. Regardless of share count.

            // set highest index (latest) yes vote - must be processed for member to ragequit
            Member storage member = members[msg.sender];
            if (_proposalIndex > member.highestIndexYesVote) {
                member.highestIndexYesVote = _proposalIndex;
            }
        } else if (vote == Vote.No) {
            proposal.noVotes = proposal.noVotes.add(_sharesToStake);
        }

        emit SubmitVote(
            proposalQueue[_proposalIndex],
            _proposalIndex,
            msg.sender,
            _vote,
            _sharesToStake
        );
    }

    /**
     * @dev Process Credit Delegation Proposal
     * @param _proposalIndex Address of borrower to receive credit delegation
     */
    function processProposal(uint256 _proposalIndex) public nonReentrant {
        _validateProposalForProcessing(_proposalIndex);

        uint256 proposalId = proposalQueue[_proposalIndex];
        Proposal storage proposal = proposals[proposalId];

        proposal.flags[1] = true; // processed
        bool didPass = _didPass(_proposalIndex);

        /*
         * TODO Add logic to redistribute locked shares
         * which exceeds the required collaterization ratio.
         */

        // PROPOSAL PASSED
        if (didPass) {
            proposal.flags[1] = true; // didPass

            Loan memory loan =
                Loan({
                    borrower: proposal.borrower,
                    asset: proposal.delegationAsset,
                    amount: proposal.delegationAmount,
                    totalLoansAtProcess: totalLoans[proposal.delegationAsset],
                    timestampIndex: 0, // FIX THIS TIMESTAMp
                    interest: proposal.interestAmount,
                    interestRateMode: proposal.interestRateMode,
                    repayed: 0,
                    withdrawn: 0,
                    proposalId: proposalId,
                    isActive: true
                });
            // PROPOSAL FAILED
        } else {
            proposal.flags[1] = false; // didNotPass
        }

        emit ProcessProposal(_proposalIndex, proposalId, didPass);
    }

    /**
     * @dev Withdraw amount from credit line.
     * @param _loanId Amount of asset to withdraw
     */
    function processLoanRepayment(uint256 _loanId) external {
        Loan storage loan = loans[_loanId];
        require(loan.isActive == false, "loan-active");
        Proposal storage proposal = proposals[loan.proposalId];

        // WARNING: GAS LIMIT may hit if number of yesCount is too HIGH.
        for (uint256 index = 0; index < proposal.yesCount; index++) {
            YesVoteData storage yesVoteData = proposal.yesVoteData[index];
            require(
                yesVoteData.repaymentProcessed == false,
                "process-loan-repayment-invalid"
            );
            _processLoanRepaymentShareDistribution(
                yesVoteData.user,
                yesVoteData.sharesLocked,
                proposal.delegationAmount,
                loan.repayed
            );
            yesVoteData.repaymentProcessed = true;
        }
    }

    /**
     * @dev Process personal loan repayment shares minting.
     * @param _loanId Identification number of loan
     * @param _votePosition Index of vote cast
     */
    function processLoanRepaymentPersonal(
        uint256 _loanId,
        uint256 _votePosition
    ) external {
        Loan storage loan = loans[_loanId];
        require(loan.isActive == false, "loan-active");
        Proposal storage proposal = proposals[loan.proposalId];
        YesVoteData storage yesVoteData = proposal.yesVoteData[_votePosition];
        require(yesVoteData.user == msg.sender, "invalid-vote-position");
        require(
            yesVoteData.repaymentProcessed == false,
            "process-loan-repayment-invalid"
        );
        _processLoanRepaymentShareDistribution(
            yesVoteData.user,
            yesVoteData.sharesLocked,
            proposal.delegationAmount,
            loan.repayed
        );
        yesVoteData.repaymentProcessed = true;
    }

    function _processLoanRepaymentShareDistribution(
        address _member,
        uint256 _sharesDeposited,
        uint256 _loanAmount,
        uint256 _repayment
    ) internal {
        uint256 sharesToMint =
            _sharesDeposited.div(_loanAmount).mul(_repayment);
        _mint(msg.sender, sharesToMint);
        emit ProcessLoanRepayment(_member, _sharesDeposited, sharesToMint);
    }

    /****************************************|
    |            Borrower Functions          |
    |_______________________________________*/

    /**
     * @dev Withdraw amount from credit line.
     * @param _amount Amount of asset to withdraw
     */
    function withdrawCredit(uint256 _amount, uint256 _loanId)
        public
        isBorrower
    {
        Loan memory loan = loans[_loanId];
        require(loan.borrower == msg.sender, "invalid-loan-borrower");

        require(
            _amount.add(loan.withdrawn) <= loan.amount,
            "exceeds-borrow-limit"
        );

        // Borrow asset from Aave LendingPool
        lendingPool.borrow(
            loan.asset,
            _amount,
            loan.interestRateMode,
            referralCode,
            address(this)
        );

        // Transfer asset to borrower.
        IERC20 token = IERC20(loan.asset);
        token.transfer(msg.sender, _amount);
        loan.withdrawn = loan.withdrawn.add(_amount);

        emit CreditWithdraw(msg.sender, _amount, _loanId);
    }

    /**
     * @dev Repay debt to lender. Anyone can repay debt.
     * @param _amount Amount of asset to withdraw
     */
    function repayCredit(
        uint256 _amount,
        address _onBehalfOf,
        uint256 _loanId
    ) public {
        Loan storage loan = loans[_loanId];

        // Transfer asset to borrower.
        IERC20 token = IERC20(loan.asset);
        token.transferFrom(msg.sender, address(this), _amount);
        loan.repayed = loan.repayed.add(_amount);

        emit CreditRepay(_onBehalfOf, msg.sender, _amount, _loanId);
    }

    /***********************************|
    |     		   Internal             |
    |__________________________________*/

    function max(uint256 x, uint256 y) internal pure returns (uint256) {
        return x >= y ? x : y;
    }

    function _didPass(uint256 proposalIndex) internal returns (bool didPass) {
        Proposal memory proposal = proposals[proposalQueue[proposalIndex]];

        didPass = proposal.yesVotes > proposal.noVotes;

        // Votes must exceed 140% of delegation amount to ensure safe HEALTH FACTOR
        if (proposal.yesVotes.mul(7).div(5) < proposal.delegationAmount) {
            didPass = false;
        }

        return didPass;
    }

    function _validateProposalForProcessing(uint256 proposalIndex)
        internal
        view
    {
        require(
            proposalIndex < proposalQueue.length,
            "proposal does not exist"
        );
        Proposal memory proposal = proposals[proposalQueue[proposalIndex]];

        require(
            getCurrentPeriod() >=
                proposal.startingPeriod.add(votingPeriodLength).add(
                    gracePeriodLength
                ),
            "proposal is not ready to be processed"
        );
        require(
            proposal.flags[0] == false,
            "proposal has already been processed"
        );
        require(
            proposalIndex == 0 ||
                proposals[proposalQueue[proposalIndex.sub(1)]].flags[0],
            "previous proposal must be processed"
        );
    }

    /***********************************|
    |     		Governance Views        |
    |__________________________________*/

    function availableShares(address account) public view returns (uint256) {
        return _balances[account].sub(_lockedBalances[account]);
    }

    function lockedShares(address account) public view returns (uint256) {
        return _lockedBalances[account];
    }

    function totalLockedShares() public view returns (uint256) {
        return _lockedTotal;
    }

    function totalToLend() public view returns (uint256) {
        return _lockedTotal.mul(2).div(3);
    }

    function getStableDebtResponsibleFor(uint256 timestampIndex)
        public
        view
        returns (uint256 amount)
    {
        uint256 amount;
        for (
            timestampIndex;
            timestampIndex < timestampIndexQueue.length;
            timestampIndex++
        ) {
            DebtUpdate storage debtUpdate = stableTokenDebt[timestampIndex];
            if (debtUpdate.updateType) {
                amount.add(debtUpdate.amount);
            } else {
                amount.sub(debtUpdate.amount);
            }
        }

        return amount;
    }

    function getPrincipalBalance(address asset)
        public
        view
        returns (uint256 stableDebt, uint256 variableDebt)
    {
        (
            address aTokenAddress,
            address stableDebtToken,
            address variableDebtToken
        ) = dataProvider.getReserveTokensAddresses(address(token));
        IDebtToken tokenStable = IDebtToken(stableDebtToken);
        IDebtToken tokenVariable = IDebtToken(variableDebtToken);
        return (
            tokenStable.balanceOf(address(this)),
            tokenVariable.balanceOf(address(this))
        );
    }

    function getPrincipalBalanceStable(address asset)
        public
        view
        returns (uint256 stableDebt)
    {
        (, address stableDebtToken, ) =
            dataProvider.getReserveTokensAddresses(address(token));
        IDebtToken tokenStable = IDebtToken(stableDebtToken);
        return tokenStable.balanceOf(address(this));
    }

    function getPrincipalBalanceVariable(address asset)
        public
        view
        returns (uint256 variableDebt)
    {
        (, , address variableDebtToken) =
            dataProvider.getReserveTokensAddresses(address(token));
        IDebtToken tokenVariable = IDebtToken(variableDebtToken);
        return tokenVariable.balanceOf(address(this));
    }

    function getLoanDebt(uint256 loanId) public view returns (uint256 debt) {
        Loan storage loan = loans[loanId];
        uint256 debtToken = getPrincipalBalanceVariable(loan.asset);
        uint256 debtAccrued =
            totalLoans[loan.asset].sub(loan.totalLoansAtProcess);
        uint256 debtAccruedPercentage = debtAccrued.div(totalLoans[loan.asset]);
        return
            debtAccrued.mul(debtAccruedPercentage.mul(debtToken)).add(
                loan.interest
            );
        // return debt.add(loan.interest);
    }

    // can only withdrawShares if the latest proposal you voted YES on has been processed
    function canWithdrawShares(uint256 highestIndexYesVote)
        public
        view
        returns (bool)
    {
        require(
            highestIndexYesVote < proposalQueue.length,
            "proposal does not exist"
        );
        return proposals[proposalQueue[highestIndexYesVote]].flags[0];
    }

    function getCurrentPeriod() public view returns (uint256) {
        return now.sub(creationTime).div(periodDuration);
    }

    function hasVotingPeriodExpired(uint256 startingPeriod)
        public
        view
        returns (bool)
    {
        return getCurrentPeriod() >= startingPeriod.add(votingPeriodLength);
    }

    function getProposalQueueLength() public view returns (uint256) {
        return proposalQueue.length;
    }

    function getProposalFlags(uint256 proposalId)
        public
        view
        returns (bool[4] memory)
    {
        return proposals[proposalId].flags;
    }

    function getProposal(uint256 proposalId)
        public
        view
        returns (
            address borrower,
            address delegationAsset,
            uint256 delegationAmount,
            uint256 interestAmount,
            uint256 interestRateMode,
            uint256 yesVotes,
            uint256 noVotes,
            uint256 yesCount
        )
    {
        Proposal storage proposal = proposals[proposalId];
        return (
            proposal.borrower,
            proposal.delegationAsset,
            proposal.delegationAmount,
            proposal.interestAmount,
            proposal.interestRateMode,
            proposal.yesVotes,
            proposal.noVotes,
            proposal.yesCount
        );
    }

    function getMemberProposalVote(address memberAddress, uint256 proposalIndex)
        public
        view
        returns (Vote)
    {
        require(members[memberAddress].exists, "member does not exist");
        require(
            proposalIndex < proposalQueue.length,
            "proposal does not exist"
        );
        return
            proposals[proposalQueue[proposalIndex]].votesByMember[
                memberAddress
            ];
    }

    /***********************************|
    |        External Functions         |
    |__________________________________*/
    function _curveExchangeUnderling(
        address pool,
        int128 token_supply,
        int128 token_return,
        uint256 amount,
        uint256 min_amount
    ) internal {
        IStableSwap pool = IStableSwap(pool);
        pool.exchange_underlying(
            token_supply,
            token_return,
            amount,
            min_amount
        );
        emit AssetSwap(
            token_supply,
            token_return,
            amount,
            min_amount,
            address(pool)
        );
    }
}

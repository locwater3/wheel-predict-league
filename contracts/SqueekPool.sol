// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @title SqueekPool — Wheel Predict League SQK pool mode (Sepolia testnet)
/// @notice Parimutuel RUN/NAP pools per Squeekchain round, staked in SQK.
///         Players bet SQK on whether Squeektoshi runs (work > 0) or naps
///         (work == 0) in a given 10-minute Squeekchain round. After the
///         round settles on Squeekchain, the settler records the real result
///         and winners claim a proportional share of the whole pool (minus a
///         small fee). If one side of a round is empty there is nothing to
///         win or lose: every stake is refunded in full, with no fee.
///
/// @dev    Settlement model (v1, testnet): the contract owner acts as the
///         settler and submits the round's real work/blocks exactly as
///         published by the public Squeekchain API / SqueekCore settlements
///         (each settlement carries an on-chain transaction hash anyone can
///         audit). This is a trusted-settler demo on testnet SQK, which has
///         no real-world value; it is NOT a trustless oracle.

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract SqueekPool {
    enum Side { Nap, Run }

    struct Round {
        bool exists;
        bool settled;
        bool cancelled;      // one-sided or empty round: full refunds
        bool outcomeRun;     // meaningful only when settled && !cancelled
        uint256 work;        // real work recorded at settlement
        uint256 blocks;      // real completed blocks recorded at settlement
        uint256 totalNap;
        uint256 totalRun;
        uint256 feeTaken;
    }

    struct Bet {
        uint256 amount;
        Side side;
        bool hasBet;
        bool claimed;
    }

    IERC20 public immutable sqk;
    address public owner;
    address public feeRecipient;
    uint256 public feeBps;            // fee on the total pool, in basis points (200 = 2%)
    uint256 public constant MAX_FEE_BPS = 1000;

    mapping(uint256 => Round) public rounds;
    mapping(uint256 => mapping(address => Bet)) public bets;

    bool private _locked;
    modifier nonReentrant() {
        require(!_locked, "reentrant");
        _locked = true;
        _;
        _locked = false;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "not owner");
        _;
    }

    event RoundOpened(uint256 indexed round);
    event BetPlaced(uint256 indexed round, address indexed player, Side side, uint256 amount);
    event RoundSettled(uint256 indexed round, uint256 work, uint256 blocks, bool outcomeRun, bool cancelled, uint256 feeTaken);
    event Claimed(uint256 indexed round, address indexed player, uint256 payout);
    event Refunded(uint256 indexed round, address indexed player, uint256 amount);
    event FeeUpdated(uint256 feeBps);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor(address sqkToken, uint256 feeBps_) {
        require(sqkToken != address(0), "zero token");
        require(feeBps_ <= MAX_FEE_BPS, "fee too high");
        sqk = IERC20(sqkToken);
        owner = msg.sender;
        feeRecipient = msg.sender;
        feeBps = feeBps_;
    }

    // ---------- owner / settler ----------

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "zero owner");
        emit OwnershipTransferred(owner, newOwner);
        owner = newOwner;
    }

    function setFeeBps(uint256 feeBps_) external onlyOwner {
        require(feeBps_ <= MAX_FEE_BPS, "fee too high");
        feeBps = feeBps_;
        emit FeeUpdated(feeBps_);
    }

    function setFeeRecipient(address recipient) external onlyOwner {
        require(recipient != address(0), "zero recipient");
        feeRecipient = recipient;
    }

    /// @notice Open a Squeekchain round for betting. One round at a time is
    ///         the intended flow, but the contract does not restrict how
    ///         many rounds are open.
    function openRound(uint256 round) external onlyOwner {
        require(!rounds[round].exists, "round exists");
        rounds[round].exists = true;
        emit RoundOpened(round);
    }

    /// @notice Record the real settlement of a round and close betting.
    /// @param work   Real workAdded for the round (0 = the hamster napped).
    /// @param blocks Real completedBlockCount for the round.
    function settleRound(uint256 round, uint256 work, uint256 blocks) external onlyOwner {
        Round storage r = rounds[round];
        require(r.exists, "no round");
        require(!r.settled, "already settled");
        r.settled = true;
        r.work = work;
        r.blocks = blocks;
        r.outcomeRun = work > 0;
        if (r.totalNap == 0 || r.totalRun == 0) {
            // Nobody to win against (or nobody bet): cancel, refund everyone.
            r.cancelled = true;
        } else {
            uint256 total = r.totalNap + r.totalRun;
            r.feeTaken = (total * feeBps) / 10_000;
            if (r.feeTaken > 0) {
                require(sqk.transfer(feeRecipient, r.feeTaken), "fee transfer failed");
            }
        }
        emit RoundSettled(round, work, blocks, r.outcomeRun, r.cancelled, r.feeTaken);
    }

    // ---------- player ----------

    /// @notice Bet SQK on one side of an open round. A player may add to
    ///         their stake on the same side, but cannot bet both sides.
    ///         Requires a prior SQK approve() to this contract.
    function bet(uint256 round, Side side, uint256 amount) external nonReentrant {
        Round storage r = rounds[round];
        require(r.exists, "no round");
        require(!r.settled, "round settled");
        require(amount > 0, "zero amount");
        Bet storage b = bets[round][msg.sender];
        if (b.hasBet) {
            require(b.side == side, "cannot bet both sides");
            b.amount += amount;
        } else {
            b.hasBet = true;
            b.side = side;
            b.amount = amount;
        }
        if (side == Side.Run) r.totalRun += amount; else r.totalNap += amount;
        require(sqk.transferFrom(msg.sender, address(this), amount), "transfer failed");
        emit BetPlaced(round, msg.sender, side, amount);
    }

    /// @notice What the caller can take out of a round right now:
    ///         their winnings if they backed the winning side of a settled
    ///         round, or their full stake if the round was cancelled.
    function claimable(uint256 round, address player) public view returns (uint256) {
        Round storage r = rounds[round];
        Bet storage b = bets[round][player];
        if (!b.hasBet || b.claimed || !r.settled) return 0;
        if (r.cancelled) return b.amount;
        bool won = (b.side == Side.Run) == r.outcomeRun;
        if (!won) return 0;
        uint256 total = r.totalNap + r.totalRun;
        uint256 winPool = r.outcomeRun ? r.totalRun : r.totalNap;
        return (b.amount * (total - r.feeTaken)) / winPool;
    }

    /// @notice Claim winnings (or a full refund for a cancelled round).
    function claim(uint256 round) external nonReentrant {
        uint256 payout = claimable(round, msg.sender);
        require(payout > 0, "nothing to claim");
        bets[round][msg.sender].claimed = true;
        require(sqk.transfer(msg.sender, payout), "payout failed");
        Round storage r = rounds[round];
        if (r.cancelled) emit Refunded(round, msg.sender, payout);
        else emit Claimed(round, msg.sender, payout);
    }

    // ---------- views ----------

    function roundInfo(uint256 round)
        external
        view
        returns (bool exists, bool settled, bool cancelled, bool outcomeRun, uint256 work, uint256 blocks, uint256 totalNap, uint256 totalRun)
    {
        Round storage r = rounds[round];
        return (r.exists, r.settled, r.cancelled, r.outcomeRun, r.work, r.blocks, r.totalNap, r.totalRun);
    }

    function myBet(uint256 round, address player)
        external
        view
        returns (uint256 amount, Side side, bool hasBet, bool claimed)
    {
        Bet storage b = bets[round][player];
        return (b.amount, b.side, b.hasBet, b.claimed);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./contracts/shared/ITicket.sol";
import "./contracts/shared/IFund.sol";

contract Fund is IFund {
    // -----------------------
    // ReentrancyGuard (lightweight)
    // -----------------------
    uint256 private _locked = 1;
    modifier nonReentrant() {
        require(_locked == 1, "REENTRANCY");
        _locked = 2;
        _;
        _locked = 1;
    }

    // -----------------------
    // Errors
    // -----------------------
    error NotAdmin();
    error NotOrganizer();
    error EventNotFound();
    error BadParam();
    error NotFunding();
    error FundingClosed();
    error NotFunded();
    error NotTicketing();
    error NotCompleted();
    error AlreadyFinalized();
    error Unsafe();
    error TicketContractNotSet();
    error OnlyTicketContract();
    error NothingToClaim();
    error RefundsNotEnabled();
    error TransferFailed();
    error InsufficientRefundPool();
    error ExceedsMaxTickets();
    error ShareLocked();

    // -----------------------
    // Constants
    // -----------------------
    address public immutable admin;
    uint256 public constant PLATFORM_FEE_BPS = 500; // 5%
    uint256 public constant BPS_DENOM = 10_000;

    // -----------------------
    // External contracts
    // -----------------------
    ITicket public ticket;

    // -----------------------
    // Storage
    // -----------------------
    struct EventConfig {
        address organizer;

        // Funding
        uint256 fundingGoal;
        uint256 currentFunding;
        uint256 fundingDeadline;
        uint256 minStakeRequired;
        uint256 organizerStakeLocked;

        // Ticket params (Ticket.sol handles sales)
        uint256 ticketPrice;
        uint256 maxTickets;

        // Completion threshold (based on Ticket.sol used count)
        uint256 usedThreshold; // number of used tickets required to mark Completed

        // Pools
        uint256 refundPool;
        bool refundsEnabled;

        // Revenue distribution
        uint256 organizerShareBps;
        bool sharesFinalized;
        bool revenueReleased;

        // Shares (internal)
        uint256 totalShares;
        mapping(address => uint256) shareOf;

        // Rewards accounting
        uint256 accRewardPerShare; // scaled by 1e18
        mapping(address => uint256) rewardDebt;
        mapping(address => uint256) pending;

        // Status
        EventStatus status;

        // Ticket mint tracking (optional but helpful)
        uint256 totalMinted;
    }

    uint256 public nextEventId = 1;
    mapping(uint256 => EventConfig) private events_;

    // -----------------------
    // Events
    // -----------------------
    event TicketContractSet(address ticket);
    event EventCreated(
        uint256 indexed eventId,
        address indexed organizer,
        uint256 stakeAmount,
        uint256 minStakeRequired,
        uint256 fundingGoal,
        uint256 fundingDeadline,
        uint256 organizerShareBps,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 usedThreshold
    );

    event ContributionMade(uint256 indexed eventId, address indexed donator, uint256 amount);
    event SharesIssued(uint256 indexed eventId, address indexed donator, uint256 sharesMinted);

    event FundingSuccessful(uint256 indexed eventId);
    event FundingFinalized(uint256 indexed eventId, uint256 totalShares);

    event TicketingStarted(uint256 indexed eventId, uint256 mintedQty, uint8 ticketType);
    event Completed(uint256 indexed eventId, uint256 usedTickets);

    event RevenueReleased(
        uint256 indexed eventId,
        uint256 totalRevenue,
        uint256 platformFee,
        uint256 organizerShare,
        uint256 donatorPool,
        uint256 newAccRewardPerShare
    );

    event RewardClaimed(uint256 indexed eventId, address indexed donator, uint256 amount);

    event RefundsEnabled(uint256 indexed eventId, uint256 refundPoolAmount);
    event TicketRefundPaid(uint256 indexed eventId, uint256 indexed tokenId, address indexed to, uint256 amount);

    event PenaltyApplied(uint256 indexed eventId, uint256 amount, uint256 penaltyBps, PenaltyReason reason);

    // -----------------------
    // Constructor / Modifiers
    // -----------------------
    constructor() {
        admin = msg.sender;
    }

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAdmin();
        _;
    }

    modifier onlyOrganizer(uint256 eventId) {
        EventConfig storage e = _mustGet(eventId);
        if (msg.sender != e.organizer) revert NotOrganizer();
        _;
    }

    modifier onlyTicket() {
        if (address(ticket) == address(0)) revert TicketContractNotSet();
        if (msg.sender != address(ticket)) revert OnlyTicketContract();
        _;
    }

    // -----------------------
    // Admin setup
    // -----------------------
    function setTicketContract(address ticketAddr) external onlyAdmin {
        if (ticketAddr == address(0)) revert BadParam();
        ticket = ITicket(ticketAddr);
        emit TicketContractSet(ticketAddr);
    }

    // -----------------------
    // Views
    // -----------------------
    function pendingReward(uint256 eventId, address user) external view returns (uint256) {
        EventConfig storage e = _mustGet(eventId);
        uint256 shares = e.shareOf[user];
        uint256 accumulated = (shares * e.accRewardPerShare) / 1e18;
        uint256 debt = e.rewardDebt[user];
        uint256 p = e.pending[user];
        if (accumulated > debt) p += (accumulated - debt);
        return p;
    }

    // -----------------------
    // createEvent() with stake requirement
    // -----------------------
    function createEvent(
        uint256 fundingGoal,
        uint256 fundingDeadline,
        uint256 minStakeRequired,
        uint256 organizerShareBps,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 usedThreshold
    ) external payable returns (uint256 eventId) {
        if (fundingGoal == 0) revert BadParam();
        if (fundingDeadline == 0 || fundingDeadline <= block.timestamp) revert BadParam();
        if (minStakeRequired == 0) revert BadParam();
        if (msg.value < minStakeRequired) revert BadParam();
        if (organizerShareBps > BPS_DENOM) revert BadParam();
        if (ticketPrice == 0 || maxTickets == 0) revert BadParam();
        if (usedThreshold == 0 || usedThreshold > maxTickets) revert BadParam();

        eventId = nextEventId++;
        EventConfig storage e = events_[eventId];

        e.organizer = msg.sender;
        e.fundingGoal = fundingGoal;
        e.fundingDeadline = fundingDeadline;
        e.minStakeRequired = minStakeRequired;
        e.organizerStakeLocked = msg.value;

        e.organizerShareBps = organizerShareBps;
        e.ticketPrice = ticketPrice;
        e.maxTickets = maxTickets;
        e.usedThreshold = usedThreshold;

        e.status = EventStatus.Funding;

        emit EventCreated(
            eventId,
            msg.sender,
            msg.value,
            minStakeRequired,
            fundingGoal,
            fundingDeadline,
            organizerShareBps,
            ticketPrice,
            maxTickets,
            usedThreshold
        );
    }

    // -----------------------
    // contribute() with share minting
    // -----------------------
    function contribute(uint256 eventId) external payable {
        EventConfig storage e = _mustGet(eventId);

        if (e.status != EventStatus.Funding) revert NotFunding();
        if (block.timestamp > e.fundingDeadline) revert FundingClosed();
        if (e.sharesFinalized) revert ShareLocked();
        if (msg.value == 0) revert BadParam();

        _updateUser(e, msg.sender);

        uint256 shares = msg.value; // 1 wei = 1 share
        e.shareOf[msg.sender] += shares;
        e.totalShares += shares;
        e.currentFunding += msg.value;

        emit ContributionMade(eventId, msg.sender, msg.value);
        emit SharesIssued(eventId, msg.sender, shares);

        if (e.currentFunding >= e.fundingGoal) {
            e.status = EventStatus.Funded;
            emit FundingSuccessful(eventId);
        }
    }

    // -----------------------
    // finalizeFunding() FIX:
    // - chỉ organizer hoặc admin gọi
    // - gọi trước deadline => phải đạt goal (Funded)
    // - gọi sau deadline => nếu chưa đạt goal => Cancelled
    // -----------------------
    function finalizeFunding(uint256 eventId) external {
        EventConfig storage e = _mustGet(eventId);

        if (msg.sender != e.organizer && msg.sender != admin) revert NotAdmin();
        if (e.sharesFinalized) revert AlreadyFinalized();

        bool afterDeadline = block.timestamp > e.fundingDeadline;

        if (!afterDeadline) {
            if (e.status != EventStatus.Funded) revert Unsafe();
        } else {
            if (e.status != EventStatus.Funded) {
                e.status = EventStatus.Cancelled;
            }
        }

        e.sharesFinalized = true;
        emit FundingFinalized(eventId, e.totalShares);
    }

    // -----------------------
    // startTicketing() NEW:
    // - chỉ organizer gọi
    // - sau khi Funded + sharesFinalized
    // - mint vé thông qua Ticket.sol (Fund KHÔNG tự bán)
    // -----------------------
    function startTicketing(
        uint256 eventId,
        uint8 ticketType,
        uint256 quantity
    ) external onlyOrganizer(eventId) returns (uint256[] memory tokenIds) {
        EventConfig storage e = _mustGet(eventId);
        if (address(ticket) == address(0)) revert TicketContractNotSet();

        if (e.status != EventStatus.Funded) revert NotFunded();
        if (!e.sharesFinalized) revert Unsafe();
        if (quantity == 0) revert BadParam();

        // đảm bảo không mint vượt maxTickets
        if (e.totalMinted + quantity > e.maxTickets) revert ExceedsMaxTickets();

        // mintBatch(to=organizer, eventId, price, type, qty)
        tokenIds = ticket.mintBatch(
            e.organizer,
            eventId,
            e.ticketPrice,
            ITicket.TicketType(ticketType),
            quantity
        );

        e.totalMinted += quantity;
        e.status = EventStatus.Ticketing;

        emit TicketingStarted(eventId, quantity, ticketType);
    }

    // -----------------------
    // Completed logic NEW:
    // - chỉ organizer gọi
    // - kiểm tra usedThreshold từ Ticket.sol (getUsageStats)
    // -----------------------
    function setCompletedIfThresholdMet(uint256 eventId) external onlyOrganizer(eventId) {
        EventConfig storage e = _mustGet(eventId);
        if (address(ticket) == address(0)) revert TicketContractNotSet();
        if (e.status != EventStatus.Ticketing) revert NotTicketing();

        (, , uint256 totalUsed, ) = ticket.getUsageStats(eventId);
        if (totalUsed < e.usedThreshold) revert Unsafe();

        e.status = EventStatus.Completed;
        emit Completed(eventId, totalUsed);
    }

    // -----------------------
    // releaseRevenue() distribution
    // - chỉ organizer
    // - chỉ khi Completed
    // - revenue lấy từ Ticket.sol: getTotalRevenue(eventId)
    // -----------------------
    function releaseRevenue(uint256 eventId) external nonReentrant onlyOrganizer(eventId) {
        EventConfig storage e = _mustGet(eventId);
        if (address(ticket) == address(0)) revert TicketContractNotSet();
        if (!e.sharesFinalized) revert Unsafe();
        if (e.revenueReleased) revert AlreadyFinalized();
        if (e.status != EventStatus.Completed) revert NotCompleted();
        if (e.totalShares == 0) revert BadParam();
        if (e.refundsEnabled) revert Unsafe();

        uint256 totalRevenue = ticket.getTotalRevenue(eventId);
        if (totalRevenue == 0) revert BadParam();

        e.revenueReleased = true;

        uint256 platformFee = (totalRevenue * PLATFORM_FEE_BPS) / BPS_DENOM;
        uint256 afterFee = totalRevenue - platformFee;

        uint256 organizerShare = (afterFee * e.organizerShareBps) / BPS_DENOM;
        uint256 donatorPool = afterFee - organizerShare;

        if (platformFee > 0) {
            (bool okFee, ) = admin.call{value: platformFee}("");
            if (!okFee) revert TransferFailed();
        }
        if (organizerShare > 0) {
            (bool okOrg, ) = e.organizer.call{value: organizerShare}("");
            if (!okOrg) revert TransferFailed();
        }

        e.accRewardPerShare += (donatorPool * 1e18) / e.totalShares;

        emit RevenueReleased(eventId, totalRevenue, platformFee, organizerShare, donatorPool, e.accRewardPerShare);
    }

    function claimReward(uint256 eventId) external nonReentrant {
        EventConfig storage e = _mustGet(eventId);
        _updateUser(e, msg.sender);

        uint256 amt = e.pending[msg.sender];
        if (amt == 0) revert NothingToClaim();

        e.pending[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: amt}("");
        if (!ok) revert TransferFailed();

        emit RewardClaimed(eventId, msg.sender, amt);
    }

    // -----------------------
    // refundTickets() enable refund mode
    // (admin hoặc organizer)
    // -----------------------
    function refundTickets(uint256 eventId) external {
        EventConfig storage e = _mustGet(eventId);
        if (msg.sender != admin && msg.sender != e.organizer) revert NotAdmin();

        e.refundsEnabled = true;
        emit RefundsEnabled(eventId, e.refundPool);
    }

    // -----------------------
    // claimTicketRefund() - CALLED BY Ticket.sol
    // Ticket.sol phải validate:
    // - tokenId thuộc eventId
    // - owner đúng
    // - status Sold/Refundable
    // rồi gọi Fund để payout, sau đó Ticket.sol markAsRefunded(tokenId)
    // -----------------------
    function claimTicketRefund(uint256 eventId, uint256 tokenId, address to)
        external
        nonReentrant
        onlyTicket
    {
        EventConfig storage e = _mustGet(eventId);
        if (!e.refundsEnabled) revert RefundsNotEnabled();
        if (to == address(0)) revert BadParam();

        uint256 amount = e.ticketPrice;
        if (amount > e.refundPool) revert InsufficientRefundPool();

        e.refundPool -= amount;

        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit TicketRefundPaid(eventId, tokenId, to, amount);
    }

    // -----------------------
    // applyPenalty() admin slashes stake -> refundPool
    // -----------------------
    function applyPenalty(uint256 eventId, uint256 penaltyBps, PenaltyReason reason) external onlyAdmin {
        EventConfig storage e = _mustGet(eventId);
        if (penaltyBps > BPS_DENOM) revert BadParam();

        uint256 amount = (e.organizerStakeLocked * penaltyBps) / BPS_DENOM;
        if (amount == 0) revert BadParam();

        e.organizerStakeLocked -= amount;
        e.refundPool += amount;

        emit PenaltyApplied(eventId, amount, penaltyBps, reason);
    }

    // -----------------------
    // Internal reward accounting
    // -----------------------
    function _updateUser(EventConfig storage e, address user) internal {
        uint256 shares = e.shareOf[user];
        uint256 accumulated = (shares * e.accRewardPerShare) / 1e18;
        uint256 debt = e.rewardDebt[user];

        if (accumulated > debt) {
            e.pending[user] += (accumulated - debt);
        }
        e.rewardDebt[user] = accumulated;
    }

    function _mustGet(uint256 eventId) internal view returns (EventConfig storage e) {
        e = events_[eventId];
        if (e.status == EventStatus.None) revert EventNotFound();
    }

    receive() external payable {}
}

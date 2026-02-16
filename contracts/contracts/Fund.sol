// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./shared/ITicket.sol";
import "./shared/IFund.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Fund
 * @notice Quản lý funding + reward chia doanh thu + refund pool cho từng event.
 *         Ticket SALE phải nằm ở Ticket.sol (Fund KHÔNG có hàm mua ticket).
 *
 * Flow:
 *  1) organizer createEvent() + stake
 *  2) donators contribute() => mint shares (1 wei = 1 share)
 *  3) finalizeFunding():
 *      - trước deadline: chỉ cho finalize nếu đạt goal (status Funded)
 *      - sau deadline : nếu chưa đạt goal => Cancelled, nếu đạt => giữ Funded
 *  4) startTicketing(): chỉ organizer, chỉ sau Funded + sharesFinalized, gọi Ticket.sol mintBatch()
 *  5) setCompletedIfThresholdMet(): chỉ organizer, check totalUsed từ Ticket.sol >= usedThreshold
 *  6) releaseRevenue(): chỉ organizer, chỉ khi Completed, lấy revenue từ Ticket.sol và chia:
 *      platform fee -> admin, organizer share -> organizer, phần còn lại -> donatorPool
 *      donatorPool được ghi nhận qua accRewardPerShare
 *  7) claimReward(): donator claim reward
 *  8) refundTickets(): admin/organizer bật refund mode
 *  9) claimTicketRefund(): Ticket.sol gọi để payout refund theo tokenId
 * 10) applyPenalty(): admin slash stake của organizer => refundPool
 */
contract Fund is IFund, ReentrancyGuard {
    // -----------------------
    // Errors
    // -----------------------
    error NotAdmin();
    error NotOrganizer();
    error NotAuthorized(); // organizer OR admin
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

    // FIX: prevent funds getting stuck due to missing settlement paths.
    error NothingToWithdraw();

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

        // Stake requirement
        uint256 minStakeRequired;
        uint256 organizerStakeLocked;

        // Ticket params (Ticket.sol handles SALE)
        uint256 ticketPrice;
        uint256 maxTickets;

        // Completion threshold (based on Ticket.sol used count)
        uint256 usedThreshold;

        // Pools
        uint256 refundPool;
        bool refundsEnabled;

        // FIX (critical): track real escrowed revenue inside Fund per event.
        // Ticket.sol forwards ticket sale proceeds into Fund via depositTicketRevenue(eventId).
        uint256 escrowedRevenue;

        // Revenue distribution
        uint256 organizerShareBps;
        bool sharesFinalized;   // khóa contribute/mint shares
        bool revenueReleased;   // khóa releaseRevenue

        // Shares
        uint256 totalShares;
        mapping(address => uint256) shareOf;

        // Rewards accounting (MasterChef-like)
        uint256 accRewardPerShare; // scaled by 1e18
        mapping(address => uint256) rewardDebt;
        mapping(address => uint256) pending;

        // Status
        EventStatus status;

        // Ticket mint tracking
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
    event FundingFinalized(uint256 indexed eventId, uint256 totalShares, EventStatus statusAfterFinalize);

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

    // FIX: escrow deposit events for off-chain sync.
    event TicketRevenueDeposited(uint256 indexed eventId, address indexed from, uint256 amount, uint256 newEscrowedRevenue);

    // FIX: settlements to avoid locked funds.
    event ContributionRefunded(uint256 indexed eventId, address indexed donator, uint256 amount);
    event StakeWithdrawn(uint256 indexed eventId, address indexed organizer, uint256 amount);

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

    modifier onlyOrganizerOrAdmin(uint256 eventId) {
        EventConfig storage e = _mustGet(eventId);
        if (msg.sender != e.organizer && msg.sender != admin) revert NotAuthorized();
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
    // Escrow deposits
    // -----------------------
    function depositTicketRevenue(uint256 eventId) external payable onlyTicket {
        // FIX (critical): Ticket.sol forwards ETH into Fund to make releaseRevenue() possible.
        // We account per event to avoid cross-event balance contamination.
        if (msg.value == 0) revert BadParam();
        EventConfig storage e = _mustGet(eventId);

        e.escrowedRevenue += msg.value;
        emit TicketRevenueDeposited(eventId, msg.sender, msg.value, e.escrowedRevenue);
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

        // stake requirement
        if (minStakeRequired == 0) revert BadParam();
        if (msg.value < minStakeRequired) revert BadParam();

        // revenue split
        if (organizerShareBps > BPS_DENOM) revert BadParam();

        // ticket params
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

        // update reward before changing shares
        _updateUser(e, msg.sender);

        // 1 wei = 1 share
        uint256 shares = msg.value;
        e.shareOf[msg.sender] += shares;
        e.totalShares += shares;

        e.currentFunding += msg.value;

        emit ContributionMade(eventId, msg.sender, msg.value);
        emit SharesIssued(eventId, msg.sender, shares);

        // đạt goal => chuyển trạng thái Funded (nhưng CHƯA finalize shares)
        if (e.currentFunding >= e.fundingGoal) {
            e.status = EventStatus.Funded;
            emit FundingSuccessful(eventId);
        }
    }

    // -----------------------
    // finalizeFunding() FIX:
    // - chỉ organizer hoặc admin gọi
    // - gọi trước deadline => phải đạt goal (status Funded)
    // - gọi sau deadline  => nếu chưa đạt goal => Cancelled
    // - luôn lock shares sau finalize (không contribute thêm)
    // -----------------------
    function finalizeFunding(uint256 eventId) external onlyOrganizerOrAdmin(eventId) {
        EventConfig storage e = _mustGet(eventId);
        if (e.sharesFinalized) revert AlreadyFinalized();

        bool afterDeadline = block.timestamp > e.fundingDeadline;

        if (!afterDeadline) {
            // muốn finalize sớm => phải đủ goal
            if (e.status != EventStatus.Funded) revert Unsafe();
        } else {
            // sau deadline mà chưa đủ goal => Cancelled
            if (e.status != EventStatus.Funded) {
                e.status = EventStatus.Cancelled;
            }
        }

        e.sharesFinalized = true;
        emit FundingFinalized(eventId, e.totalShares, e.status);
    }

    // -----------------------
    // startTicketing() (manual) - organizer gọi
    // - chỉ sau khi Funded + sharesFinalized
    // - Fund không bán vé, chỉ mint vé qua Ticket.sol
    // -----------------------
    function startTicketing(
        uint256 eventId,
        uint8 ticketType,
        uint256 quantity
    ) external onlyOrganizer(eventId) returns (uint256[] memory tokenIds) {
        EventConfig storage e = _mustGet(eventId);
        if (address(ticket) == address(0)) revert TicketContractNotSet();

        // FIX: allow minting multiple batches after ticketing started.
        // Previously, status was set to Ticketing after first mint, making subsequent mints impossible.
        if (e.status != EventStatus.Funded && e.status != EventStatus.Ticketing) revert NotFunded();
        if (!e.sharesFinalized) revert Unsafe();

        if (quantity == 0) revert BadParam();

        // đảm bảo không mint vượt maxTickets
        if (e.totalMinted + quantity > e.maxTickets) revert ExceedsMaxTickets();

        // Ticket mintBatch(to, eventId, price, type, qty)
        tokenIds = ticket.mintBatch(
            e.organizer,
            eventId,
            e.ticketPrice,
            ITicket.TicketType(ticketType),
            quantity
        );

        e.totalMinted += quantity;

        if (e.status == EventStatus.Funded) {
            e.status = EventStatus.Ticketing;
        }

        emit TicketingStarted(eventId, quantity, ticketType);
    }

    // -----------------------
    // Completed logic (manual) - organizer gọi
    // - kiểm tra usedThreshold từ Ticket.sol (getUsageStats)
    // -----------------------
    function setCompletedIfThresholdMet(uint256 eventId) external onlyOrganizer(eventId) {
        EventConfig storage e = _mustGet(eventId);
        if (address(ticket) == address(0)) revert TicketContractNotSet();

        if (e.status != EventStatus.Ticketing) revert NotTicketing();

        // Ticket.sol trả usage stats, lấy totalUsed
        (, , uint256 totalUsed, ) = ticket.getUsageStats(eventId);

        // chưa đạt threshold => không cho Completed
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

        // Nếu đã bật refunds thì không được release revenue (tránh double-mode)
        if (e.refundsEnabled) revert Unsafe();

        // FIX (critical): do NOT use Ticket.getTotalRevenue() as the source of funds.
        // Real ETH is escrowed in Fund via depositTicketRevenue(eventId).
        uint256 totalRevenue = e.escrowedRevenue;
        if (totalRevenue == 0) revert BadParam();

        // consume escrow for this event so it cannot be released twice
        e.escrowedRevenue = 0;

        e.revenueReleased = true;

        // 1) platform fee
        uint256 platformFee = (totalRevenue * PLATFORM_FEE_BPS) / BPS_DENOM;
        uint256 afterFee = totalRevenue - platformFee;

        // 2) organizer share
        uint256 organizerShare = (afterFee * e.organizerShareBps) / BPS_DENOM;
        uint256 donatorPool = afterFee - organizerShare;

        // 3) payout fee + organizer
        if (platformFee > 0) {
            (bool okFee, ) = admin.call{value: platformFee}("");
            if (!okFee) revert TransferFailed();
        }
        if (organizerShare > 0) {
            (bool okOrg, ) = e.organizer.call{value: organizerShare}("");
            if (!okOrg) revert TransferFailed();
        }

        // 4) donator pool => accRewardPerShare
        e.accRewardPerShare += (donatorPool * 1e18) / e.totalShares;

        emit RevenueReleased(eventId, totalRevenue, platformFee, organizerShare, donatorPool, e.accRewardPerShare);
    }

    // -----------------------
    // claimReward() - donator claim reward theo shares
    // -----------------------
    function claimReward(uint256 eventId) external nonReentrant {
        EventConfig storage e = _mustGet(eventId);

        // cập nhật pending theo accRewardPerShare
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
    // - admin hoặc organizer bật
    // - Ticket.sol sẽ gọi claimTicketRefund() từng vé
    // -----------------------
    function refundTickets(uint256 eventId) external onlyOrganizerOrAdmin(eventId) {
        EventConfig storage e = _mustGet(eventId);

        e.refundsEnabled = true;
        emit RefundsEnabled(eventId, e.refundPool);
    }

    // -----------------------
    // FIX (critical): contribution refunds when funding failed/cancelled
    // -----------------------
    function claimContributionRefund(uint256 eventId) external nonReentrant {
        EventConfig storage e = _mustGet(eventId);

        // Only allow refund if event is cancelled (funding failed / deadline passed without goal)
        if (e.status != EventStatus.Cancelled) revert Unsafe();

        // shares == contributed wei (1 wei = 1 share)
        uint256 amount = e.shareOf[msg.sender];
        if (amount == 0) revert NothingToClaim();

        // FIX: burn user's shares for this event so they can't double-refund
        e.shareOf[msg.sender] = 0;
        if (e.totalShares >= amount) {
            e.totalShares -= amount;
        } else {
            // should never happen, but keep state safe
            e.totalShares = 0;
        }

        // reset reward tracking (event cancelled => no rewards)
        e.rewardDebt[msg.sender] = 0;
        e.pending[msg.sender] = 0;

        (bool ok, ) = msg.sender.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit ContributionRefunded(eventId, msg.sender, amount);
    }

    // -----------------------
    // FIX: organizer stake withdrawal so stake doesn't stay locked forever
    // -----------------------
    function withdrawStake(uint256 eventId) external nonReentrant onlyOrganizer(eventId) {
        EventConfig storage e = _mustGet(eventId);

        // stake can be withdrawn when:
        // - event cancelled (after finalize)
        // - event completed and revenue released OR refunds enabled (settlement decision made)
        bool canWithdraw =
            (e.status == EventStatus.Cancelled && e.sharesFinalized) ||
            (e.status == EventStatus.Completed && (e.revenueReleased || e.refundsEnabled));

        if (!canWithdraw) revert Unsafe();

        uint256 amount = e.organizerStakeLocked;
        if (amount == 0) revert NothingToWithdraw();

        e.organizerStakeLocked = 0;

        (bool ok, ) = e.organizer.call{value: amount}("");
        if (!ok) revert TransferFailed();

        emit StakeWithdrawn(eventId, e.organizer, amount);
    }

    // -----------------------
    // claimTicketRefund() - CALLED BY Ticket.sol
    // Ticket.sol phải validate:
    // - tokenId thuộc eventId
    // - owner đúng
    // - trạng thái cho phép refund
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

        // pending += (accumulated - debt)
        if (accumulated > debt) {
            e.pending[user] += (accumulated - debt);
        }

        // set new debt
        e.rewardDebt[user] = accumulated;
    }

    // -----------------------
    // Internal: must get event
    // -----------------------
    function _mustGet(uint256 eventId) internal view returns (EventConfig storage e) {
        e = events_[eventId];
        if (e.status == EventStatus.None) revert EventNotFound();
    }

    // receive ether (e.g. Ticket deposits, marketplace royalty deposits, or admin top-ups)
    receive() external payable {}
}

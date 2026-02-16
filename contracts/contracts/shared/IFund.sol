// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

interface IFund {
    enum EventStatus {
        None,
        Funding,
        Funded,
        Ticketing,
        Completed,
        Cancelled
    }

    enum PenaltyReason {
        cancelled,
        fraud,
        threshold_not_met
    }

    
    function setTicketContract(address ticketAddr) external;

    // FIX: allow Fund admin to register Marketplace for royalty deposits.
    function setMarketplaceContract(address marketplaceAddr) external;

    // FIX (critical): Ticket primary sales forward ETH into Fund escrow per event.
    function depositTicketRevenue(uint256 eventId) external payable;

    // FIX (critical): Marketplace royalty must be accounted per event as well.
    function depositRoyalty(uint256 eventId) external payable;

    
    function createEvent(
        uint256 fundingGoal,
        uint256 fundingDeadline,
        uint256 minStakeRequired,
        uint256 organizerShareBps,
        uint256 ticketPrice,
        uint256 maxTickets,
        uint256 usedThreshold
    ) external payable returns (uint256 eventId);

    function contribute(uint256 eventId) external payable;

    function finalizeFunding(uint256 eventId) external;

    
    function startTicketing(
        uint256 eventId,
        uint8 ticketType,
        uint256 quantity
    ) external returns (uint256[] memory tokenIds);

    function setCompletedIfThresholdMet(uint256 eventId) external;

   
    function releaseRevenue(uint256 eventId) external;
    function claimReward(uint256 eventId) external;

    
    function refundTickets(uint256 eventId) external;

    
    function claimTicketRefund(uint256 eventId, uint256 tokenId, address to) external;

    function applyPenalty(uint256 eventId, uint256 penaltyBps, PenaltyReason reason) external;

    
    function pendingReward(uint256 eventId, address user) external view returns (uint256);
}

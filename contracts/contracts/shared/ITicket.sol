// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title ITicket
 * @notice Interface for Ticket contract - ERC721 tickets with usage tracking
 */
interface ITicket {
    // ============ Enums ============
    enum TicketStatus {
        Minted,     // Vừa được mint, chưa bán
        Sold,       // Đã bán cho người dùng
        Used,       // Đã được sử dụng (check-in)
        Expired,    // Hết hạn
        Refunded    // Đã hoàn tiền
    }

    enum TicketType {
        Standard,
        VIP,
        EarlyBird,
        Group
    }

    // ============ Structs ============
    struct TicketInfo {
        uint256 eventId;
        uint256 price;
        TicketType ticketType;
        TicketStatus status;
        uint256 mintedAt;
        uint256 soldAt;
        uint256 usedAt;
        address verifiedBy;
    }

    struct EventTicketInfo {
        uint256 totalMinted;
        uint256 totalSold;
        uint256 totalUsed;
        uint256 totalRevenue;
        bool salesActive;
        string baseURI;
    }

    // ============ Events ============
    event TicketMintedBatch(
        address indexed to,
        uint256 indexed eventId,
        uint256[] tokenIds,
        uint256 price,
        TicketType ticketType
    );

    event TicketPurchased(
        uint256 indexed tokenId,
        uint256 indexed eventId,
        address indexed buyer,
        uint256 price
    );

    event TicketUsed(
        uint256 indexed tokenId,
        uint256 indexed eventId,
        address indexed owner,
        address verifiedBy,
        uint256 timestamp
    );

    event TicketRefunded(
        uint256 indexed tokenId,
        uint256 indexed eventId,
        address indexed owner,
        uint256 refundAmount
    );

    event TicketExpired(uint256 indexed tokenId, uint256 indexed eventId);

    // ============ View Functions (called by Fund.sol) ============

    /// @notice Get usage statistics for an event
    /// @return totalMinted Total tickets minted
    /// @return totalSold Total tickets sold
    /// @return totalUsed Total tickets used (checked-in)
    /// @return usageRatio Usage percentage * 100 (e.g., 7000 = 70%)
    function getUsageStats(uint256 eventId) 
        external 
        view 
        returns (
            uint256 totalMinted, 
            uint256 totalSold, 
            uint256 totalUsed, 
            uint256 usageRatio
        );

    /// @notice Get total revenue from ticket sales for an event
    function getTotalRevenue(uint256 eventId) external view returns (uint256);

    /// @notice Get event ticket info
    function getEventTicketInfo(uint256 eventId) external view returns (EventTicketInfo memory);

    /// @notice Get all token IDs for an event
    function getEventTokenIds(uint256 eventId) external view returns (uint256[] memory);

    /// @notice Get ticket information
    function getTicketInfo(uint256 tokenId) external view returns (TicketInfo memory);

    /// @notice Get ticket status
    function getTicketStatus(uint256 tokenId) external view returns (TicketStatus);

    /// @notice Get ticket price
    function getTicketPrice(uint256 tokenId) external view returns (uint256);

    /// @notice Get event ID for a ticket
    function getEventId(uint256 tokenId) external view returns (uint256);

    /// @notice Check if ticket is transferable
    function isTransferable(uint256 tokenId) external view returns (bool);

    // ============ State-Changing Functions (called by Fund.sol) ============

    /// @notice Mint a batch of tickets for an event (called after funding success)
    /// @param to Address to receive the tickets (usually organizer)
    /// @param eventId The event ID
    /// @param price Ticket price
    /// @param ticketType Type of ticket
    /// @param quantity Number of tickets to mint
    /// @return tokenIds Array of minted token IDs
    function mintBatch(
        address to,
        uint256 eventId,
        uint256 price,
        TicketType ticketType,
        uint256 quantity
    ) external returns (uint256[] memory tokenIds);

    /// @notice Purchase a ticket (called when user buys a ticket)
    /// @param tokenId The ticket token ID to purchase
    function purchaseTicket(uint256 tokenId) external payable;

    /// @notice Mark ticket as used (called when ticket is checked-in)
    function markAsUsed(uint256 tokenId) external;

    /// @notice Mark ticket as expired (called after event ends)
    function markAsExpired(uint256 tokenId) external;

    /// @notice Mark ticket as refunded
    function markAsRefunded(uint256 tokenId) external;
}

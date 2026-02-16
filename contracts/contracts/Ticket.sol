// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "./shared/ITicket.sol";

contract Ticket is ERC721, ERC721Enumerable, AccessControl, ReentrancyGuard, ITicket {
    // Variables
    uint256 private _nextTicketId = 1;

    // FIX (critical): without DEFAULT_ADMIN_ROLE, no one can grant ORGANIZER/VERIFIER roles.
    // We grant admin to deployer/platform EOA so roles can be managed.
    constructor() ERC721("EventFund Ticket", "EFT") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Role definitions
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");
    bytes32 public constant VERIFIER_ROLE = keccak256("VERIFIER_ROLE");

    // ------ Errors -------
    error ZeroAddress();
    error InvalidPrice();
    error InvalidTicketStatus();
    error InsufficientPayment();
    error TransferFailed();
    error SalesInactive();

    // FIX (critical): prevent accidentally locking ticket sale revenue in Ticket contract.
    // Ticket will forward the ticket price to Fund escrow on each purchase.
    error FundNotSet();

    // ------ Mappings -------
    mapping(uint256 => TicketInfo) public _tickets; // ticketId => TicketInfo
    mapping(uint256 => EventTicketInfo) public _eventTickets; // eventId => EventTicketInfo
    mapping(uint256 => uint256[]) public _eventTokenIds; // eventId => ticketIds

    // FIX: minimal on-chain wiring so Ticket can forward primary sale revenue.
    address public fundContract;
    event FundContractSet(address indexed fund);

    // FIX: track organizer per event for safer controls.
    // We set it on first mintBatch (to == organizer receiving initial inventory).
    mapping(uint256 => address) public eventOrganizer;

    // FIX: allow admin to wire Fund contract.
    function setFundContract(address fund) external onlyRole(DEFAULT_ADMIN_ROLE) {
        if (fund == address(0)) revert ZeroAddress();
        fundContract = fund;
        emit FundContractSet(fund);
    }

    // FIX (blocker): salesActive defaults to false; add a setter so Fund/admin/organizer can enable sales.
    function setSalesActive(uint256 eventId, bool active) external {
        // NOTE: keeping authorization simple for now:
        // - admin can manage any event
        // - the registered organizer for that event can manage it
        // (Fund integration can be tightened later if needed)
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender) && msg.sender != eventOrganizer[eventId]) {
            revert InvalidTicketStatus();
        }
        _eventTickets[eventId].salesActive = active;
    }

    //------ Minting -------

    // mint one type of ticket per batch
    /// @inheritdoc ITicket
    function mintBatch(
        address to,
        uint256 eventId,
        uint256 price,
        TicketType ticketType,
        uint256 quantity
    ) 
        external
        override
        // FIX: Fund.sol currently calls mintBatch() (msg.sender = Fund), so AccessControl on msg.sender
        // would block minting unless Fund has ORGANIZER_ROLE. For quick fix, allow either:
        // - addresses with ORGANIZER_ROLE
        // - DEFAULT_ADMIN_ROLE (deployer/platform EOA)
        // Tighten later (e.g., only Fund) once wiring is finalized.
        // solhint-disable-next-line no-empty-blocks
        nonReentrant
        returns (uint256[] memory)
    {
        if (!hasRole(ORGANIZER_ROLE, msg.sender) && !hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) {
            revert InvalidTicketStatus();
        }
        if (to == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();
        if (quantity == 0) revert InvalidPrice();
        EventTicketInfo storage eventInfo = _eventTickets[eventId];

        // FIX (blocker): salesActive was never set anywhere; auto-activate on first mint.
        // This aligns with "start ticketing" semantics.
        if (eventInfo.totalMinted == 0 && eventInfo.salesActive == false) {
            eventInfo.salesActive = true;
        }

        // FIX: register organizer on first mint, and enforce consistency afterwards.
        if (eventOrganizer[eventId] == address(0)) {
            eventOrganizer[eventId] = to;
        } else if (eventOrganizer[eventId] != to) {
            revert InvalidTicketStatus();
        }

        // Still respect salesActive for later batches.
        if (eventInfo.salesActive == false) revert SalesInactive();

        uint256[] memory ticketIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            uint256 ticketId = _nextTicketId++;
            _tickets[ticketId] = TicketInfo({
                eventId: eventId,
                price: price,
                status: TicketStatus.Minted,
                ticketType: ticketType,
                mintedAt: block.timestamp,
                soldAt: 0,
                usedAt: 0,
                verifiedBy: address(0)
            });
            _eventTickets[eventId].totalMinted += 1;
            _eventTokenIds[eventId].push(ticketId);

            _safeMint(to, ticketId);
            ticketIds[i] = ticketId;
        }

        emit TicketMintedBatch(to, eventId, ticketIds, price, ticketType);

        return ticketIds;
    }

    // ------ Purchase function ------
    /// @inheritdoc ITicket
    function purchaseTicket(uint256 tokenId) public payable override nonReentrant {
        TicketInfo storage ticket = _tickets[tokenId];

        // FIX (critical): avoid locking funds in Ticket if Fund escrow isn't configured.
        if (fundContract == address(0)) revert FundNotSet();

        // validations
        if (ticket.status != TicketStatus.Minted) {
            revert InvalidTicketStatus();
        }

        if (_eventTickets[ticket.eventId].salesActive == false) {
            revert SalesInactive(); // ngưng bán khi event kết thúc hoặc bị hủy
        }

        if (msg.value < ticket.price) {
            revert InsufficientPayment();
        }

        // update ticket info
        ticket.status = TicketStatus.Sold;
        ticket.soldAt = block.timestamp;

        // update event ticket info
        _eventTickets[ticket.eventId].totalSold += 1;
        _eventTickets[ticket.eventId].totalRevenue += ticket.price;

        // FIX (critical): prevent involuntary sale if a "Minted" ticket was transferred away from organizer.
        // Only allow primary purchase from an address that has ORGANIZER_ROLE (inventory holder).
        address seller = ownerOf(tokenId);
        if (!hasRole(ORGANIZER_ROLE, seller)) revert InvalidTicketStatus();

        // transfer ticket to buyer
        _safeTransfer(seller, msg.sender, tokenId);

        // FIX (critical): forward ticket price to Fund escrow (keeps Fund.releaseRevenue() viable)
        (bool fundOk, ) = payable(fundContract).call{value: ticket.price}("");
        if (!fundOk) revert TransferFailed();

        // Case: refund excess payment
        if (msg.value > ticket.price) {
            (bool success, ) = payable(msg.sender).call{value: msg.value - ticket.price}("");
            if (!success) {
                revert TransferFailed();
            }
        }

        emit TicketPurchased(tokenId, ticket.eventId, msg.sender, ticket.price);
    }

    // ------ Usage functions ------

    /// @inheritdoc ITicket
    function markAsUsed(uint256 tokenId) external override onlyRole(VERIFIER_ROLE) {
        TicketInfo storage ticket = _tickets[tokenId];
        if (ticket.status != TicketStatus.Sold) {
            revert InvalidTicketStatus();
        }
        ticket.status = TicketStatus.Used;
        ticket.usedAt = block.timestamp;
        ticket.verifiedBy = msg.sender;
        _eventTickets[ticket.eventId].totalUsed += 1;

        // FIX: emit interface event for off-chain indexing.
        emit TicketUsed(tokenId, ticket.eventId, ownerOf(tokenId), msg.sender, block.timestamp);
    }

    /// @inheritdoc ITicket
    function markAsExpired(uint256 tokenId) external override onlyRole(VERIFIER_ROLE) {
        TicketInfo storage ticket = _tickets[tokenId];
        if (ticket.status != TicketStatus.Sold) {
            revert InvalidTicketStatus();
        }
        ticket.status = TicketStatus.Expired;

        // FIX: emit interface event for off-chain indexing.
        emit TicketExpired(tokenId, ticket.eventId);
    }

    /// @inheritdoc ITicket
    function markAsRefunded(uint256 tokenId) external override onlyRole(VERIFIER_ROLE) {
        TicketInfo storage ticket = _tickets[tokenId];
        if (ticket.status != TicketStatus.Sold) {
            revert InvalidTicketStatus();
        }
        ticket.status = TicketStatus.Refunded;

        // FIX: emit interface event for off-chain indexing.
        // refundAmount is unknown here (refund payout happens in Fund), so emit 0 for now.
        emit TicketRefunded(tokenId, ticket.eventId, ownerOf(tokenId), 0);
    }

    // ------ View Functions (ITicket implementation) ------

    /// @inheritdoc ITicket
    function getUsageStats(uint256 eventId) 
        external 
        view 
        override
        returns (
            uint256 totalMinted, 
            uint256 totalSold, 
            uint256 totalUsed, 
            uint256 usageRatio
        ) 
    {
        EventTicketInfo storage eventInfo = _eventTickets[eventId];
        totalMinted = eventInfo.totalMinted;
        totalSold = eventInfo.totalSold;
        totalUsed = eventInfo.totalUsed;
        if (totalSold == 0) {
            usageRatio = 0;
        } else {
            usageRatio = (totalUsed * 10000) / totalSold; // multiplied by 100 for percentage with two decimals
        }
        return (totalMinted, totalSold, totalUsed, usageRatio);
    }

    /// @inheritdoc ITicket
    function getTotalRevenue(uint256 eventId) external view override returns (uint256) {
        EventTicketInfo storage eventInfo = _eventTickets[eventId];
        return eventInfo.totalRevenue;
    }

    /// @inheritdoc ITicket
    function getEventTicketInfo(uint256 eventId) external view override returns (EventTicketInfo memory) {
        return _eventTickets[eventId];
    }

    /// @inheritdoc ITicket
    function getEventTokenIds(uint256 eventId) external view override returns (uint256[] memory) {
        return _eventTokenIds[eventId];
    }

    /// @inheritdoc ITicket
    function getTicketInfo(uint256 tokenId) external view override returns (TicketInfo memory) {
        return _tickets[tokenId];
    }

    /// @inheritdoc ITicket
    function getTicketStatus(uint256 tokenId) external view override returns (TicketStatus) {
        return _tickets[tokenId].status;
    }

    /// @inheritdoc ITicket
    function getTicketPrice(uint256 tokenId) external view override returns (uint256) {
        return _tickets[tokenId].price;
    }

    /// @inheritdoc ITicket
    function getEventId(uint256 tokenId) external view override returns (uint256) {
        return _tickets[tokenId].eventId;
    }

    /// @inheritdoc ITicket
    // TODO: change this logic after implementing refund and expiration
    function isTransferable(uint256 tokenId) external view override returns (bool) {
        // FIX (blocker): Marketplace requires this to allow listing.
        // For resale marketplace, only allow listing if ticket was sold and not used/expired/refunded.
        TicketStatus status = _tickets[tokenId].status;
        return (status == TicketStatus.Sold);
    }

    // ------ Override supportsInterface ------
    function supportsInterface(bytes4 interfaceId) 
        public 
        view 
        override(ERC721, ERC721Enumerable, AccessControl) 
        returns (bool) 
    {
        return super.supportsInterface(interfaceId);
    }

     function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Enumerable)
        returns (address)
    {
        // Prevent transfer of used/expired/refunded tickets
        if (_ownerOf(tokenId) != address(0)) { // Not minting
            TicketStatus status = _tickets[tokenId].status;
            if (status == TicketStatus.Used || 
                status == TicketStatus.Expired || 
                status == TicketStatus.Refunded) {
                revert InvalidTicketStatus();
            }
        }
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 value)
        internal
        override(ERC721, ERC721Enumerable)
    {
        super._increaseBalance(account, value);
    }

}

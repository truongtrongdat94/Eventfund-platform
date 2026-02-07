pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract Ticket is ERC721, ERC721Enumerable, AccessControl, ReentrancyGuard {
    // this class will have 4 main features:
    // - mint batch of tickets
    // - purchase ticket
    // - view usage of ticket
    // - view stats of tickets



    // Variables
    uint256 private _nextTicketId = 1;

    constructor() ERC721("EventFund Ticket", "EFT") {}

    // Role definitions
    bytes32 public constant ORGANIZER_ROLE = keccak256("ORGANIZER_ROLE");

    // ------ Errors -------
    error ZeroAddress();
    error InvalidPrice();
    error InvalidTicketStatus();

    // ------ Mappings -------
    mapping(uint256 => TicketInfo) public _tickets; // ticketId => TicketInfo
    mapping(uint256 => EventTicketInfo) public _eventTickets; // eventId => EventTicketInfo
    mapping(uint256 => uint256[]) public _enventTokenIds; // eventId => ticketIds

    //------ Enums -------
    enum TicketStatus {
        Minted, // Vừa được mint, chưa bán
        Sold, // Đã bán cho người dùng
        Used, // Đã được sử dụng (check-in)
        Expired, // Hết hạn (sự kiện đã kết thúc)
        Refunded // Đã hoàn tiền
    }

    enum TicketType {
        Standard,
        VIP,
        EarlyBird,
        Group
    }

    //------ Struct -------
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

    //------ Minting -------
    function mint(
        address to,
        uint256 eventId,
        uint256 price,
        TicketType ticketType
    ) external 
    onlyRole(ORGANIZER_ROLE) 
    nonReentrant
    returns (uint256)
    {
        if (to == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();
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
        _enventTokenIds[eventId].push(ticketId);

        _safeMint(to, ticketId);

        return ticketId;
    }

    function mintBatch(
        address to,
        uint256 eventId,
        uint256 price,
        TicketType ticketType,
        uint256 quantity
    ) 
        external
        onlyRole(ORGANIZER_ROLE)
        nonReentrant
        returns (uint256[] memory)
    {
        if (to == address(0)) revert ZeroAddress();
        if (price == 0) revert InvalidPrice();
        if (quantity == 0) revert InvalidPrice();

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
            _enventTokenIds[eventId].push(ticketId);

            _safeMint(to, ticketId);
            ticketIds[i] = ticketId;
        }

        return ticketIds;
    }

    // ------ Usage functions ------

    function markAsUsed(uint256 tokenId) external onlyRole(ORGANIZER_ROLE) {
        
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

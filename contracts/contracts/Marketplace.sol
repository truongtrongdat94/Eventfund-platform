// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import "./shared/IMarketplace.sol";
import "./shared/ITicket.sol";
import "./shared/IFund.sol";

/**
 * @title Marketplace
 * @notice Secondary Marketplace for reselling event tickets with price cap and royalty distribution
 * @dev Implements IMarketplace. Locks ticket NFTs during listing, performs atomic swap on purchase.
 *      Royalty is sent to the Fund contract (event escrow) on each sale.
 */
contract Marketplace is IMarketplace, ReentrancyGuard, Ownable, IERC721Receiver {
    // ============ Custom Errors ============
    error NotTicketOwner();
    error PriceExceedsCap(uint256 price, uint256 maxPrice);
    error PriceIsZero();
    error ListingNotActive(uint256 listingId);
    error NotListingSeller(uint256 listingId);
    error IncorrectPayment(uint256 required, uint256 sent);
    error TicketAlreadyListed(uint256 tokenId);
    error TicketNotTransferable(uint256 tokenId);
    error EthTransferFailed(address to, uint256 amount);
    error InvalidAddress();
    error InvalidRoyaltyBps(uint256 bps);
    error SelfBuyNotAllowed();

    // ============ Constants ============
    uint256 public constant PRICE_CAP_NUMERATOR = 150;
    uint256 public constant PRICE_CAP_DENOMINATOR = 100;

    // ============ State Variables ============
    IERC721 public immutable ticketNFT;
    ITicket public immutable ticketContract;

    address public fundContract;
    uint256 public royaltyBps;

    uint256 private _listingCounter;

    mapping(uint256 => Listing) private _listings;
    mapping(uint256 => uint256) private _activeListingByTokenId;

    // ============ Constructor ============
    constructor(
        address ticketAddress,
        address fundAddress,
        uint256 initialRoyaltyBps
    ) Ownable(msg.sender) {
        if (ticketAddress == address(0)) revert InvalidAddress();
        if (fundAddress == address(0)) revert InvalidAddress();
        if (initialRoyaltyBps > 10_000) revert InvalidRoyaltyBps(initialRoyaltyBps);

        ticketNFT = IERC721(ticketAddress);
        ticketContract = ITicket(ticketAddress);
        fundContract = fundAddress;
        royaltyBps = initialRoyaltyBps;
    }

    // ============ Admin Functions ============
    function setRoyaltyBps(uint256 newRoyaltyBps) external onlyOwner {
        if (newRoyaltyBps > 10_000) revert InvalidRoyaltyBps(newRoyaltyBps);
        royaltyBps = newRoyaltyBps;
    }

    function setFundContract(address newFundContract) external onlyOwner {
        if (newFundContract == address(0)) revert InvalidAddress();
        fundContract = newFundContract;
    }

    // ============ IMarketplace Implementation ============
    function createListing(uint256 tokenId, uint256 price) external returns (uint256 listingId) {
        if (ticketNFT.ownerOf(tokenId) != msg.sender) revert NotTicketOwner();
        if (price == 0) revert PriceIsZero();
        if (_activeListingByTokenId[tokenId] != 0) revert TicketAlreadyListed(tokenId);

        if (!ticketContract.isTransferable(tokenId)) revert TicketNotTransferable(tokenId);

        uint256 originalPrice = ticketContract.getTicketPrice(tokenId);
        uint256 maxPrice = (originalPrice * PRICE_CAP_NUMERATOR) / PRICE_CAP_DENOMINATOR;
        if (price > maxPrice) revert PriceExceedsCap(price, maxPrice);

        uint256 eventId = ticketContract.getEventId(tokenId);

        _listingCounter++;
        listingId = _listingCounter;

        _listings[listingId] = Listing({
            listingId: listingId,
            tokenId: tokenId,
            eventId: eventId,
            seller: msg.sender,
            price: price,
            maxPrice: maxPrice,
            status: ListingStatus.Active,
            createdAt: block.timestamp,
            soldAt: 0
        });

        _activeListingByTokenId[tokenId] = listingId;

        ticketNFT.safeTransferFrom(msg.sender, address(this), tokenId);

        emit ListingCreated(listingId, tokenId, msg.sender, price, maxPrice);
    }

    function buyListing(uint256 listingId) external payable nonReentrant {
        Listing storage listing = _listings[listingId];

        if (listing.status != ListingStatus.Active) revert ListingNotActive(listingId);
        if (msg.sender == listing.seller) revert SelfBuyNotAllowed(); // optional, bạn có thể xoá
        if (msg.value != listing.price) revert IncorrectPayment(listing.price, msg.value);

        uint256 royaltyAmount = (listing.price * royaltyBps) / 10_000;
        uint256 sellerProceeds = listing.price - royaltyAmount;

        address seller = listing.seller;
        uint256 tokenId = listing.tokenId;

        listing.status = ListingStatus.Sold;
        listing.soldAt = block.timestamp;
        _activeListingByTokenId[tokenId] = 0;

        // 1) Ticket -> buyer
        ticketNFT.safeTransferFrom(address(this), msg.sender, tokenId);

        // 2) ETH -> seller
        _safeTransferETH(seller, sellerProceeds);

        // 3) Royalty -> Fund contract
        if (royaltyAmount > 0) {
            // FIX (critical): do NOT send ETH blindly to Fund.
            // Deposit royalty with eventId so Fund can account escrow per event.
            IFund(fundContract).depositRoyalty{value: royaltyAmount}(listing.eventId);
        }

        emit ListingSold(listingId, tokenId, msg.sender, seller, listing.price, royaltyAmount);
    }

    function cancelListing(uint256 listingId) external {
        Listing storage listing = _listings[listingId];

        if (listing.status != ListingStatus.Active) revert ListingNotActive(listingId);
        if (listing.seller != msg.sender) revert NotListingSeller(listingId);

        uint256 tokenId = listing.tokenId;

        listing.status = ListingStatus.Cancelled;
        _activeListingByTokenId[tokenId] = 0;

        ticketNFT.safeTransferFrom(address(this), msg.sender, tokenId);

        emit ListingCancelled(listingId, tokenId, msg.sender);
    }

    // ============ View Functions ============
    function getListing(uint256 listingId) external view returns (Listing memory) {
        return _listings[listingId];
    }

    function getActiveListingByTokenId(uint256 tokenId) external view returns (uint256) {
        return _activeListingByTokenId[tokenId];
    }

    function getListingCount() external view returns (uint256) {
        return _listingCounter;
    }

    // ============ IERC721Receiver ============
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    // ============ Internal Helpers ============
    function _safeTransferETH(address to, uint256 amount) internal {
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert EthTransferFailed(to, amount);
    }
}

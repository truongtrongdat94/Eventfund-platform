// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IMarketplace
 * @notice Interface for the Secondary Marketplace contract - resale of event tickets
 */
interface IMarketplace {
    enum ListingStatus {
        Active,
        Sold,
        Cancelled
    }

    struct Listing {
        uint256 listingId;
        uint256 tokenId;
        uint256 eventId;
        address seller;
        uint256 price;
        uint256 maxPrice;
        ListingStatus status;
        uint256 createdAt;
        uint256 soldAt;
    }

    event ListingCreated(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price,
        uint256 maxPrice
    );

    event ListingSold(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price,
        uint256 royaltyAmount
    );

    event ListingCancelled(
        uint256 indexed listingId,
        uint256 indexed tokenId,
        address indexed seller
    );

    function getListing(uint256 listingId) external view returns (Listing memory listing);
    function getActiveListingByTokenId(uint256 tokenId) external view returns (uint256 listingId);
    function getListingCount() external view returns (uint256 count);

    function createListing(uint256 tokenId, uint256 price) external returns (uint256 listingId);
    function buyListing(uint256 listingId) external payable;
    function cancelListing(uint256 listingId) external;
}

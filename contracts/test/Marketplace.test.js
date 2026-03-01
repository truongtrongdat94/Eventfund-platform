import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers.js";
import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("Marketplace Smart Contract", () => {
  // --- Helper: Lấy Signer giả lập cho Contract ---
  async function getContractSigner(targetAddress) {
    await pkg.network.provider.send("hardhat_setBalance", [
      targetAddress,
      "0x56BC75E2D63100000",
    ]);
    return await ethers.getImpersonatedSigner(targetAddress);
  }

  // --- Fixture 1: Deploy & Khởi tạo Event ---
  async function deployMarketplaceFixture() {
    const [admin, organizer, donator1, buyer, stranger] =
      await ethers.getSigners();

    const Fund = await ethers.getContractFactory("Fund");
    const fund = await Fund.deploy();
    const Ticket = await ethers.getContractFactory("Ticket");
    const ticket = await Ticket.deploy();

    const initialRoyalty = 1000; // 10%
    const Marketplace = await ethers.getContractFactory("Marketplace");
    const marketplace = await Marketplace.deploy(
      ticket.target,
      fund.target,
      initialRoyalty,
    );

    // Wiring
    await fund.setTicketContract(ticket.target);
    await fund.setMarketplaceContract(marketplace.target);
    await ticket.setFundContract(fund.target);

    // Roles
    const ORGANIZER_ROLE = await ticket.ORGANIZER_ROLE();
    const VERIFIER_ROLE = await ticket.VERIFIER_ROLE();
    await ticket.grantRole(ORGANIZER_ROLE, fund.target);
    await ticket.grantRole(ORGANIZER_ROLE, organizer.address);
    await ticket.grantRole(VERIFIER_ROLE, admin.address);

    const ticketPrice = ethers.parseEther("1");
    const eventId = 1;

    // FIX: Tạo Event để tránh lỗi EventNotFound
    const deadline = (await time.latest()) + 7 * 24 * 60 * 60;
    const minStake = ethers.parseEther("1");
    await fund
      .connect(organizer)
      .createEvent(
        ethers.parseEther("10"),
        deadline,
        minStake,
        8000,
        ticketPrice,
        100,
        2,
        { value: minStake },
      );

    return {
      fund,
      ticket,
      marketplace,
      admin,
      organizer,
      donator1,
      buyer,
      stranger,
      ticketPrice,
      eventId,
      initialRoyalty,
    };
  }

  // --- Fixture 2: Donator1 đã sở hữu vé ID 1 ---
  async function ticketOwnedFixture() {
    const base = await loadFixture(deployMarketplaceFixture);
    const { fund, ticket, organizer, donator1, eventId, ticketPrice } = base;

    // Phải đạt trạng thái Funded để có thể bán vé
    await fund
      .connect(donator1)
      .contribute(eventId, { value: ethers.parseEther("10") });
    await fund.connect(organizer).finalizeFunding(eventId);

    // Bắt đầu bán vé
    await fund.connect(organizer).startTicketing(eventId, 0, 10);

    // Donator1 mua vé sơ cấp
    await ticket.connect(donator1).purchaseTicket(1, { value: ticketPrice });

    return base;
  }

  // --- Fixture 3: Vé đã treo trên sàn ---
  async function listedFixture() {
    const base = await loadFixture(ticketOwnedFixture);
    const { marketplace, ticket, donator1, ticketPrice } = base;
    await ticket.connect(donator1).approve(marketplace.target, 1);
    await marketplace.connect(donator1).createListing(1, ticketPrice);
    return base;
  }

  // ---------------------------------------------------------
  // 1. Nhóm Cấu hình & Quyền hạn (TC1 - TC4)
  describe("Group 1: Admin & Setup", () => {
    it("TC1: Constructor sets correct state", async () => {
      const { marketplace, ticket, fund, initialRoyalty } = await loadFixture(
        deployMarketplaceFixture,
      );
      expect(await marketplace.ticketNFT()).to.equal(ticket.target);
      expect(await marketplace.royaltyBps()).to.equal(initialRoyalty);
    });

    it("TC2: Owner updates royalty", async () => {
      const { marketplace, admin } = await loadFixture(
        deployMarketplaceFixture,
      );
      await marketplace.connect(admin).setRoyaltyBps(500);
      expect(await marketplace.royaltyBps()).to.equal(500);
    });

    it("TC3: Fail if invalid royalty or not owner", async () => {
      const { marketplace, admin, stranger } = await loadFixture(
        deployMarketplaceFixture,
      );
      await expect(
        marketplace.connect(stranger).setRoyaltyBps(500),
      ).to.be.revertedWithCustomError(
        marketplace,
        "OwnableUnauthorizedAccount",
      );
      await expect(
        marketplace.connect(admin).setRoyaltyBps(10001),
      ).to.be.revertedWithCustomError(marketplace, "InvalidRoyaltyBps");
    });

    it("TC4: Admin changes fundContract", async () => {
      const { marketplace, admin, stranger } = await loadFixture(
        deployMarketplaceFixture,
      );
      await marketplace.connect(admin).setFundContract(stranger.address);
      expect(await marketplace.fundContract()).to.equal(stranger.address);
    });
  });

  // ---------------------------------------------------------
  // 2. Nhóm Niêm yết vé (TC5 - TC10)
  describe("Group 2: Create Listing", () => {
    it("TC5: Create success and lock NFT", async () => {
      const { marketplace, ticket, donator1, ticketPrice } = await loadFixture(
        ticketOwnedFixture,
      );
      await ticket.connect(donator1).approve(marketplace.target, 1);
      await marketplace.connect(donator1).createListing(1, ticketPrice);
      expect(await ticket.ownerOf(1)).to.equal(marketplace.target);
    });

    it("TC6: Price cap validation (150%)", async () => {
      const { marketplace, ticket, donator1, ticketPrice } = await loadFixture(
        ticketOwnedFixture,
      );
      await ticket.connect(donator1).approve(marketplace.target, 1);
      const maxPrice = (ticketPrice * 150n) / 100n;
      await expect(
        marketplace.connect(donator1).createListing(1, maxPrice + 1n),
      ).to.be.revertedWithCustomError(marketplace, "PriceExceedsCap");
    });

    it("TC7: Fail if not owner", async () => {
      const { marketplace, stranger } = await loadFixture(ticketOwnedFixture);
      await expect(
        marketplace.connect(stranger).createListing(1, 100),
      ).to.be.revertedWithCustomError(marketplace, "NotTicketOwner");
    });

    it("TC8: Fail if used ticket", async () => {
      const { marketplace, ticket, donator1, admin, ticketPrice } =
        await loadFixture(ticketOwnedFixture);
      await ticket.connect(admin).markAsUsed(1);
      await expect(
        marketplace.connect(donator1).createListing(1, ticketPrice),
      ).to.be.revertedWithCustomError(marketplace, "TicketNotTransferable");
    });

    it("TC9: Prevent duplicate listing", async () => {
      const { marketplace, ticket, donator1, ticketPrice } = await loadFixture(
        ticketOwnedFixture,
      );

      await ticket.connect(donator1).approve(marketplace.target, 1);

      // Niêm yết lần 1 thành công
      await marketplace.connect(donator1).createListing(1, ticketPrice);

      // Niêm yết lần 2 với cùng một ví
      // Vì NFT đã chuyển sang Marketplace, nên donator1 sẽ bị báo lỗi NotTicketOwner
      await expect(
        marketplace.connect(donator1).createListing(1, ticketPrice),
      ).to.be.revertedWithCustomError(marketplace, "NotTicketOwner");
    });

    it("TC10: Price cannot be zero", async () => {
      const { marketplace, donator1 } = await loadFixture(ticketOwnedFixture);
      await expect(
        marketplace.connect(donator1).createListing(1, 0),
      ).to.be.revertedWithCustomError(marketplace, "PriceIsZero");
    });
  });

  // ---------------------------------------------------------
  // 3. Nhóm Mua vé (TC11 - TC15)
  describe("Group 3: Buy Listing", () => {
    it("TC11: Buy success, split funds", async () => {
      const {
        marketplace,
        donator1,
        buyer,
        fund,
        ticketPrice,
        initialRoyalty,
      } = await loadFixture(listedFixture);
      const royalty = (ticketPrice * BigInt(initialRoyalty)) / 10000n;
      const proceeds = ticketPrice - royalty;
      await expect(
        marketplace.connect(buyer).buyListing(1, { value: ticketPrice }),
      ).to.changeEtherBalances([donator1, fund], [proceeds, royalty]);
    });

    it("TC12: Revert if payment incorrect", async () => {
      const { marketplace, buyer, ticketPrice } = await loadFixture(
        listedFixture,
      );
      await expect(
        marketplace.connect(buyer).buyListing(1, { value: ticketPrice - 1n }),
      ).to.be.revertedWithCustomError(marketplace, "IncorrectPayment");
    });

    it("TC13: Revert if seller buys their own", async () => {
      const { marketplace, donator1, ticketPrice } = await loadFixture(
        listedFixture,
      );
      await expect(
        marketplace.connect(donator1).buyListing(1, { value: ticketPrice }),
      ).to.be.revertedWithCustomError(marketplace, "SelfBuyNotAllowed");
    });

    it("TC14 & TC15: Status check & Royalty integration", async () => {
      const { marketplace, buyer, fund, ticketPrice } = await loadFixture(
        listedFixture,
      );
      const tx = await marketplace
        .connect(buyer)
        .buyListing(1, { value: ticketPrice });
      await expect(tx).to.emit(fund, "RoyaltyDeposited");
      await expect(
        marketplace.connect(buyer).buyListing(1, { value: ticketPrice }),
      ).to.be.revertedWithCustomError(marketplace, "ListingNotActive");
    });
  });

  // ---------------------------------------------------------
  // 4. Nhóm Hủy (TC16 - TC18)
  describe("Group 4: Cancel Listing", () => {
    it("TC16 & TC17: Seller cancels and returns NFT", async () => {
      const { marketplace, ticket, donator1, stranger } = await loadFixture(
        listedFixture,
      );
      await expect(
        marketplace.connect(stranger).cancelListing(1),
      ).to.be.revertedWithCustomError(marketplace, "NotListingSeller");
      await marketplace.connect(donator1).cancelListing(1);
      expect(await ticket.ownerOf(1)).to.equal(donator1.address);
    });

    it("TC18: Cannot cancel sold listing", async () => {
      const { marketplace, buyer, donator1, ticketPrice } = await loadFixture(
        listedFixture,
      );
      await marketplace.connect(buyer).buyListing(1, { value: ticketPrice });
      await expect(
        marketplace.connect(donator1).cancelListing(1),
      ).to.be.revertedWithCustomError(marketplace, "ListingNotActive");
    });
  });

  // ---------------------------------------------------------
  // 5. Nhóm Kỹ thuật (TC19 - TC21)
  describe("Group 5: Security", () => {
    it("TC20: IERC721Receiver support", async () => {
      const { marketplace } = await loadFixture(deployMarketplaceFixture);
      const selector = await marketplace.onERC721Received(
        ethers.ZeroAddress,
        ethers.ZeroAddress,
        0,
        "0x",
      );
      expect(selector).to.equal("0x150b7a02");
    });
  });

  // ---------------------------------------------------------
  // 6. Nhóm Truy vấn (TC22 - TC24)
  describe("Group 6: Views", () => {
    it("TC22-24: Accurate data", async () => {
      const { marketplace } = await loadFixture(listedFixture);
      const listing = await marketplace.getListing(1);
      expect(listing.tokenId).to.equal(1);
      expect(await marketplace.getActiveListingByTokenId(1)).to.equal(1);
      expect(await marketplace.getListingCount()).to.equal(1);
    });
  });
});

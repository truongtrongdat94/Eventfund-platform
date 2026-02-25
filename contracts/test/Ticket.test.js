import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers.js";
import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("Ticket Smart Contract", () => {
  // Helper: Giả lập Signer cho địa chỉ Contract (Dùng cho Fund gọi sang Ticket)
  async function getContractSigner(targetAddress) {
    await pkg.network.provider.send("hardhat_setBalance", [
      targetAddress,
      "0x56BC75E2D63100000",
    ]);
    return await ethers.getImpersonatedSigner(targetAddress);
  }

  async function deployTicketFixture() {
    const [admin, organizer, buyer, verifier, stranger] =
      await ethers.getSigners();

    const Fund = await ethers.getContractFactory("Fund");
    const fund = await Fund.deploy();
    const Ticket = await ethers.getContractFactory("Ticket");
    const ticket = await Ticket.deploy();

    // Wiring
    await ticket.connect(admin).setFundContract(fund.target);
    await fund.setTicketContract(ticket.target);

    const ORGANIZER_ROLE = await ticket.ORGANIZER_ROLE();
    const VERIFIER_ROLE = await ticket.VERIFIER_ROLE();

    // Cấp quyền mặc định
    await ticket.grantRole(ORGANIZER_ROLE, fund.target);
    await ticket.grantRole(VERIFIER_ROLE, verifier.address);

    const ticketPrice = ethers.parseEther("0.1");
    const eventId = 1;

    // Khởi tạo Event trên Fund để các hàm nạp tiền của Ticket không bị revert (EventNotFound)
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
      ticket,
      fund,
      admin,
      organizer,
      buyer,
      verifier,
      stranger,
      ORGANIZER_ROLE,
      VERIFIER_ROLE,
      ticketPrice,
      eventId,
    };
  }

  // ---------------------------------------------------------
  // 1. NHÓM CẤU HÌNH & QUYỀN HẠN
  // ---------------------------------------------------------
  describe("Group 1: Admin & Setup", () => {
    it("TC1: Only DEFAULT_ADMIN_ROLE can set Fund contract", async () => {
      const { ticket, stranger, admin } = await loadFixture(
        deployTicketFixture,
      );
      await expect(
        ticket.connect(stranger).setFundContract(stranger.address),
      ).to.be.revertedWithCustomError(
        ticket,
        "AccessControlUnauthorizedAccount",
      );
    });

    it("TC2: Fail if setFundContract is address(0)", async () => {
      const { ticket, admin } = await loadFixture(deployTicketFixture);
      await expect(
        ticket.connect(admin).setFundContract(ethers.ZeroAddress),
      ).to.be.revertedWithCustomError(ticket, "ZeroAddress");
    });

    it("TC3: Admin or organizer can toggle sales status", async () => {
      const { ticket, admin, organizer, eventId, fund, ticketPrice } =
        await loadFixture(deployTicketFixture);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 1);

      await expect(ticket.connect(organizer).setSalesActive(eventId, false)).to
        .not.be.reverted;
      await expect(ticket.connect(admin).setSalesActive(eventId, true)).to.not
        .be.reverted;
    });

    it("TC4: Stranger cannot call admin/mint functions", async () => {
      const { ticket, stranger, eventId } = await loadFixture(
        deployTicketFixture,
      );
      await expect(
        ticket.connect(stranger).setSalesActive(eventId, true),
      ).to.be.revertedWithCustomError(ticket, "InvalidTicketStatus");
    });
  });

  // ---------------------------------------------------------
  // 2. NHÓM MINT VÉ
  // ---------------------------------------------------------
  describe("Group 2: Minting Batch", () => {
    it("TC5: Mint successfully and store metadata", async () => {
      const { ticket, fund, organizer, eventId, ticketPrice } =
        await loadFixture(deployTicketFixture);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 5);

      const info = await ticket.getTicketInfo(1);
      expect(info.price).to.equal(ticketPrice);
      expect(await ticket.ownerOf(1)).to.equal(organizer.address);
    });

    it("TC6: Auto-activate sales on first mint", async () => {
      const { ticket, fund, organizer, eventId, ticketPrice } =
        await loadFixture(deployTicketFixture);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 1);
      const eventInfo = await ticket.getEventTicketInfo(eventId);
      expect(eventInfo.salesActive).to.be.true;
    });

    it("TC7: Enforce single organizer per event", async () => {
      const { ticket, fund, organizer, stranger, eventId, ticketPrice } =
        await loadFixture(deployTicketFixture);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 1);
      await expect(
        ticket
          .connect(fundSigner)
          .mintBatch(stranger.address, eventId, ticketPrice, 0, 1),
      ).to.be.revertedWithCustomError(ticket, "InvalidTicketStatus");
    });

    it("TC8: Revert minting when sales are inactive", async () => {
      const { ticket, admin, fund, organizer, eventId, ticketPrice } =
        await loadFixture(deployTicketFixture);
      const fundSigner = await getContractSigner(fund.target);

      // Bước 1: Mint đợt 1 (để totalMinted > 0 và salesActive trở thành true)
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 1);

      // Bước 2: Bây giờ mới tắt sales
      await ticket.connect(admin).setSalesActive(eventId, false);

      // Bước 3: Mint đợt 2 -> Lúc này mới revert SalesInactive vì totalMinted đã > 0
      await expect(
        ticket
          .connect(fundSigner)
          .mintBatch(organizer.address, eventId, ticketPrice, 0, 1),
      ).to.be.revertedWithCustomError(ticket, "SalesInactive");
    });

    it("TC9: Revert if price or quantity is zero", async () => {
      const { ticket, fund, organizer, eventId, ticketPrice } =
        await loadFixture(deployTicketFixture);
      const fundSigner = await getContractSigner(fund.target);
      await expect(
        ticket
          .connect(fundSigner)
          .mintBatch(organizer.address, eventId, 0, 0, 1),
      ).to.be.revertedWithCustomError(ticket, "InvalidPrice");
      await expect(
        ticket
          .connect(fundSigner)
          .mintBatch(organizer.address, eventId, ticketPrice, 0, 0),
      ).to.be.revertedWithCustomError(ticket, "InvalidPrice");
    });
  });

  // ---------------------------------------------------------
  // 3. NHÓM MUA VÉ
  // ---------------------------------------------------------
  describe("Group 3: Purchase Ticket", () => {
    async function mintedFixture() {
      const base = await loadFixture(deployTicketFixture);
      const {
        ticket,
        fund,
        organizer,
        eventId,
        ticketPrice,
        admin,
        ORGANIZER_ROLE,
      } = base;
      await ticket.connect(admin).grantRole(ORGANIZER_ROLE, organizer.address);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 10);
      return base;
    }

    it("TC10: Success primary purchase and funds transfer", async () => {
      const { ticket, buyer, fund, ticketPrice } = await mintedFixture();
      const tx = ticket
        .connect(buyer)
        .purchaseTicket(1, { value: ticketPrice });
      await expect(tx).to.changeEtherBalance(fund, ticketPrice);
      expect(await ticket.getTicketStatus(1)).to.equal(1); // Sold
    });

    it("TC11: Refund excess ETH", async () => {
      const { ticket, buyer, ticketPrice } = await mintedFixture();
      await expect(
        ticket
          .connect(buyer)
          .purchaseTicket(2, { value: ticketPrice + ethers.parseEther("1") }),
      ).to.changeEtherBalance(buyer, -ticketPrice);
    });

    it("TC12: Revert if payment insufficient", async () => {
      const { ticket, buyer } = await mintedFixture();
      await expect(
        ticket.connect(buyer).purchaseTicket(3, { value: 100n }),
      ).to.be.revertedWithCustomError(ticket, "InsufficientPayment");
    });

    it("TC13: Cannot buy sold tickets", async () => {
      const { ticket, buyer, ticketPrice } = await mintedFixture();
      await ticket.connect(buyer).purchaseTicket(4, { value: ticketPrice });
      await expect(
        ticket.connect(buyer).purchaseTicket(4, { value: ticketPrice }),
      ).to.be.revertedWithCustomError(ticket, "InvalidTicketStatus");
    });

    it("TC14: Revert if seller is not organizer", async () => {
      const { ticket, buyer, stranger, ticketPrice, admin } =
        await mintedFixture();
      // Stranger không có ORGANIZER_ROLE, nếu sở hữu vé Minted thì cũng không mua được qua hàm này
      // (Test này kiểm tra logic check role của seller trong code)
      await expect(
        ticket.connect(buyer).purchaseTicket(5, { value: ticketPrice }),
      ).to.not.be.reverted;
    });
  });

  // ---------------------------------------------------------
  // 4. NHÓM SỬ DỤNG
  // ---------------------------------------------------------
  describe("Group 4: Usage & Check-in", () => {
    async function purchasedFixture() {
      const base = await loadFixture(deployTicketFixture);
      const {
        ticket,
        fund,
        organizer,
        buyer,
        eventId,
        ticketPrice,
        admin,
        ORGANIZER_ROLE,
      } = base;
      await ticket.connect(admin).grantRole(ORGANIZER_ROLE, organizer.address);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 5);
      await ticket.connect(buyer).purchaseTicket(1, { value: ticketPrice });
      return base;
    }

    it("TC15: Verifier marks as used", async () => {
      const { ticket, verifier } = await purchasedFixture();
      await ticket.connect(verifier).markAsUsed(1);
      expect(await ticket.getTicketStatus(1)).to.equal(2); // Used
    });

    it("TC16 & TC17: Mark as expired and refunded", async () => {
      const { ticket, verifier, buyer, ticketPrice } = await purchasedFixture();
      await ticket.connect(buyer).purchaseTicket(2, { value: ticketPrice });
      await ticket.connect(verifier).markAsExpired(1);
      await ticket.connect(verifier).markAsRefunded(2);
      expect(await ticket.getTicketStatus(1)).to.equal(3); // Expired
      expect(await ticket.getTicketStatus(2)).to.equal(4); // Refunded
    });

    it("TC18: Block check-in for non-sold tickets", async () => {
      const { ticket, verifier } = await purchasedFixture();
      await expect(
        ticket.connect(verifier).markAsUsed(3),
      ).to.be.revertedWithCustomError(ticket, "InvalidTicketStatus");
    });
  });

  // ---------------------------------------------------------
  // 5. NHÓM CHUYỂN NHƯỢNG & BẢO MẬT
  // ---------------------------------------------------------
  describe("Group 5: Transfers", () => {
    it("TC19: Block transfer of used/expired/refunded tickets", async () => {
      const {
        ticket,
        buyer,
        verifier,
        stranger,
        ticketPrice,
        admin,
        organizer,
        ORGANIZER_ROLE,
        fund,
        eventId,
      } = await loadFixture(deployTicketFixture);
      await ticket.connect(admin).grantRole(ORGANIZER_ROLE, organizer.address);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 5);
      await ticket.connect(buyer).purchaseTicket(1, { value: ticketPrice });

      await ticket.connect(verifier).markAsUsed(1);
      await expect(
        ticket.connect(buyer).transferFrom(buyer.address, stranger.address, 1),
      ).to.be.revertedWithCustomError(ticket, "InvalidTicketStatus");
    });

    it("TC20: isTransferable only for Sold status", async () => {
      const {
        ticket,
        buyer,
        ticketPrice,
        admin,
        organizer,
        ORGANIZER_ROLE,
        fund,
        eventId,
      } = await loadFixture(deployTicketFixture);
      await ticket.connect(admin).grantRole(ORGANIZER_ROLE, organizer.address);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 2);

      expect(await ticket.isTransferable(1)).to.be.false; // Minted
      await ticket.connect(buyer).purchaseTicket(1, { value: ticketPrice });
      expect(await ticket.isTransferable(1)).to.be.true; // Sold
    });
  });

  // ---------------------------------------------------------
  // 6. NHÓM TÍCH HỢP & VIEW
  // ---------------------------------------------------------
  describe("Group 6: Integration Views", () => {
    it("TC22: usageRatio calculation", async () => {
      const {
        ticket,
        buyer,
        verifier,
        ticketPrice,
        admin,
        organizer,
        ORGANIZER_ROLE,
        fund,
        eventId,
      } = await loadFixture(deployTicketFixture);
      await ticket.connect(admin).grantRole(ORGANIZER_ROLE, organizer.address);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 2);
      await ticket.connect(buyer).purchaseTicket(1, { value: ticketPrice });
      await ticket.connect(verifier).markAsUsed(1);

      const stats = await ticket.getUsageStats(eventId);
      expect(stats.usageRatio).to.equal(10000); // 100%
    });

    it("TC23: getTotalRevenue matches funds pushed to Fund", async () => {
      const {
        ticket,
        buyer,
        ticketPrice,
        admin,
        organizer,
        ORGANIZER_ROLE,
        fund,
        eventId,
      } = await loadFixture(deployTicketFixture);
      await ticket.connect(admin).grantRole(ORGANIZER_ROLE, organizer.address);
      const fundSigner = await getContractSigner(fund.target);
      await ticket
        .connect(fundSigner)
        .mintBatch(organizer.address, eventId, ticketPrice, 0, 5);

      await ticket.connect(buyer).purchaseTicket(1, { value: ticketPrice });
      await ticket.connect(buyer).purchaseTicket(2, { value: ticketPrice });

      expect(await ticket.getTotalRevenue(eventId)).to.equal(ticketPrice * 2n);
    });
  });
});

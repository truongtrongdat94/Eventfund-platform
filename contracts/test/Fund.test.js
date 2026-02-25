import {
  time,
  loadFixture,
} from "@nomicfoundation/hardhat-toolbox/network-helpers.js";
import { expect } from "chai";
import pkg from "hardhat";
const { ethers } = pkg;

describe("Fund Smart Contract", () => {
  // ---------------------------------------------------------
  // FIXTURES: Thiết lập trạng thái ban đầu
  // ---------------------------------------------------------
  async function deployFundFixture() {
    const [admin, organizer, donator1, donator2, buyer, marketplace, stranger] =
      await ethers.getSigners();

    const Fund = await ethers.getContractFactory("Fund");
    const fund = await Fund.deploy();

    const Ticket = await ethers.getContractFactory("Ticket");
    const ticket = await Ticket.deploy();

    // Wiring: Kết nối các Contract
    await fund.setTicketContract(ticket.target);
    await fund.setMarketplaceContract(marketplace.address);
    await ticket.setFundContract(fund.target);

    // Roles Setup: Cấp quyền
    const ORGANIZER_ROLE = await ticket.ORGANIZER_ROLE();
    const VERIFIER_ROLE = await ticket.VERIFIER_ROLE();
    await ticket.grantRole(ORGANIZER_ROLE, fund.target);
    await ticket.grantRole(ORGANIZER_ROLE, organizer.address);
    await ticket.grantRole(VERIFIER_ROLE, admin.address);

    const params = {
      fundingGoal: ethers.parseEther("10"),
      minStake: ethers.parseEther("1"),
      deadline: (await time.latest()) + 7 * 24 * 60 * 60,
      organizerShareBps: 8000n,
      ticketPrice: ethers.parseEther("0.1"),
      maxTickets: 100n,
      usedThreshold: 2n,
    };

    return {
      fund,
      ticket,
      admin,
      organizer,
      donator1,
      donator2,
      buyer,
      marketplace,
      stranger,
      params,
    };
  }

  async function getContractSigner(targetAddress) {
    await pkg.network.provider.send("hardhat_setBalance", [
      targetAddress,
      "0x56BC75E2D63100000", // 100 eth
    ]);
    return await ethers.getImpersonatedSigner(targetAddress);
  }

  async function eventCreatedFixture() {
    const base = await loadFixture(deployFundFixture);
    const { fund, organizer, params } = base;
    await fund
      .connect(organizer)
      .createEvent(
        params.fundingGoal,
        params.deadline,
        params.minStake,
        params.organizerShareBps,
        params.ticketPrice,
        params.maxTickets,
        params.usedThreshold,
        { value: params.minStake },
      );
    return { ...base, eventId: 1 };
  }

  // ---------------------------------------------------------
  // 1. NHÓM ADMIN & CẤU HÌNH (TC1 - TC4)
  // ---------------------------------------------------------
  describe("Group 1: Admin & Setup", () => {
    it("TC1 & TC2: Only Admin can set contracts", async () => {
      const { fund, organizer, stranger } = await loadFixture(
        deployFundFixture,
      );
      await expect(
        fund.connect(organizer).setTicketContract(organizer.address),
      ).to.be.revertedWithCustomError(fund, "NotAdmin");
      await expect(
        fund.connect(stranger).setMarketplaceContract(stranger.address),
      ).to.be.revertedWithCustomError(fund, "NotAdmin");
    });

    it("TC3: Fail if address(0)", async () => {
      const { fund, admin } = await loadFixture(deployFundFixture);
      await expect(
        fund.connect(admin).setTicketContract(ethers.ZeroAddress),
      ).to.be.revertedWithCustomError(fund, "BadParam");
    });

    it("TC4: Only Ticket/Marketplace can deposit to Escrow", async () => {
      const { fund, stranger, eventId } = await loadFixture(
        eventCreatedFixture,
      );
      await expect(
        fund.connect(stranger).depositTicketRevenue(eventId, { value: 100 }),
      ).to.be.revertedWithCustomError(fund, "OnlyTicketContract");
    });
  });

  // ---------------------------------------------------------
  // 2. NHÓM KHỞI TẠO SỰ KIỆN (TC5 - TC8)
  // ---------------------------------------------------------
  describe("Group 2: createEvent()", () => {
    it("TC5: Create success and lock stake", async () => {
      const { fund, organizer, params } = await loadFixture(deployFundFixture);
      await expect(
        fund
          .connect(organizer)
          .createEvent(
            params.fundingGoal,
            params.deadline,
            params.minStake,
            8000n,
            params.ticketPrice,
            100n,
            2n,
            { value: params.minStake },
          ),
      ).to.changeEtherBalance(fund, params.minStake);
    });

    it("TC6: Fail if stake < minStake", async () => {
      const { fund, organizer, params } = await loadFixture(deployFundFixture);
      await expect(
        fund
          .connect(organizer)
          .createEvent(
            params.fundingGoal,
            params.deadline,
            params.minStake,
            8000n,
            params.ticketPrice,
            100n,
            2n,
            { value: ethers.parseEther("0.5") },
          ),
      ).to.be.revertedWithCustomError(fund, "BadParam");
    });

    it("TC7: Fail if deadline in past", async () => {
      const { fund, organizer, params } = await loadFixture(deployFundFixture);
      await expect(
        fund
          .connect(organizer)
          .createEvent(
            params.fundingGoal,
            (await time.latest()) - 1,
            params.minStake,
            8000n,
            params.ticketPrice,
            100n,
            2n,
            { value: params.minStake },
          ),
      ).to.be.revertedWithCustomError(fund, "BadParam");
    });

    it("TC8: Fail if invalid params (usedThreshold = 0)", async () => {
      const { fund, organizer, params } = await loadFixture(deployFundFixture);
      await expect(
        fund
          .connect(organizer)
          .createEvent(
            params.fundingGoal,
            params.deadline,
            params.minStake,
            8000n,
            params.ticketPrice,
            100n,
            0n,
            { value: params.minStake },
          ),
      ).to.be.revertedWithCustomError(fund, "BadParam");
    });
  });

  // ---------------------------------------------------------
  // 3. NHÓM HUY ĐỘNG VỐN (TC9 - TC13)
  // ---------------------------------------------------------
  describe("Group 3: contribute()", () => {
    it("TC9 & TC10: Success contribute and transition to Funded", async () => {
      const { fund, donator1, eventId, params } = await loadFixture(
        eventCreatedFixture,
      );
      await expect(
        fund
          .connect(donator1)
          .contribute(eventId, { value: params.fundingGoal }),
      ).to.emit(fund, "FundingSuccessful");
    });

    it("TC11: Fail after deadline", async () => {
      const { fund, donator1, eventId, params } = await loadFixture(
        eventCreatedFixture,
      );
      await time.increaseTo(params.deadline + 1);
      await expect(
        fund.connect(donator1).contribute(eventId, { value: 100 }),
      ).to.be.revertedWithCustomError(fund, "FundingClosed");
    });

    it("TC12 & TC13: Fail if status is not Funding", async () => {
      const { fund, organizer, donator1, eventId, params } = await loadFixture(
        eventCreatedFixture,
      );
      await fund
        .connect(donator1)
        .contribute(eventId, { value: params.fundingGoal });
      await fund.connect(organizer).finalizeFunding(eventId);
      await expect(
        fund.connect(donator1).contribute(eventId, { value: 100 }),
      ).to.be.revertedWithCustomError(fund, "NotFunding");
    });
  });

  // ---------------------------------------------------------
  // 4. NHÓM CHỐT VỐN & BÁN VÉ (TC14 - TC17)
  // ---------------------------------------------------------
  describe("Group 4: Finalize & Ticketing", () => {
    it("TC14 & TC15: finalizeFunding() logic", async () => {
      const { fund, organizer, eventId, params } = await loadFixture(
        eventCreatedFixture,
      );
      await time.increaseTo(params.deadline + 1);
      await expect(fund.connect(organizer).finalizeFunding(eventId)).to.emit(
        fund,
        "FundingFinalized",
      );
    });

    it("TC16 & TC17: startTicketing() and maxTickets check", async () => {
      const { fund, donator1, organizer, eventId, params } = await loadFixture(
        eventCreatedFixture,
      );
      await fund
        .connect(donator1)
        .contribute(eventId, { value: params.fundingGoal });
      await fund.connect(organizer).finalizeFunding(eventId);
      await expect(
        fund.connect(organizer).startTicketing(eventId, 0, 10),
      ).to.emit(fund, "TicketingStarted");
      await expect(
        fund.connect(organizer).startTicketing(eventId, 10, 101),
      ).to.be.revertedWithCustomError(fund, "ExceedsMaxTickets");
    });
  });

  // ---------------------------------------------------------
  // 5. NHÓM DOANH THU & CHIA THƯỞNG (TC18 - TC22)
  // ---------------------------------------------------------
  describe("Group 5: Revenue & Rewards", () => {
    it("TC18-TC22: Full flow Release and Claim Reward", async () => {
      const {
        fund,
        organizer,
        donator1,
        admin,
        buyer,
        eventId,
        params,
        ticket,
      } = await loadFixture(eventCreatedFixture);

      // 1. Đóng góp đủ tiền để đạt goal
      await fund
        .connect(donator1)
        .contribute(eventId, { value: params.fundingGoal });

      // 2. Chốt funding
      await fund.connect(organizer).finalizeFunding(eventId);

      // 3. Bắt đầu bán vé (Vé sẽ được mint cho organizer)
      await fund.connect(organizer).startTicketing(eventId, 0, 10);

      // 4. Mua vé (Lúc này organizer đã có ORGANIZER_ROLE nên sẽ thành công)
      await ticket
        .connect(buyer)
        .purchaseTicket(1, { value: params.ticketPrice });
      await ticket
        .connect(buyer)
        .purchaseTicket(2, { value: params.ticketPrice });

      // 5. Đánh dấu vé đã sử dụng (Sử dụng admin có VERIFIER_ROLE)
      await ticket.connect(admin).markAsUsed(1);
      await ticket.connect(admin).markAsUsed(2);

      // 6. Kiểm tra điều kiện hoàn thành (Threshold = 2)
      await fund.connect(organizer).setCompletedIfThresholdMet(eventId);

      // 7. Giải ngân doanh thu
      await expect(fund.connect(organizer).releaseRevenue(eventId)).to.emit(
        fund,
        "RevenueReleased",
      );

      // 8. Kiểm tra rút thưởng cho donator
      const balanceBefore = await ethers.provider.getBalance(donator1.address);
      // donator1 claim thưởng từ doanh thu bán vé
      await fund.connect(donator1).claimReward(eventId);
      const balanceAfter = await ethers.provider.getBalance(donator1.address);

      expect(balanceAfter).to.be.gt(balanceBefore);
    });
  });

  // ---------------------------------------------------------
  // 6. NHÓM HOÀN TIỀN & BẢO MẬT (TC23 - TC31)
  // ---------------------------------------------------------
  describe("Group 6: Refunds & Security", () => {
    it("TC23 & TC24: Refund and double claim block", async () => {
      const { fund, donator1, organizer, eventId, params } = await loadFixture(
        eventCreatedFixture,
      );
      await fund.connect(donator1).contribute(eventId, { value: 500 });
      await time.increaseTo(params.deadline + 1);
      await fund.connect(organizer).finalizeFunding(eventId);

      await expect(
        fund.connect(donator1).claimContributionRefund(eventId),
      ).to.changeEtherBalance(donator1, 500);
      await expect(
        fund.connect(donator1).claimContributionRefund(eventId),
      ).to.be.revertedWithCustomError(fund, "NothingToClaim");
    });

    it("TC25: applyPenalty() logic", async () => {
      const { fund, admin, eventId } = await loadFixture(eventCreatedFixture);
      await expect(fund.connect(admin).applyPenalty(eventId, 5000, 1)).to.emit(
        fund,
        "PenaltyApplied",
      );
    });

    it("TC27, 28, 29: Stake withdrawal constraints", async () => {
      const { fund, organizer, stranger, eventId, params } = await loadFixture(
        eventCreatedFixture,
      );
      await expect(
        fund.connect(organizer).withdrawStake(eventId),
      ).to.be.revertedWithCustomError(fund, "Unsafe");
      await time.increaseTo(params.deadline + 1);
      await fund.connect(organizer).finalizeFunding(eventId);
      await expect(
        fund.connect(stranger).withdrawStake(eventId),
      ).to.be.revertedWithCustomError(fund, "NotOrganizer");
      await expect(
        fund.connect(organizer).withdrawStake(eventId),
      ).to.changeEtherBalance(organizer, params.minStake);
    });

    it("TC31: Block release if usedThreshold not met", async () => {
      const { fund, organizer, donator1, eventId, params, ticket } =
        await loadFixture(eventCreatedFixture);
      await fund
        .connect(donator1)
        .contribute(eventId, { value: params.fundingGoal });
      await fund.connect(organizer).finalizeFunding(eventId);
      const ts = await getContractSigner(ticket.target);
      await fund.connect(ts).depositTicketRevenue(eventId, { value: 100 });

      // Revert vì chưa đạt Threshold
      await expect(
        fund.connect(organizer).releaseRevenue(eventId),
      ).to.be.revertedWithCustomError(fund, "NotCompleted");
    });

    it("TC30: Reentrancy check (NothingToClaim)", async () => {
      const { fund, donator1, eventId } = await loadFixture(
        eventCreatedFixture,
      );
      await expect(
        fund.connect(donator1).claimReward(eventId),
      ).to.be.revertedWithCustomError(fund, "NothingToClaim");
    });
  });
});

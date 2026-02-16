# Marketplace.sol – Quick Fixes (Royalty → Fund Escrow) (Phase 1)

Ngày cập nhật: 2026-02-16

Tài liệu này ghi lại các thay đổi quick-fix để đồng bộ `Marketplace.sol` với `Fund.sol` và `Ticket.sol`, tập trung vào bug critical: **royalty bị gửi “mù” vào Fund** và không hạch toán theo `eventId`.

---

## 1) Vấn đề gốc (trước khi fix)

### 1.1. Royalty gửi vào Fund nhưng không biết thuộc event nào
- Trong `Marketplace.buyListing()` trước đây:
  - Tính `royaltyAmount` rồi `_safeTransferETH(fundContract, royaltyAmount)`.
- `Fund` nhận được ETH nhưng **không có cách biết** số tiền đó thuộc `eventId` nào.
- Hậu quả:
  - Sai accounting escrow theo event.
  - Dễ gây “cross-event contamination”: payout của event A có thể dùng tiền royalty của event B.

---

## 2) Các fix đã thực hiện

### 2.1. Marketplace deposit royalty vào Fund theo `eventId` (CRITICAL)
**Fix trong `contracts/contracts/Marketplace.sol`:**
- Import `IFund`.
- Trong `buyListing(listingId)`, bước trả royalty:
  - Thay vì gửi ETH trực tiếp vào `fundContract`, gọi:

```solidity
IFund(fundContract).depositRoyalty{value: royaltyAmount}(listing.eventId);
```

**Ý nghĩa:**
- Royalty được ghi nhận đúng eventId trên Fund.
- Fund có thể cộng royalty vào escrow của event và phân phối khi `releaseRevenue()`.

---

### 2.2. Fund thêm cơ chế nhận royalty có kiểm soát (CRITICAL)
**Fix trong `contracts/contracts/Fund.sol`:**
- Thêm state `address public marketplace`.
- Thêm `setMarketplaceContract(address marketplaceAddr)` (admin-only) để đăng ký marketplace.
- Thêm `depositRoyalty(uint256 eventId) external payable`:
  - Chỉ marketplace đã đăng ký mới gọi được.
  - Cộng `msg.value` vào `events_[eventId].escrowedRevenue`.
  - Emit event `RoyaltyDeposited`.

**Ý nghĩa:**
- Fund không nhận royalty từ “bất kỳ ai” (giảm rủi ro spam/nhầm lẫn).
- Royalty trở thành một phần revenue của event và được phân phối cùng flow `releaseRevenue()`.

---

### 2.3. Đồng bộ IFund interface
**Fix trong `contracts/contracts/shared/IFund.sol`:**
- Thêm:
  - `setMarketplaceContract(address marketplaceAddr)`
  - `depositRoyalty(uint256 eventId) external payable`

---

## 3) Checklist cấu hình để flow resale + royalty chạy

1) Deploy `Fund`, `Ticket`, `Marketplace`.
2) Admin gọi:
   - `Fund.setTicketContract(ticketAddress)`
   - `Ticket.setFundContract(fundAddress)`
   - `Fund.setMarketplaceContract(marketplaceAddress)`  ← bắt buộc để `depositRoyalty()` không revert
3) Khi `Marketplace.buyListing()` chạy:
   - Royalty sẽ được deposit vào Fund theo `listing.eventId`.
4) Khi organizer gọi `Fund.releaseRevenue(eventId)`:
   - Revenue = `escrowedRevenue` (bao gồm primary sales từ Ticket + royalty từ Marketplace).

---

## 4) Những điểm còn thiếu / cần fix tiếp

- Nếu bạn muốn tách riêng “ticket primary revenue” và “royalty revenue” (analytics/off-chain), có thể tạo 2 biến escrow riêng trong Fund.
- Marketplace vẫn phụ thuộc vào `Ticket.isTransferable(tokenId)` để list; hiện `Ticket.isTransferable()` đã được quick-fix để trả `true` khi status `Sold`.

---

## 5) File liên quan

- Marketplace implementation: `contracts/contracts/Marketplace.sol`
- Fund implementation: `contracts/contracts/Fund.sol`
- Fund interface: `contracts/contracts/shared/IFund.sol`

# Fund.sol – Quick Fixes (Escrow + Refund Paths) (Phase 1)

Ngày cập nhật: 2026-02-16

Tài liệu này ghi lại các thay đổi quick-fix mới nhất trong:
- `contracts/contracts/Fund.sol`
- `contracts/contracts/shared/IFund.sol`
- và phần đồng bộ liên quan trong `contracts/contracts/Ticket.sol`

Mục tiêu là gỡ các **critical bugs** khiến flow Fund ↔ Ticket không chạy được hoặc làm **kẹt tiền**.

---

## 1) Vấn đề gốc (trước khi fix)

### 1.1. `releaseRevenue()` gãy vì Fund không có tiền thật
- `Fund.releaseRevenue(eventId)` lấy `totalRevenue = Ticket.getTotalRevenue(eventId)` rồi cố payout từ **ETH balance của Fund**.
- Nhưng `Ticket.purchaseTicket()` trước đó **không forward ETH sang Fund**.
- Kết quả: `releaseRevenue()` thường revert do Fund không đủ balance (hoặc trả bằng tiền “khác event/khác nguồn”).

### 1.2. Kẹt tiền: donator không refund được khi event Cancelled
- `finalizeFunding()` có thể set event → `Cancelled`.
- Nhưng Fund không có đường để donator lấy lại contribution (vốn nằm trong Fund).

### 1.3. Kẹt stake organizer
- `organizerStakeLocked` bị lock nhưng không có đường hoàn trả rõ ràng sau khi event kết thúc/cancel.

### 1.4. Mint tickets chỉ chạy được 1 lần
- `startTicketing()` set status → `Ticketing`.
- Nhưng lần gọi tiếp theo yêu cầu status `Funded` ⇒ không thể mint nhiều batch.

---

## 2) Các fix đã thực hiện

### 2.1. Escrow theo `eventId`: `depositTicketRevenue(eventId)` (CRITICAL)
**Fix:** thêm hàm mới vào Fund và interface:

- Trong `contracts/contracts/shared/IFund.sol`:
  - `depositTicketRevenue(uint256 eventId) external payable;`

- Trong `contracts/contracts/Fund.sol`:
  - Thêm field `escrowedRevenue` trong `EventConfig`.
  - Implement `depositTicketRevenue(eventId)`:
    - `onlyTicket` (chỉ Ticket contract gọi)
    - cộng `msg.value` vào `events_[eventId].escrowedRevenue`
    - emit `TicketRevenueDeposited`

**Ý nghĩa:**
- ETH từ vé primary được đưa vào đúng “escrow của event” trong Fund.
- Giảm rủi ro cross-event contamination.

---

### 2.2. `releaseRevenue()` dùng escrow thật thay vì `Ticket.getTotalRevenue()` (CRITICAL)
**Fix:** trong `Fund.releaseRevenue(eventId)`:
- `totalRevenue = e.escrowedRevenue` (thay vì gọi Ticket)
- sau đó set `e.escrowedRevenue = 0` để “consume escrow” (chống release 2 lần)

**Ý nghĩa:**
- Payout đúng theo nguồn tiền thật.
- Không phụ thuộc vào số liệu thống kê trong Ticket.

---

### 2.3. Đồng bộ Ticket để deposit theo eventId
**Fix trong `Ticket.sol`:**
- `purchaseTicket()` gọi `IFund(fundContract).depositTicketRevenue{value: ticket.price}(ticket.eventId)`.

**Tác động:**
- Fund nhận được ETH đúng eventId.

---

### 2.4. Cho phép mint nhiều batch trong `startTicketing()`
**Fix:**
- `startTicketing()` cho phép gọi khi status là `Funded` **hoặc** `Ticketing`.
- Chỉ set `status = Ticketing` nếu trước đó là `Funded`.

**Ý nghĩa:**
- Organizer có thể mint nhiều đợt cho cùng event (vẫn enforce `maxTickets`).

---

### 2.5. Refund contribution cho donator khi event `Cancelled` (CRITICAL)
**Fix:** thêm hàm mới:
- `claimContributionRefund(uint256 eventId)`

**Logic:**
- Chỉ cho phép nếu `e.status == Cancelled`
- refund theo `amount = e.shareOf[msg.sender]` (vì 1 wei = 1 share)
- set `shareOf[msg.sender] = 0`, giảm `totalShares`, reset `rewardDebt/pending`
- transfer ETH về user
- emit `ContributionRefunded`

**Ý nghĩa:**
- Donators có đường rút tiền khi funding thất bại.

---

### 2.6. Rút stake organizer để tránh kẹt tiền
**Fix:** thêm hàm mới:
- `withdrawStake(uint256 eventId)`

**Rule hiện tại:**
- Cho rút stake nếu:
  - `Cancelled` và đã `sharesFinalized`
  - hoặc `Completed` và đã quyết định settlement: `revenueReleased || refundsEnabled`

**Ý nghĩa:**
- Stake không bị kẹt vĩnh viễn.

---

### 2.7. Đồng bộ Ticket minting với Fund
**Fix trong `Ticket.sol`:**
- `mintBatch()` cho phép `msg.sender == fundContract` (ngoài admin/organizer role) để `Fund.startTicketing()` mint được.

---

## 3) API mới / thay đổi quan trọng

**Fund.sol / IFund.sol**
- Mới: `depositTicketRevenue(uint256 eventId) external payable`
- Mới: `claimContributionRefund(uint256 eventId) external`
- Mới: `withdrawStake(uint256 eventId) external`
- Thay đổi hành vi: `releaseRevenue()` lấy tiền từ `escrowedRevenue`.
- Thay đổi hành vi: `startTicketing()` cho phép mint nhiều batch.

**Ticket.sol**
- `purchaseTicket()` deposit vào Fund theo `eventId`.
- `mintBatch()` cho phép `msg.sender == fundContract`.

---

## 4) Checklist cấu hình để flow chạy được

1) Deploy `Fund` và `Ticket`.
2) Admin gọi:
   - `Fund.setTicketContract(ticketAddress)`
   - `Ticket.setFundContract(fundAddress)`
3) Admin cấp role cho organizer/verifier (Ticket side):
   - `grantRole(ORGANIZER_ROLE, organizerAddress)`
   - `grantRole(VERIFIER_ROLE, verifierAddress)`
4) Funding + ticketing:
   - organizer: `Fund.createEvent()` (kèm stake)
   - donators: `Fund.contribute()`
   - organizer/admin: `Fund.finalizeFunding()`
   - organizer: `Fund.startTicketing()` (mint)
5) Primary sale:
   - buyer: `Ticket.purchaseTicket(tokenId)` → Fund nhận ETH qua `depositTicketRevenue(eventId)`
6) Completed + release:
   - organizer: `Fund.setCompletedIfThresholdMet()`
   - organizer: `Fund.releaseRevenue()`
   - donators: `Fund.claimReward()`
7) Funding failed:
   - organizer/admin: `Fund.finalizeFunding()` → Cancelled
   - donators: `Fund.claimContributionRefund()`

---

## 5) Những điểm còn thiếu / cần fix tiếp (không nằm trong patch này)

- **Marketplace royalty theo eventId**: Marketplace hiện gửi ETH vào Fund nhưng không gọi hàm có `eventId` ⇒ Fund không thể hạch toán royalty theo event.
  - Nên quick-fix tiếp: Marketplace gọi `depositTicketRevenue(eventId)` (hoặc tách `depositRoyalty(eventId)` nếu muốn phân loại).
- Refund vé end-to-end: Fund có `claimTicketRefund()` (chỉ Ticket gọi) nhưng Ticket chưa có flow gọi refund.
- Shares ERC1155 (token hóa) chưa được triển khai; hiện vẫn dùng `shareOf/totalShares` internal.

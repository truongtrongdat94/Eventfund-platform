# Ticket.sol – Quick Fixes (Phase 1)

Ngày cập nhật: 2026-02-16

Tài liệu này ghi lại các thay đổi đã được sửa nhanh trong `contracts/contracts/Ticket.sol` để gỡ các **blocker/critical bugs** đã phát hiện trong flow Fund ↔ Ticket ↔ Marketplace.

## 1) Mục tiêu của bản fix

- Làm cho Ticket contract **deploy được và dùng được** (quản trị role hoạt động).
- Mở được vòng đời ticket cơ bản: **mint → purchase → used/expired/refunded**.
- Tránh tình trạng **tiền vé bị kẹt** trong Ticket (forward sang Fund).
- Làm cho Marketplace có thể **list** ticket (bằng `isTransferable`).
- Emit đủ events theo interface để backend/indexer sync được.

## 2) Các thay đổi đã thực hiện

### 2.1. Fix AccessControl: cấp `DEFAULT_ADMIN_ROLE` khi deploy (BLOCKER)
**Vấn đề:** trước đây `Ticket` không grant `DEFAULT_ADMIN_ROLE` cho bất kỳ ai ⇒ không ai cấp được `ORGANIZER_ROLE`/`VERIFIER_ROLE` ⇒ các hàm `mintBatch()/markAsUsed()/markAsExpired()/markAsRefunded()` coi như không thể dùng.

**Fix:** trong constructor:
- Grant `DEFAULT_ADMIN_ROLE` cho deployer/platform EOA (`msg.sender`).

**Tác động:**
- Admin có thể set role cho organizer/verifier và cấu hình các tham số khác.

---

### 2.2. Thêm Fund wiring + forward doanh thu vé (CRITICAL)
**Vấn đề:** `purchaseTicket()` thu ETH nhưng không chuyển đi đâu ⇒ doanh thu vé bị **kẹt vĩnh viễn** trong Ticket; trong khi `Fund.releaseRevenue()` lại cố chi tiền từ balance của Fund ⇒ flow giải ngân bị gãy.

**Fix:**
- Thêm state `address public fundContract`.
- Thêm hàm quản trị `setFundContract(address fund)` (admin-only).
- Trong `purchaseTicket()`:
  - Require `fundContract != address(0)`.
  - Sau khi bán thành công, **forward** `ticket.price` sang `fundContract` bằng low-level call.

**Thay đổi API (mới):**
- `setFundContract(address fund)`
- Event: `FundContractSet(address fund)`

**Lưu ý:** hiện tại Ticket forward bằng `payable(fundContract).call{value: ticket.price}("")`.
- Điều này yêu cầu Fund phải có `receive()` hoặc fallback payable (Fund hiện có `receive() external payable {}`).
- Nếu sau này bạn muốn hạch toán escrow theo `eventId` (khuyến nghị), Fund nên có hàm `deposit(eventId)` payable để Marketplace/Ticket gọi đúng event.

---

### 2.3. Fix blocker `salesActive`: bật bán được (BLOCKER)
**Vấn đề:** `EventTicketInfo.salesActive` mặc định `false` và trước đó **không có hàm nào set true** ⇒ `mintBatch()` và `purchaseTicket()` luôn revert `SalesInactive()`.

**Fix:**
- Thêm hàm `setSalesActive(uint256 eventId, bool active)`.
- Auto-activate `salesActive = true` khi mint batch đầu tiên cho event.

**Thay đổi API (mới):**
- `setSalesActive(uint256 eventId, bool active)`

**Authorization hiện tại (quick fix):**
- Admin có thể set cho mọi event.
- `eventOrganizer[eventId]` (được set từ lần mint đầu) cũng có thể set.

---

### 2.4. Track organizer theo `eventId`
**Mục đích:** có một mốc “ai là organizer” để làm authorization tối thiểu cho `setSalesActive`.

**Fix:**
- Thêm `mapping(uint256 => address) public eventOrganizer`.
- Set organizer ở lần mint đầu: `eventOrganizer[eventId] = to`.
- Nếu lần mint sau `to` khác organizer ban đầu ⇒ revert.

---

### 2.5. Fix Marketplace blocker: implement `isTransferable()`
**Vấn đề:** Marketplace yêu cầu `ticketContract.isTransferable(tokenId)` nhưng Ticket trước đó luôn `return false` ⇒ Marketplace không list được.

**Fix:**
- `isTransferable(tokenId)` trả về `true` khi status là `Sold`.

**Ý nghĩa:**
- Ticket chỉ được list resale sau khi đã bán primary.
- Ticket `Used/Expired/Refunded` không thể transfer vì đã chặn ở `_update()`.

---

### 2.6. Emit đủ events theo `ITicket` (MEDIUM, sync/indexing)
**Vấn đề:** interface [contracts/contracts/shared/ITicket.sol](../contracts/shared/ITicket.sol) định nghĩa `TicketUsed/TicketExpired/TicketRefunded` nhưng implementation trước đó không emit ⇒ backend listener sync thiếu dữ liệu.

**Fix:** emit events tương ứng trong:
- `markAsUsed()` → emit `TicketUsed(...)`
- `markAsExpired()` → emit `TicketExpired(...)`
- `markAsRefunded()` → emit `TicketRefunded(...)`

**Lưu ý:** `TicketRefunded.refundAmount` hiện emit `0` vì payout refund thực tế đang ở Fund; sau này khi flow refund hoàn chỉnh (Ticket gọi Fund để refund), bạn có thể emit đúng amount.

---

### 2.7. Giảm rủi ro “mua cưỡng bức” (HIGH)
**Bối cảnh:** OpenZeppelin ERC721 `_transfer/_safeTransfer` nội bộ **không check approvals** ("imposes no restrictions on msg.sender"). Nếu ticket ở trạng thái `Minted` nhưng đang nằm trong ví nào đó, `purchaseTicket()` có thể chuyển NFT khỏi ví đó mà không cần approval.

**Fix quick:**
- Trong `purchaseTicket()`, chỉ cho mua primary nếu `seller = ownerOf(tokenId)` đang có `ORGANIZER_ROLE`.

**Ý nghĩa:**
- Primary sale chỉ diễn ra từ ví inventory (organizer) đã được cấp role.

## 3) Checklist deploy/cấu hình để chạy được

1) Deploy `Fund` và `Ticket`.
2) Admin (deployer) gọi:
   - `Fund.setTicketContract(ticketAddress)`
   - `Ticket.setFundContract(fundAddress)`
3) Admin cấp role:
   - `Ticket.grantRole(ORGANIZER_ROLE, organizerAddress)`
   - `Ticket.grantRole(VERIFIER_ROLE, verifierAddress)`
4) Organizer chạy flow:
   - Fund: `createEvent()` → `contribute()` → `finalizeFunding()` → `startTicketing()`
   - Ticket: buyers `purchaseTicket(tokenId)`
   - Verifier: `markAsUsed(tokenId)`

## 4) Những gì CHƯA giải quyết (cố ý để phase sau)

- Fund chưa có escrow accounting theo `eventId` (Ticket đang forward ETH nhưng Fund chưa ghi nhận theo event).
- Refund end-to-end chưa khép vòng (Ticket chưa gọi Fund.claimTicketRefund()).
- Authorization cho `mintBatch()` hiện là quick fix (admin/organizer role); chuẩn hơn là Fund làm minter duy nhất hoặc module hóa rõ hơn.

## 5) File liên quan

- Ticket implementation: `contracts/contracts/Ticket.sol`
- Ticket interface: `contracts/contracts/shared/ITicket.sol`
- Fund implementation: `contracts/contracts/Fund.sol`

## Cách chạy Test

Mở terminal tại thư mục gốc của dự án và thực hiện các lệnh:

```bash
cd contracts
npx hardhat test test/Fund.test.js
npx hardhat test test/Marketplace.test.js
npx hardhat test test/Ticket.test.js
npx hardhat test
```

# Fund.sol Test Cases

### 1. Nhóm Admin & Cấu hình (4 Test Cases)

- **TC1**: Kiểm tra chỉ Admin mới có quyền `setTicketContract`.
- **TC2**: Kiểm tra chỉ Admin mới có quyền `setMarketplaceContract`.
- **TC3**: Kiểm tra lỗi khi địa chỉ contract được set là `address(0)`.
- **TC4**: Kiểm tra quyền nạp tiền vào Escrow (Chỉ Ticket và Marketplace được phép).

### 2. Nhóm Khởi tạo Sự kiện - createEvent() (4 Test Cases)

- **TC5**: Tạo event thành công và khóa đúng số tiền Stake.
- **TC6**: Lỗi nếu tiền gửi vào thấp hơn `minStakeRequired`.
- **TC7**: Lỗi nếu `fundingDeadline` nằm trong quá khứ hoặc bằng hiện tại.
- **TC8**: Lỗi nếu các tham số như `fundingGoal` hoặc `usedThreshold` không hợp lệ.

### 3. Nhóm Huy động vốn - contribute() (5 Test Cases)

- **TC9**: Góp vốn thành công, tăng `totalShares` và `shareOf` theo tỷ lệ 1:1.
- **TC10**: Tự động chuyển trạng thái sang `Funded` khi đạt mục tiêu (`fundingGoal`).
- **TC11**: Lỗi khi góp vốn vào event đã quá hạn (`FundingClosed`).
- **TC12**: Lỗi khi góp vốn vào event đã bị hủy hoặc đã hoàn tất.
- **TC13**: Lỗi khi `sharesFinalized` đã được bật (không cho góp thêm).

### 4. Nhóm Chốt vốn & Bán vé (4 Test Cases)

- **TC14**: `finalizeFunding()` chuyển trạng thái sang `Cancelled` nếu không đạt goal sau deadline.
- **TC15**: `finalizeFunding()` chốt thành công nếu đạt goal (kể cả trước deadline).
- **TC16**: `startTicketing()` gọi hàm mint từ `Ticket.sol` thành công.
- **TC17**: Lỗi nếu mint vé vượt quá `maxTickets`.

### 5. Nhóm Doanh thu & Chia thưởng (5 Test Cases)

- **TC18**: `depositTicketRevenue()` hạch toán chính xác doanh thu theo từng `eventId`.
- **TC19**: `depositRoyalty()` hạch toán tiền bản quyền từ Marketplace vào doanh thu event.
- **TC20**: `releaseRevenue()` tính toán và chia tiền chính xác (5% phí sàn, % của Organizer, phần còn lại cho Donators).
- **TC21**: Kiểm tra cập nhật `accRewardPerShare` sau khi giải ngân doanh thu.
- **TC22**: `claimReward()` cho phép Donator rút đúng số tiền thưởng được chia.

### 6. Nhóm Hoàn tiền & Bảo mật (9 Test Cases)

- **TC23**: `claimContributionRefund()` hoàn tiền 100% cho Donator nếu event bị `Cancelled`.
- **TC24**: **Security**: Chặn rút tiền vốn lần 2 (Double-refund).
- **TC25**: `applyPenalty()` cắt tiền stake của Organizer chuyển vào pool refund thành công.
- **TC26**: **Security**: Chặn rút tiền thưởng khi chưa có doanh thu giải ngân.
- **TC27**: `withdrawStake()` cho phép Organizer rút lại tiền stake sau khi event kết thúc an toàn.
- **TC28**: **Security**: Chặn Organizer rút stake sớm khi event đang diễn ra (`Unsafe`).
- **TC29**: **Security**: Chặn người lạ rút stake thay cho Organizer.
- **TC30**: **Security**: Kiểm tra `nonReentrant` trên các hàm rút tiền (`claimReward`, `claimContributionRefund`).
- **TC31**: **Security**: Chặn `releaseRevenue` nếu event chưa đạt ngưỡng sử dụng vé (`usedThreshold`).

---

# Ticket.sol Test Cases

### 1. Nhóm Cấu hình & Quyền hạn (Admin & Setup)

- **TC1**: Cấu hình Fund Contract: Kiểm tra chỉ ví có quyền Admin (`DEFAULT_ADMIN_ROLE`) mới có thể đặt địa chỉ hợp đồng Fund.
- **TC2**: Chặn địa chỉ rỗng: Revert nếu cố tình đặt địa chỉ Fund là `address(0)`.
- **TC3**: Quản lý trạng thái bán (`SalesActive`): Kiểm tra xem Admin hoặc đúng Organizer có thể bật/tắt quyền bán vé hay không.
- **TC4**: Kiểm tra phân quyền (`Access Control`): Đảm bảo người lạ (stranger) không thể gọi các hàm quản trị hoặc mint vé.

### 2. Nhóm Mint vé (Minting Batch)

- **TC5**: Mint thành công: Kiểm tra hợp đồng Fund (hoặc Admin/Organizer) gọi `mintBatch` thành công, vé được tạo đúng số lượng và chủ sở hữu.
- **TC6**: Tự động kích hoạt Sales: Xác nhận rằng ở lần mint đầu tiên (`totalMinted == 0`), hệ thống tự động chuyển trạng thái `salesActive` sang `true`.
- **TC7**: Ràng buộc Organizer duy nhất: Trong một sự kiện, nếu đợt mint đầu tiên đã gán cho ví A, thì đợt mint sau không được phép gán cho ví B.
- **TC8**: Chặn Mint khi Sales ngưng: Kiểm tra nếu trạng thái bán đang tắt (`salesActive = false`), các đợt mint sau phải bị từ chối.
- **TC9**: Giới hạn dữ liệu: Revert nếu giá vé (`price`) hoặc số lượng (`quantity`) bằng 0.

### 3. Nhóm Mua vé (Purchase Ticket)

- **TC10**: Mua sơ cấp thành công: Người dùng mua vé từ Organizer thành công. Trạng thái sang `Sold`, NFT sang Buyer, tiền đẩy về Fund.
- **TC11**: Trả lại tiền thừa: Nếu người mua gửi thừa tiền, hợp đồng phải hoàn lại tiền dư.
- **TC12**: Thanh toán thiếu: Revert lỗi `InsufficientPayment` nếu số tiền gửi nhỏ hơn giá vé.
- **TC13**: Chặn mua lại vé đã bán: Không được phép mua vé đã có trạng thái `Sold`.
- **TC14**: Bảo mật nguồn bán: Kiểm tra lỗi `InvalidTicketStatus` nếu người sở hữu hiện tại của vé không phải là organizer.

### 4. Nhóm Sử dụng & Trạng thái (Usage & Status)

- **TC15**: Check-in (`markAsUsed`): Chỉ ví có quyền `VERIFIER_ROLE` mới có thể xác nhận vé đã dùng.
- **TC16**: Hết hạn (`markAsExpired`): Chuyển trạng thái vé sang `Expired`.
- **TC17**: Hoàn tiền (`markAsRefunded`): Chuyển trạng thái vé sang `Refunded`.
- **TC18**: Chặn Check-in vé chưa bán: Không được phép check-in vé đang ở trạng thái `Minted`.

### 5. Nhóm Chuyển nhượng & Bảo mật (Security)

- **TC19**: Chặn chuyển nhượng vé đặc biệt: Kiểm tra vé đã `Used`, `Expired` hoặc `Refunded` bị cấm `transfer`.
- **TC20**: Tính khả dụng (`isTransferable`): Hàm này trả về `true` chỉ khi vé đã được mua (`Sold`) và chưa được sử dụng.
- **TC21**: Kiểm tra Enumerable: Đảm bảo các hàm liệt kê vé (`tokenOfOwnerByIndex`) hoạt động chính xác.

### 6. Nhóm Tích hợp & View (Integration)

- **TC22**: Thống kê (`getUsageStats`): Kiểm tra tính toán `usageRatio` chính xác.
- **TC23**: Doanh thu (`getTotalRevenue`): Kiểm tra tổng số tiền thu được ghi nhận trên Ticket khớp với thực tế đẩy sang Fund.

---

# Marketplace.sol Test Cases

### 1. Nhóm Cấu hình & Quyền hạn (Admin & Setup)

- **TC1**: Khởi tạo hợp đồng: Kiểm tra constructor lưu đúng địa chỉ Ticket, Fund và tỷ lệ `RoyaltyBps` ban đầu.
- **TC2**: Cập nhật Royalty thành công: Chỉ Owner mới có thể thay đổi phí tác quyền.
- **TC3**: Cập nhật Royalty thất bại: Revert nếu giá trị bps > 10,000 (100%) hoặc người gọi không phải Owner.
- **TC4**: Thay đổi địa chỉ Fund: Đảm bảo chỉ Admin mới có thể thay đổi địa chỉ `fundContract` nhận phí bản quyền.

### 2. Nhóm Niêm yết vé (Create Listing)

- **TC5**: Niêm yết thành công: Kiểm tra NFT được chuyển từ người bán sang Marketplace và trạng thái Listing là `Active`.
- **TC6**: Kiểm tra Price Cap (150%):
  - Giá bán = 150% giá gốc => Thành công.
  - Giá bán = 151% giá gốc => Revert `PriceExceedsCap`.
- **TC7**: Quyền sở hữu: Revert `NotTicketOwner` nếu cố niêm yết vé của người khác.
- **TC8**: Trạng thái vé (`isTransferable`): Revert `TicketNotTransferable` nếu vé đã được sử dụng (`Used`) hoặc hết hạn.
- **TC9**: Chặn niêm yết trùng: Một vé đang treo trên sàn không được phép tạo thêm listing thứ hai.
- **TC10**: Giá bằng 0: Revert `PriceIsZero` nếu người bán đặt giá 0.

### 3. Nhóm Mua vé (Buy Listing)

- **TC11**: Mua thành công & Chia tiền: Kiểm tra luồng tiền:
  - Người bán nhận: Giá bán - Phí tác quyền.
  - Fund nhận: Phí tác quyền.
  - NFT chuyển sang ví Buyer.
- **TC12**: Sai số tiền thanh toán: Revert `IncorrectPayment` nếu Buyer gửi thiếu hoặc thừa ETH.
- **TC13**: Tự mua vé của mình: Revert `SelfBuyNotAllowed`.
- **TC14**: Mua listing không hoạt động: Revert `ListingNotActive` nếu listing đã được bán hoặc đã bị hủy trước đó.
- **TC15**: Tích hợp nạp Royalty: Đảm bảo hàm `depositRoyalty` của Fund được gọi đúng `eventId`.

### 4. Nhóm Hủy niêm yết (Cancel Listing)

- **TC16**: Hủy thành công: Người bán nhận lại NFT, trạng thái listing chuyển sang `Cancelled`.
- **TC17**: Quyền hủy: Chỉ người bán mới có quyền hủy.
- **TC18**: Hủy khi đã bán: Revert `ListingNotActive` nếu vé đã được giao dịch xong.

### 5. Nhóm Kỹ thuật & Bảo mật (Technical & Security)

- **TC19**: Chống Reentrancy: Kiểm tra hàm `buyListing` không thể bị tấn công tái nhập (`nonReentrant`).
- **TC20**: Nhận NFT (`IERC721Receiver`): Kiểm tra Marketplace có trả về đúng selector `onERC721Received`.
- **TC21**: Lỗi chuyển ETH: Kiểm tra lỗi `EthTransferFailed` khi ví người bán không nhận được tiền.

### 6. Nhóm Truy vấn (View Functions)

- **TC22**: `getListing`: Trả về đúng thông tin struct `Listing`.
- **TC23**: `getActiveListingByTokenId`: Trả về đúng `listingId` hiện tại hoặc 0 nếu không có.
- **TC24**: `getListingCount`: Đếm đúng tổng số listing đã từng được tạo.

# Kiểm tra tích hợp StaffMobile ↔ RunnerMobile

## Chuẩn bị

- Backend đang chạy; hai app trỏ cùng API.
- Một volunteer đã LinkUser và Active tại giải A, thêm giải B nếu muốn kiểm tra chọn nhiều giải.
- Một runner confirmed có BIB/QR tại A; một vé ở B; một hồ sơ chưa confirmed.
- Mỗi lần check-in thành công thay đổi dữ liệu thật, nên dùng dữ liệu thử.

## Các bước trên thiết bị

1. Đăng nhập volunteer → thấy giải A và đúng quầy/trạm. Mở A → roster chỉ chứa runner confirmed.
2. Mở vé runner trên RunnerMobile → quét từ StaffMobile → tên/BIB/cự ly đúng, hiện thành công.
3. Làm mới trang scan-qr UserWeb hoặc chi tiết vé RunnerMobile → cùng checkedInAtUtc.
4. Quét lại cùng vé → đã check-in trước đó; thời điểm không đổi.
5. Quét vé B trong context A → báo sai giải, không gửi check-in sai event.
6. Nhập BIB có số 0 đầu → giữ nguyên BIB. Nhập BIB không tồn tại/chưa confirmed → báo lỗi backend.
7. Từ chối camera → có hướng dẫn và nút quay về nhập BIB; bật quyền trong settings rồi thử lại.
8. Mở camera → chuyển app nền → mở lại → camera hoạt động; thoát màn hình → camera dừng.
9. Tải roster khi online, ngắt mạng rồi check-in một runner khác → chờ đồng bộ; chưa tăng số đã xác nhận.
10. Quét lại offline → một queue item. Đóng/mở lại app bằng cùng tài khoản → queue còn.
11. Đăng xuất khi còn queue → có thông báo. Đăng nhập tài khoản khác → không thấy queue của tài khoản trước.
12. Khôi phục mạng → chờ tối đa 30 giây khi foreground hoặc nhấn đồng bộ → chỉ xác nhận sau HTTP thành công.
13. BTC thu hồi phân công trong lúc offline → đồng bộ báo lỗi, giữ queue và không hiện thành công giả.
14. Phiên hết hạn/HTTP 401 → về đăng nhập, queue được giữ cho đúng tài khoản.

## Phạm vi tự động

- Contract URL, Bearer header và body tương ứng UserWeb/backend.
- Đăng nhập Volunteer, token hết hạn, dẫn xuất username từ JWT backend.
- JSON QR nguyên bản, numeric BIB, sai event, dữ liệu hỏng, QR thanh toán.
- Server alreadyCheckedIn và timestamp đầu tiên.
- Queue offline bền vững, chống trùng, cách ly tài khoản, thiếu cache/runner.
- HTTP business/auth/server errors không fallback offline.
- Đồng bộ giữ nguyên QR, lỗi không bị xóa, phân công bị thu hồi.
- Chống submit đồng thời, dispose khi request chưa hoàn tất.
- Widget đăng nhập và nhập BIB/check-in trên màn hình hẹp.

Camera thật và iOS cần được xác minh trên thiết bị; unit/widget test không thay thế bước này.

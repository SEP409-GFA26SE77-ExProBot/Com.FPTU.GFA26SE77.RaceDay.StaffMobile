# RaceDay StaffMobile

Ứng dụng Flutter cho volunteer / nhân sự được phân công check-in runner. Cấu trúc và theme dùng cùng cách tổ chức với RunnerMobile; API đối chiếu từ UserWeb và Event/IAM backend.

## Cấu trúc

```text
lib/
  core/                 # endpoints, HTTP client, lỗi, JWT, theme
  features/
    authentication/
      data/             # remote/local datasource, model, repository
      domain/           # entity, repository contract, login use case
      presentation/     # controller, splash, login
    home/presentation/  # danh sách giải được phân công
    check_in/
      data/             # API, cache theo tài khoản, hàng đợi offline
      domain/           # model, kiểm tra QR/BIB, repository contract
      presentation/     # controller, màn hình check-in và camera
  shared/widgets/       # logo, button, status panel
test/                   # contract, offline, session và widget tests
```

## Chạy

Yêu cầu Flutter với Dart >= 3.11.5. Android min SDK 23. Có scaffold Android, iOS và Web; build iOS cần macOS/Xcode.

1. Chạy backend ở port 5080 theo README backend.
2. Tạo `.env` từ `.env.example`. Không đưa bí mật vào file này vì được bundle cùng ứng dụng.
3. Cấu hình `API_URL`:
   - Android emulator: `http://10.0.2.2:5080`.
   - Điện thoại thật cùng Wi-Fi: `http://<IP-LAN-máy-chạy-backend>:5080`.
   - Web / iOS simulator: `http://localhost:5080`.
4. Chạy:

```powershell
flutter pub get
flutter run
```

Có thể ghi đè mà không sửa file: `flutter run --dart-define=API_URL=http://192.168.1.10:5080`.

Với Web: `flutter run -d chrome --web-port=5300 --dart-define=API_URL=http://localhost:5080`. Thêm origin này vào `ALLOWS_CORS` của backend. Camera trên trình duyệt cần HTTPS hoặc localhost. Điện thoại thật nên dùng Android app khi phát triển qua HTTP LAN.

Android đã khai báo INTERNET/CAMERA, cho phép HTTP để dùng backend phát triển như RunnerMobile. iOS đã khai báo mô tả quyền camera và local networking; dùng HTTPS khi triển khai thực tế. Bundle ID Android: `vn.raceday.staff_mobile`, cài song song RunnerMobile được.

`android/gradle.properties` tắt Kotlin incremental compilation để tránh lỗi cache native khi Pub cache và dự án nằm khác ổ đĩa trên Windows. Có thể bỏ cấu hình này khi môi trường build không gặp lỗi; xem [tài liệu Kotlin](https://kotlinlang.org/docs/gradle-compilation-and-caches.html).

## Luồng sử dụng

1. BTC thêm volunteer vào nhân sự giải trên UserWeb, liên kết đúng tài khoản và chuyển trạng thái **Active**.
2. Đăng nhập StaffMobile bằng tài khoản đó. App gọi `staff/me` và hiển thị mọi giải được phân công; chọn đúng giải.
3. Runner mở vé đã **confirmed** trên RunnerMobile (có BIB và QR).
4. Volunteer chọn **Quét QR vé runner**, cấp quyền camera và quét. Camera đóng sau một mã; app gửi payload cho backend.
5. Xem tên runner, BIB, cự ly, thời điểm check-in. Quét lại hiển thị **Đã check-in trước đó**, giữ thời điểm máy chủ.
6. Có thể nhập BIB nếu camera không dùng được; tìm kiếm và lọc danh sách theo trạng thái.

IAM role không thay thế quyền tại giải. App không áp dụng bộ lọc Runner từ RunnerMobile: backend quyết định quyền qua staff assignment Active đã LinkUser. Tài khoản không có phân công sẽ thấy hướng dẫn liên hệ BTC. App không lấy danh sách giải công khai hoặc tự chọn giải bất kỳ.

## API

| Thao tác | Endpoint | Nội dung |
| --- | --- | --- |
| Đăng nhập | POST /api/v1/iam/auth/login | `{username,password}` → `accessToken` |
| Phân công | GET /api/v1/event/staff/me | Danh sách assignment Active |
| Danh sách runner | GET /api/v1/event/check-ins?eventId=... | Runner confirmed và trạng thái check-in |
| Quét QR | POST /api/v1/event/check-in | `{eventId,qrPayload}`; qrPayload là chuỗi JSON nguyên bản |
| Nhập BIB | POST /api/v1/event/check-in | `{eventId,bib}` |

Các request nghiệp vụ dùng `Authorization: Bearer <accessToken>`. HTTP 401 xóa phiên và trở về đăng nhập. HTTP 400/403/500 không được chuyển thành check-in offline.

QR RunnerMobile tương thích trực tiếp:
```json
{"user_id":"<runner-id>","bib":"000123","event_id":"<event-id>","distance":"10 KM"}
```

Không gửi đồng thời `bib` và `qrPayload`: backend ưu tiên `bib`, nên giữ QR nguyên bản để kiểm tra event. QR chỉ chứa số BIB cũng được hỗ trợ như UserWeb. Không cần thay đổi backend hoặc RunnerMobile.

## Mất mạng

- Cần mở giải và tải danh sách khi còn mạng trước.
- Chỉ lưu lượt provisional khi BIB có trong danh sách confirmed đã cache. Không xác nhận runner lạ khi offline.
- Nhãn **Chờ đồng bộ** tách riêng với **Đã check-in**; thống kê xác nhận chỉ tính kết quả máy chủ.
- Queue/cache nằm riêng theo user ID; đăng xuất giữ queue nhưng tài khoản khác không đọc/đồng bộ được.
- Thử đồng bộ khi mở app, trở lại app, nhấn làm mới và mỗi 30 giây khi app foreground có queue.
- Khi đồng bộ, gửi nguyên QR (hoặc BIB nhập tay), kiểm tra lại quyền và trạng thái trên backend.
- Chỉ xóa queue sau phản hồi thành công. Lỗi bị từ chối giữ lại kèm lý do, hiển thị trên trang phân công và danh sách runner.
- Thời điểm server xác nhận là `checkedInAtUtc` chính thức. Thời gian lưu offline chỉ mang tính tạm thời; API hiện không nhận timestamp offline.
- Không xóa dữ liệu ứng dụng khi còn queue. Cache trên thiết bị không thể biết ngay các thay đổi quyền/trạng thái trong lúc mất mạng.

## Kiểm tra

```powershell
flutter analyze
flutter test
flutter build apk --debug
flutter build web
```

Kiểm thử tự động dùng HTTP giả lập để không sửa dữ liệu runner thật. Kịch bản thử camera và backend thật nằm ở [docs/check-in-validation.md](docs/check-in-validation.md).

Thư viện camera: [mobile_scanner](https://pub.dev/packages/mobile_scanner). Widget tự quản lý controller/lifecycle, dừng camera khi rời màn hình hoặc app inactive.

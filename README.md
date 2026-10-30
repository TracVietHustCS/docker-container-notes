# Docker và Container notes

Ghi chú tự học về Docker và container cho người làm DevOps: khái niệm, image và Dockerfile, container, volume và mạng, Compose, bảo mật, vận hành và xử lý sự cố. 19 trang, 12 câu luyện tập, tiếng Việt.

Site: https://tracviethustcs.github.io/docker-container-notes/
Trang chủ: https://tracviethustcs.github.io/

Đây là ghi chú tự soạn, không phải tài liệu chính thức của Docker, Inc. Lệnh và giá trị mặc định thay đổi theo phiên bản: đối chiếu docs.docker.com và thử trong môi trường lab.

## Cấu trúc

- `index.html`: trang đã build, một file duy nhất (HTML, CSS, JS), không dùng framework.
- `src/content/*.md`: nội dung từng trang, viết bằng markdown rút gọn.
- `src/build.py`, `src/site.json`, `src/tpl/`: bộ build và cấu hình giao diện.

## Thêm hoặc sửa một trang

1. Mở một file trong `src/content/` (hoặc tạo file `.md` mới; số đầu tên file quyết định thứ tự).
2. Mỗi trang bắt đầu bằng `=== id | Nhóm | Tiêu đề`.
3. Cú pháp: `>> ` là câu dẫn, `## ` và `### ` là tiêu đề, `- ` và `1. ` là danh sách, dòng bắt đầu bằng `|` là bảng (dùng `\|` cho dấu `|` trong ô), khối code bao bằng ba dấu huyền (thêm `ascii` cho sơ đồ), `**đậm**`, `` `code` ``, `[chữ](#id-trang)`.
4. Khối nổi bật: `::: tip Tiêu đề` (hoặc `warn`, `note`, `lab`), nội dung, rồi dòng `:::`.
5. Câu hỏi luyện tập: dòng `@quiz`, mỗi câu gồm `Q: ...`, đáp án `+ ` (đúng) hoặc `- ` (sai), và `E: giải thích`.
6. Build: `python3 src/build.py` (Python 3, không cần thư viện ngoài), rồi commit `index.html`.

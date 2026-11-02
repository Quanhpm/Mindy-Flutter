# Nguồn font

| File | Font | Giấy phép |
| --- | --- | --- |
| Nunito-*.ttf | Nunito (copy từ MindyMobile) | SIL Open Font License 1.1, xem `Nunito-OFL.txt` |
| RobotoMono.ttf | Roboto Mono variable (Google Fonts), terminal minh họa S1 | SIL Open Font License 1.1, xem `RobotoMono-OFL.txt` |
| BeVietnamPro-*.ttf | Be Vietnam Pro (Google Fonts) | SIL Open Font License 1.1 |
| MaterialSymbolsRounded.ttf | Material Symbols Rounded (Google), trục FILL 0–1 | Apache License 2.0 |

Be Vietnam Pro và Material Symbols được trích từ file thiết kế `MINDY-BE/Mentor Mobile UI.html`
(bản woff2 subset của Google Fonts). Be Vietnam Pro đã gộp 3 subset latin, latin-ext, vietnamese
thành 1 TTF cho mỗi độ đậm 400/500/600/700. Có thể thay bằng TTF chính thức tải từ
https://fonts.google.com/specimen/Be+Vietnam+Pro mà không cần sửa code.

Roboto Mono tải nguyên bản từ https://github.com/google/fonts/tree/main/ofl/robotomono
ngày 02/11/2026; metadata nguồn ghi commit `111eb14e367888c9374da4da0b018e72cf8ac46d`.
Bundle cùng app, không tải font khi chạy. Giấy phép đầy đủ giữ nguyên cạnh TTF.

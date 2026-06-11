# AGENTS.md

**Toàn bộ rules của project nằm trong [`CLAUDE.md`](CLAUDE.md) — đọc file đó.**

File này chỉ là pointer cho các agent không tự đọc CLAUDE.md (Codex, Gemini...).
KHÔNG duplicate nội dung vào đây — một nguồn sự thật duy nhất, tránh drift
(quyết định 2026-06-11, xem `phases/P1-baseline/actual.md`).

Tóm tắt resume protocol: đọc `CLAUDE.md` → `PROGRESS.md` (snapshot + next_action)
→ `phases/<current_phase>-*/plan.md` + `actual.md` (các entry cuối) → làm tiếp từ
`next_action`. Quy tắc khoa học, phase gates, commands, kiến trúc: tất cả trong CLAUDE.md.

# PROGRESS — nguồn sự thật duy nhất về trạng thái project

> AI agent: ĐỌC FILE NÀY ĐẦU TIÊN sau CLAUDE.md. Cập nhật trước khi kết thúc mọi phiên làm việc. Không bao giờ để file này outdated — thà ghi "đang dở X" còn hơn ghi thiếu.

## Snapshot

```yaml
current_phase: P0
phase_status: not_started        # not_started | planning | in_progress | blocked | done
last_updated: 2026-06-10
last_session: "Redesign Docker theo yêu cầu Loc: apt-first, multi-arch (arm64+amd64), root-of-trust push lên Docker Hub, build.sh/push.sh, secrets qua env. Plan + expectations P0 viết lại (v2, xem changes.md). Chưa chạy lệnh build nào."
next_action: "P0 bước 1: Loc chạy `cd src/docker && ./build.sh` trên Mac M1 (cần Docker Desktop), dán output + size image (docker images) để ghi actual.md"
blockers: []
chipyard_pinned: null            # set sau P0, dạng {version, commit}
docker_image_pinned: null        # set sau P0 bước 6, dạng {image, tag, digest}
```

## Resume protocol (cho AI agent)

1. Đọc `CLAUDE.md` (rules) → `PROGRESS.md` (file này) → `phases/<current_phase>-*/plan.md` và `actual.md` (3–5 entry cuối).
2. Nếu `phase_status: blocked` → đọc blocker, xử lý blocker trước, không nhảy bước.
3. Làm tiếp từ `next_action`. Không bắt đầu việc ngoài plan của phase hiện tại; muốn đổi → ghi `changes.md` trước (xem CLAUDE.md mục Agent workflow).
4. Trong lúc làm: append vào `phases/<phase>/actual.md` mỗi khi có kết quả/lỗi đáng ghi.
5. Trước khi kết thúc phiên: cập nhật Snapshot ở trên (last_session, next_action, blockers, last_updated).

## Trạng thái các phase

| Phase | Thư mục | Status | Plan | Expect | Report |
|---|---|---|---|---|---|
| P0 — Môi trường | `phases/P0-environment/` | not_started | ✅ | ✅ | — |
| P1 — Baseline + benchmarks | `phases/P1-baseline/` | — | chưa viết | chưa viết | — |
| P2 — NoC sweep | `phases/P2-noc-sweep/` | — | chưa viết | chưa viết | — |
| P3 — VC707 | `phases/P3-vc707/` | — | chưa viết | chưa viết | — |
| P4 — Phân tích & viết | `phases/P4-analysis/` | — | chưa viết | chưa viết | — |

## Nhật ký phiên làm việc (mới nhất trên cùng)

| Ngày | Ai | Việc đã làm | Kết quả |
|---|---|---|---|
| 2026-06-10 (2) | Claude + Loc | Redesign Docker: apt-first, multi-arch, Docker Hub root-of-trust, build/push scripts, .env secrets, .gitignore; viết lại plan+expectations P0 (v2) | P0 sẵn sàng, chờ build đầu tiên trên M1 |
| 2026-06-10 | Claude + Loc | Survey, research plan, project structure, agent rules | Repo khởi tạo, P0 sẵn sàng bắt đầu |

---
title: "#1 AI Workflow Orchestrator — Phase 1 MVP 完成"
tags: [FastAPI, Vue3, Claude Code SDK, WebSocket, PWA, SQLite]
created: 2026-03-01
phase: 1
---

# #1 AI Workflow Orchestrator — Phase 1 MVP 完成

> **Tech** FastAPI, SQLite (aiosqlite), Vue 3 + TypeScript, TailwindCSS v4, WebSocket, Web Push, PWA, Claude Code SDK
> **AI** Claude Code

## 源起

想要一套能把 AI 作業流程跑完整的工具——從需求分析到實作驗證，每個階段讓 Claude 自動執行，卡關時通知我確認，不需要一直盯著螢幕。核心需求是：可以跑在 Windows 上、手機能收 Push 通知、支援 PWA 安裝。

## 設計

整個系統分七個開發階段推進，最終架構如下：

- **Backend**：FastAPI + SQLite (aiosqlite) + WebSocket，API 與即時推播全走這裡
- **Frontend**：Vue 3 + TypeScript + TailwindCSS v4，Vite 打包，PWA 讓手機可以安裝
- **AI Runner**：`backend/services/ai_runner.py`，每個 stage 呼叫 `claude_code_sdk.query()` 跑一次 Claude Code
- **Stage pipeline**：analyze → design → implement → verify，stage 之間設 checkpoint，讓使用者可以審閱後再繼續
- **即時通訊**：WebSocket 推 live updates，Web Push 在手機或桌面送通知
- **生產部署**：FastAPI 直接 serve Vue 的 dist，Tailscale 處理 HTTPS，Windows Task Scheduler 管理服務

**AI Runner 的選型過程**是這個架構裡最值得記錄的決策。最初版本用 Anthropic raw API + 自製的 `tool_executor.py`，實作了六個工具：`read_file`、`write_file`、`list_directory`、`run_command`、`search_files`、`request_checkpoint`。寫到一半發現，這樣等於在自己重新實作 Claude Code 的基礎功能，工具維護成本高，而且缺少像 `edit_file` 這種關鍵能力（自己實作的 write_file 每次都是整檔覆寫，很容易出事）。

評估過用 Claude Code CLI 的非互動模式（subprocess），理論上可行，但控制流程、錯誤處理都很麻煩。後來發現 claude-code-sdk 能以 Python library 的方式呼叫 Claude Code，工具全部內建、有完整的 async streaming 介面，直接換過去。舊的 `tool_executor.py` 整個刪掉。

**敏感檔案保護**用三層：Claude Code global deny rules（`~/.claude/settings.json`）、project deny rules（`.claude/settings.local.json`），加上 `can_use_tool` callback 在 runner 層再過濾一次。

## 實現

**Windows asyncio 與 subprocess 的問題。** Claude Code SDK 底層會起 subprocess，在 Windows 上 asyncio 預設的 SelectorEventLoop 不支援 subprocess，執行時直接噴錯。解法是把 AI Runner 的工作移到獨立執行緒，在那個執行緒裡用 `asyncio.new_event_loop()` 配合 `ProactorEventLoop` 跑，主執行緒的 FastAPI event loop 不動。

**SDK 版本不匹配造成的 `rate_limit_event` 錯誤。** SDK 回傳的 event stream 裡出現了當前版本不認識的 event type `rate_limit_event`，直接 raise exception 中斷整個 stage。暫時用 try/except 在 event 處理迴圈裡把不認識的 type 跳過，等 SDK 更新再處理。

**`can_use_tool` callback 在 streaming mode 下的 bug。** 原本設計是在 `ClaudeCodeOptions` 裡傳入 `can_use_tool` callback 攔截敏感工具呼叫，測試時發現 streaming mode 下這個 callback 根本不會被觸發——Claude Code 跑完工具才回傳結果，攔截時機完全錯。改成依賴 deny rules 做前端阻擋，system prompt 再提醒一次不要碰特定路徑，callback 保留但只作為最後一道。

**Doppler 管理 secrets。** API key 不能寫在 `.env` 裡讓 AI 讀到，也不想手動管環境變數。選用 Doppler 作為 secrets manager，所有敏感值（`ANTHROPIC_API_KEY` 等）存在 Doppler 上，啟動時用 `doppler run --` 注入。這樣一來 `.env` 檔案可以完全不存在，AI runner 的 Claude Code 子程序也自動繼承環境變數拿到 key。原本用的 `python-dotenv` 直接移除，`config.py` 只剩 `os.getenv()` 讀取。

**TailwindCSS v4 語法變更。** v4 不再使用 `@tailwind base/components/utilities` directive，改成 `@import "tailwindcss"` 一行搞定，但第一次設定時花了一點時間找文件確認。

## 尾聲

| 指標 | 結果 |
|------|------|
| Stage pipeline | analyze → design → implement → verify 全通 |
| Checkpoint 機制 | Push 通知 + UI 確認 + asyncio.Event resume |
| 平台支援 | Windows 本機 + Tailscale HTTPS + PWA 安裝 |
| Crash recovery | 服務重啟後自動把中斷的 task 標為 failed |

從零開始七個階段推到 MVP，最大的收穫是「不要重造輪子」——換用 claude-code-sdk 之後，AI 能力直接升一個層次，還省掉維護 tool loop 的工作量。

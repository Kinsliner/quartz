---
title: "#5 逆向 Claude CLI 控制協議，實現 AskUserQuestion"
tags: [Claude CLI, subprocess, WebSocket, FastAPI, reverse-engineering]
created: 2026-03-15
phase: 5
---

# #5 逆向 Claude CLI 控制協議，實現 AskUserQuestion

> **Tech** Python, FastAPI, WebSocket, Claude CLI
> **AI** Claude Code

## 源起

現有系統用 `claude -p`（headless mode）執行 AI 任務，但這個模式不支援 AskUserQuestion tool，AI 無法在執行過程中向用戶提出結構化問題。目標是讓 AI 能暫停、提問、等待回答後繼續——類似 Claude Code Desktop 的互動體驗，但整合進自己的 workflow 工具裡。

## 設計

研究了幾個方向。Claude Code Desktop 本質上只是 GUI 包裝 CLI subprocess，沒有特別的 API。OpenCode（sst/opencode）有類似的互動機制，但它直接呼叫 Anthropic API，不走 CLI，意味著得用 API key 計費——這個路不走。

接著看 `claude_code_sdk` 和 `claude_agent_sdk` 的原始碼，發現它們底層都是 spawn CLI subprocess，透過 `--input-format stream-json --output-format stream-json` 做雙向 JSON 通訊。這個控制協議沒有公開文件，但從 SDK 原始碼可以完整逆向出來。

確認方向後，決定不依賴 SDK（避免 OAuth token 問題），直接自己實作控制協議：

- `cli_protocol.py` — 封裝 subprocess、握手、訊息路由、AskUserQuestion 攔截
- `poc_server.py` — FastAPI + WebSocket，橋接前端和 CLI subprocess
- `index.html` — 單頁前端，聊天介面 + 問題選項 UI

整體資料流：前端 → WebSocket → `poc_server.py` → `CliSession` (stdin) → CLI subprocess (stdout) → 事件 queue → WebSocket → 前端。AskUserQuestion 在 `CliSession` 內部攔截，reader thread 阻塞等待用戶回答，答案透過 WebSocket 傳回後再 unblock。

## 實現

**控制協議格式。** CLI 啟動需要帶 `--permission-prompt-tool stdio`，才會透過 stdin/stdout 發送 `control_request`。初始化握手：先送一個 `subtype: initialize` 的 `control_request`，CLI 回 `control_response` 後才能開始收發訊息。

**AskUserQuestion 攔截機制。** CLI 要使用 AskUserQuestion 時，會先發一個 `subtype: can_use_tool` 的 `control_request`，等待程式回應是否允許。`CliSession` 在 reader thread 裡攔截這個請求，建一個 `answer_queue`，emit `question` 事件到主 queue，然後 `answer_queue.get(timeout=600)` 阻塞等待。用戶回答透過 WebSocket 進來後，`answer_question()` 把答案塞進 queue，reader thread unblock，送出 `control_response`，AI 繼續執行。

**版本格式差異造成 ZodError。** 一開始用 SDK v0.0.25 逆向出的格式 `{"allow": true, "input": ...}` 回傳，CLI 噴 ZodError 拒絕了。比對 `claude_agent_sdk` v0.1.48 後發現格式在新版已改成 `{"behavior": "allow", "updatedInput": ...}`，換掉之後就正常了。

**Windows 上的 subprocess I/O。** 現有系統的 `CliExecutor` 已踩過 Windows subprocess pipe 的坑，用 thread + queue 模式解決。這次沿用同樣的模式：reader thread 同步讀 stdout，事件塞進 `Queue`，asyncio 層用 `asyncio.to_thread()` 做橋接，避免 event loop 被 blocking I/O 卡死。

## 尾聲

POC 全部跑通：握手、AskUserQuestion 攔截、前端選項顯示、多輪問答、答案回傳，全程走 CLI 訂閱額度、無 ZodError。這次的收穫是一份可以直接整合進現有 orchestrator 的控制協議實作，下一步可以把 AskUserQuestion 接進 Task 的 checkpoint 流程，讓 AI 在執行中途主動跟用戶確認方向。

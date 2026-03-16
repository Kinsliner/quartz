---
title: "#6 Session AskUserQuestion 雙向控制協議整合"
tags: [FastAPI, WebSocket, Claude CLI, Python, Vue3]
created: 2026-03-16
phase: 6
---

# #6 Session AskUserQuestion 雙向控制協議整合

> **Tech** FastAPI, Claude CLI stream-json, WebSocket, Vue 3, SQLite
> **AI** Claude Code

## 源起

Session 模式原本是單向的：每個 turn spawn 一個 `claude -p` subprocess，stdin 直接關閉，AI 跑完就結束。這樣做有個缺口——Claude 的 `AskUserQuestion` tool 會讓 AI 主動問使用者問題，但在 stdin 關閉的情況下根本無法傳回答案，問題直接被丟掉。

之前已經有一個 POC（`poc/cli_protocol.py`）驗證了 CLI 的 stream-json 控制協議可以攔截 `AskUserQuestion`，這次把它正式整合進 Session 模式。

## 設計

關鍵的轉換是把 subprocess 的啟動方式從單向改為雙向：原本 `claude -p` 在跑完 turn 後自動退出，現在換成 `--input-format stream-json --output-format stream-json --permission-prompt-tool stdio`，stdin 持續開著，可以雙向寫入讀取 JSON。

控制流程：

1. subprocess 啟動後送 init handshake（`{"type":"user","message":...}`）
2. reader thread 持續讀取 stdout，遇到 `control_request` 類型的訊息就攔截
3. 如果是 `AskUserQuestion`，reader thread 阻塞在 `answer_queue.get()`，把問題寫入 DB，並把 session 狀態改為 `waiting_for_answer`
4. 使用者透過前端的問題卡片回答，API `POST /answer` 呼叫 `answer_question()`，把答案塞進 queue
5. reader thread 繼續，把答案寫回 stdin（`{"behavior":"allow","updatedInput":...}`）
6. 其他工具的 `control_request` 直接 auto-allow，不打斷流程
7. 收到 `result` 後主動 `terminate()` subprocess（streaming mode 不會自動退出）

per-turn subprocess 的設計不變，確保 turn 之間不佔資源。問題存進 DB 而非記憶體，這樣頁面重載後前端仍能從 `GET /pending-question` 還原問題卡片。

## 實現

**永遠 running 的問題。** streaming mode 和 `claude -p` 最大的行為差異在於：`claude -p` 跑完一個 turn 就自動退出，streaming mode 則繼續等待下一個 user message。原本的邏輯是等 subprocess 自然結束，結果 session 就永遠停在 `running` 狀態。修正是在 `_handle_result()` 收到 `result` 事件時，主動呼叫 `stdin.close()` 加 `terminate()`。

**terminate 後誤報錯誤。** subprocess 被 terminate 後 returncode 非零，進到收尾邏輯時被誤判為執行錯誤。修正是加一個 `not self._closed` 條件，如果是主動關閉的就跳過錯誤處理。

**init handshake 的格式問題。** POC 用的 init 格式是確認過可以運作的，但整合時曾嘗試改為等待 CLI 先送出 `system` 事件再送第一個 user message，結果 CLI 回傳 exit code 1 直接掛掉。查不出具體原因，最後還原為 POC 的做法——啟動後立即送 handshake，並同時相容兩種 init 格式以防萬一。

**前端複選邏輯缺失。** `AskUserQuestion` 有 `multiSelect` 旗標，但第一版的 `SessionQuestionCard.vue` 只做了單選邏輯。修正：multiSelect 用 `Set<string>` 追蹤已選項目，UI 改為 checkbox 並顯示「(可複選)」提示；單選維持 radio 圓點，選了就直接送出。

**跨線程通訊。** reader thread 是同步執行，但答案要從 asyncio 的 API handler 傳進來。用 `queue.Queue` 而不是 asyncio event，因為 Windows 環境下 `asyncio.Event` 跨 thread 使用有相容性問題。主 event loop 這邊改用 polling（短間隔 await）讀取 reader thread 丟出的事件。

## 尾聲

| 項目 | 數字 |
|---|---|
| 修改檔案 | 11 |
| 新增測試 | 20 |
| 測試總數 | 133（全通過）|

把 POC 驗證過的協議整合進正式流程，主要麻煩都來自 streaming mode 和 `claude -p` 的行為差異——退出時機、terminate 的 returncode、init 格式。這些邊界情況在 POC 階段不明顯，但在生產整合時一個接一個浮出來。

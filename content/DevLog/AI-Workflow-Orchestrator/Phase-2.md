---
title: "#2 SDK 驗證、推播除錯、HTTPS 上線"
tags: [Claude Code SDK, Web Push, Tailscale, asyncio, Windows, Doppler]
created: 2026-03-01
phase: 2
---

# #2 SDK 驗證、推播除錯、HTTPS 上線

> **Tech** Claude Code SDK, Web Push (pywebpush), Tailscale, asyncio, Doppler, cryptography
> **AI** Claude Code

## 源起

Phase 1 的架構跑起來了，但幾個核心流程還沒真正驗過：Claude Code SDK 的工具呼叫和敏感檔案攔截到底有沒有用？Push 通知能不能送到手機？Tailscale HTTPS 能不能讓手機走安全連線存取？這次就是把這三條線逐一驗清楚。

## 設計

沒有太多選型討論，這次的工作主要是驗證和除錯。三個方向各自獨立推進：

- **SDK 驗證**：寫 `scripts/test_sdk.py`，三個測試案例逐一跑——純文字、Read 工具讀檔、嘗試讀 `.env` 確認被攔截
- **Push 通知**：寫 `scripts/test_push.py` 繞過完整 API 流程，直接測試 pywebpush 能不能把通知推到 FCM
- **HTTPS**：用 `tailscale cert` 產生憑證，`serve.py` 偵測憑證路徑後啟動 SSL

敏感檔案保護這塊，Phase 1 設計了三層（global deny rules、project deny rules、`can_use_tool` callback），這次測試過後決定移掉第三層。

## 實現

**`can_use_tool` callback 的格式問題。** 測試時發現 callback 觸發了，但 SDK 拋出格式錯誤。查了之後才知道 `can_use_tool` 需要 async iterable 格式的 prompt，要傳 `{"type": "user", "message": {"role": "user", "content": "..."}}` 這個結構，不是一般字串。改格式後可以觸發，但考量到 deny rules 已經在更底層擋住，多一層 callback 只是增加維護複雜度，最終決定移掉，依賴兩層 deny rules 就夠。

**`rate_limit_event` 版本不匹配。** SDK 的 event stream 吐出當前版本不認識的 `rate_limit_event` type，直接讓 event 處理迴圈噴例外。這個 event type 是新版 API 才有的，SDK 還沒跟上。用 try/except 跳過不認識的 event type 收工，三個測試案例全部 PASS。

**Windows asyncio subprocess 問題（二次確認）。** uvicorn 啟動時會自己設定 event loop policy，所以在 `main.py` 設 `WindowsProactorEventLoopPolicy` 完全沒用——uvicorn 啟動後會覆蓋掉。最終解法是 `asyncio.to_thread()` 把 AI Runner 丟到獨立執行緒，執行緒裡自己建 `ProactorEventLoop`，完全繞開 uvicorn 管理的 event loop。

**Push 通知的兩個 bug。** 前端拿 VAPID public key 的程式用 `res.json()` 解析，但 API 回傳的是純文字字串，JSON parse 當然失敗，改成 `res.text()` 解決。另一個問題是 VAPID public key 的格式：Web Push API 需要的是 URL-safe base64 格式的原始公鑰（uncompressed point），但程式直接把 PEM 字串丟過去——瀏覽器拿到之後完全解析不了。用 `cryptography` 套件把 PEM 裡的公鑰提取出來，轉成 URL-safe base64 再回傳，這才對。

**pywebpush 的 VAPID key 傳法。** 以為把 PEM 內容當字串傳進去就行，實際上 pywebpush 要的是檔案路徑，不是字串內容。後端改成讀 `VAPID_PRIVATE_KEY_PATH` 環境變數傳路徑，`test_push.py` 直接打到 FCM 拿到 201，Push 通知完整跑通。最後發現手機沒彈出通知，查了一下是 Android 的彈出式通知權限預設沒開，進設定打開就好。

**Tailscale 憑證偵測的編碼問題。** `serve.py` 裡執行 `tailscale cert` 並讀取輸出路徑，Windows 預設終端是 cp950 編碼，subprocess 讀出來的字串解碼失敗。加 `encoding="utf-8"` 參數修掉。偵測邏輯本身有時不穩定，所以同時提供直接指定憑證路徑的啟動指令作為備援，手機透過 `https://echen-pc.taile92755.ts.net:8000` 存取正常。

**Log 同時輸出到終端和檔案。** 在 `logging.basicConfig` 加入 `FileHandler` 指向 `backend/data/server.log`，讓 server 日誌在終端看得到的同時也落地，方便事後查問題。

**初次 Git commit。** 把整個 Phase 1 + Phase 2 的工作一起提交，60 files、10,460 lines，branch 從 master 改名 main。

## 尾聲

| 項目 | 結果 |
|------|------|
| SDK 測試 | 純文字 / Read 工具 / .env 攔截，三項全 PASS |
| Push 通知 | FCM 201，手機實際收到 |
| HTTPS | Tailscale 憑證上線，手機可透過 ts.net 存取 |
| 首次 commit | 60 files，10,460 lines |

這次的工作量不大，但每個問題都是實際跑才踩到的——尤其是 VAPID key 格式和 pywebpush 傳參方式，文件沒有講清楚，只能靠測試腳本一層一層剝。

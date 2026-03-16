---
title: "#1 Dashboard 服務監控、Log 管理與啟動配置化"
tags: [FastAPI, SQLite, Windows, Process Management, Health Monitor]
created: 2026-03-11
phase: 1
---

# #1 Dashboard 服務監控、Log 管理與啟動配置化

> **Tech** FastAPI, SQLite, Alpine.js, taskkill, PyYAML
> **AI** Claude Code

## 源起

cli-workflow 的 Dashboard 負責管理各專案的服務啟動與停止，但一直缺少兩件東西：知道服務有沒有活著、知道服務印了什麼。服務掛掉了 UI 完全沒反應，要排查問題也沒有 console output 可看。今天把這兩塊補起來，順便把 Guardian 啟動 Dashboard 的方式也整理乾淨。

## 設計

健康監控這塊有幾個選擇：主動 polling 或被動監聽 process exit event。考量到有些服務本身有提供 health endpoint（像 FastAPI 的 `/health`），希望能區分「process 還活著但回傳 500」和「process 已經死了」這兩種情況，所以選主動 polling，兩層判斷：先確認 PID 還在，再打 HTTP GET 確認服務邏輯健康。

狀態設計成三種：`running`（一切正常）、`unhealthy`（process 活著但 HTTP 回應不對）、`down`（PID 消失）。故意不做自動重啟——重啟有副作用，讓使用者自己決定。

Log 輸出的設計：原本 stdout/stderr 是 PIPE 進來的，但 Dashboard 重啟後 PIPE 就斷了，什麼都沒了。改成直接把 subprocess 的 stdout/stderr 寫到 `dashboard/data/logs/` 下的檔案，既能即時查又能保留歷史。

PID 持久化用 `dashboard/data/pids.json` 存，Dashboard 重啟後能把還活著的 process 重新接管，不會誤以為服務都沒跑。

## 實現

**Windows process tree 殺不乾淨。** 原本 stop 是送 SIGTERM，但 Windows 上 Python subprocess 不一定有辦法乾淨接收。子進程（e.g., uvicorn worker）會變成 orphan 繼續佔 port。改用 `taskkill /F /T` 加上 `/T` flag 殺整個 process tree，徹底解決。

**PID 恢復的判斷。** Dashboard 重啟後讀 `pids.json`，但要判斷這個 PID 現在是否還活著，用 `os.kill(pid, 0)` 來探測：不送實際信號，只確認 PID 存在且有權限存取。Windows 上 PID 會被回收再利用是已知問題，但目前服務數量少、重啟間隔短，碰到誤判的機率低，先用這個簡單方式處理。

**Log 編碼問題。** Windows 上中文 console output 預設是 CP950，但部分程式（如 uvicorn）會輸出 UTF-8。Log 讀取時加了自動偵測：先試 UTF-8，失敗就 fallback 到 CP950，解決亂碼。同樣的邏輯也套在 Guardian 讀 Dashboard console log 的地方。

**PyYAML 反斜線變控制字元。** `.workspace.yaml` 的 guide 註解裡原本用 Windows 路徑範例（`C:\path\to\app`），PyYAML dump 出來 `\a` 被解成 bell character（ASCII 7）。改成用正斜線 `C:/path/to/app` 作為範例，同時在所有範例路徑統一用正斜線，YAML 裡也不需要雙引號包住。

**Git 操作卡住。** Dashboard 對大型 repo 執行 `git add -A` 時，如果 repo 裡有大量檔案或 lock 狀態，`_run_git` 會永遠等不到回應，API 就掛著不回。加了 60 秒 timeout，到時間直接拋例外，至少 API 會回錯誤而不是讓前端 spinner 轉到天荒地老。

**Guardian 和 Dashboard port 不一致。** Guardian 寫死 8080 啟動 Dashboard，但 Dashboard 預設跑 8000。新增 `dashboard/__main__.py` 讓 Dashboard 支援 `python -m dashboard` 啟動，port 從環境變數 `DASHBOARD_PORT` 讀取，Guardian 那邊設好環境變數就能對齊，不用改任何 hardcode。

## 尾聲

| 功能 | 狀態 |
|------|------|
| 服務健康監控（PID + HTTP）| 完成 |
| Console log 寫檔 + UI 查看 | 完成 |
| PID 持久化與恢復 | 完成 |
| Guardian Dashboard console 查看 | 完成 |
| 啟動配置化（`-m dashboard`）| 完成 |
| .workspace.yaml guide 與 YAML 修復 | 完成 |
| Git 操作 timeout | 完成 |

Dashboard 從「能開關服務」升級成「能看服務死活和 log」，排查問題不用再 SSH 進去翻檔案了。

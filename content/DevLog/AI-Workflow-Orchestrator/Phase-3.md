---
title: "#3 雙模式 AI Runner：SDK 與 CLI Headless 並存"
tags: [Python, FastAPI, Claude Code, subprocess, asyncio]
created: 2026-03-01
phase: 3
---

# #3 雙模式 AI Runner：SDK 與 CLI Headless 並存

> **Tech** Python, FastAPI, subprocess, asyncio, Claude Code CLI
> **AI** Claude Code

## 源起

原本的 `ai_runner.py` 與 `claude_code_sdk` 緊密耦合，整個 `_run_stage()` 只能走 SDK 這條路。為了比較 SDK 和 CLI headless 兩種執行模式的行為差異，需要讓系統同時支援兩種方式，並透過環境變數 `AI_RUNNER_MODE` 切換，預設維持 `sdk`。

## 設計

把執行邏輯從 `ai_runner.py` 裡抽出，建立獨立的 `stage_executor.py`，定義共用的資料結構和兩個 executor 類別：

- `SdkExecutor`：搬移原 `_run_stage()` 的 SDK 呼叫邏輯，保留 Windows 所需的 ProactorEventLoop 線程模式
- `CliExecutor`：用 `subprocess.Popen` 啟動 `claude` CLI，加 `--output-format stream-json --verbose`，背景線程讀 stdout 丟進 `queue.Queue`，主協程從 queue 消費並解析事件
- `create_executor()` factory 函式根據 `AI_RUNNER_MODE` 決定回傳哪個

`ai_runner.py` 這邊只需要建 `StageContext` 然後迭代 executor yield 出來的 `StageLogEvent`，原本的 SDK import 全部移走。

## 實現

**`stream-json` 需要搭配 `--verbose`。** 最初啟動 CLI 時只給了 `--output-format stream-json`，CLI 直接報錯退出。加回 `--verbose` 才正常輸出結構化事件。

**`--permission-mode bypassPermissions` 漏掉了。** CliExecutor 第一次跑起來後工具全部無法使用，Claude 只能空轉。原因是 CLI 預設不繞過權限，需要明確傳 `--permission-mode bypassPermissions`，加上去就正常了。

**system prompt 的傳遞方式。** CLI 的 `--append-system-prompt` 旗標在 Windows subprocess 環境下傳多行字串很容易出問題，最後改用環境變數 `CLAUDE_CODE_APPEND_SYSTEM_PROMPT` 注入，繞開 shell 引號的問題。

**Windows `set` 指令的尾隨空格。** 本機測試時用 `set AI_RUNNER_MODE=cli &&` 設定環境變數，但這樣設出來的值是 `'cli '`（尾端有空格），factory 比對 `'cli'` 永遠失敗，一直跑 SdkExecutor。在 `config.py` 讀取時加 `.strip()` 解決。

**asyncio subprocess 在 uvicorn 裡的問題。** 雖然 `main.py` 已經設定 ProactorEventLoop，`asyncio.create_subprocess_exec` 在 uvicorn worker 裡的行為仍然不穩定，管道讀取會卡住。最終方案是完全放棄 asyncio subprocess，改用同步的 `subprocess.Popen` 搭配背景線程讀取 stdout，線程把每行丟進 `queue.Queue`，主協程消費並 yield——這樣串流不中斷，又不會碰到 asyncio subprocess 的地雷。

## 尾聲

新增約 270 行的 `stage_executor.py`，`ai_runner.py` 反而淨減 65 行。兩種模式可以隨時透過環境變數切換，讓後續比較 SDK 與 CLI 行為差異時不用改程式碼。

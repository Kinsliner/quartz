---
title: "#01 兩個工具的合體"
tags: [Python, Claude API, Tool Use, Jira, Git]
created: 2025-10-13
phase: 1
---

# #01 兩個工具的合體

> **Tech** Python, Anthropic Tool Use API, Jira REST API, Git Worktree
> **AI** Claude Code, Claude Sonnet

## 源起

手上有兩個分別開發的工具，做到一半發現它們是同一件事的兩半。

**automation_tool** 是 AI 分析工具，用 Anthropic Tool Use API 讓 Claude 自主探索專案——讀目錄結構、搜尋程式碼、讀檔案，最多跑 30 輪對話，最後產出結構化的需求文件（9 章節）和設計文件（11 章節）。它有腦但沒有手腳，不知道怎麼融入實際開發流程。

**jira_poller** 是 DevOps 整合工具，每 30 秒輪詢 Jira 上標了 `AI-Agent` 的任務，自動建 Git Worktree、跑四階段流程（需求→設計→開發→測試），每階段都能用 `@approved` / `@rejected` 做人工審批。它有完整的工作流但 AI 分析能力很弱——需求階段只是丟一句 prompt 就叫 AI 生成，出來的東西 500 字不到，設計階段甚至只有 placeholder。

兩個放在一起看：一個有大腦沒身體，一個有身體沒大腦。而且接口天然相容——都吃需求文字、都吐 Markdown。

## 設計

整合方向是讓 jira_poller 在需求和設計階段呼叫 automation_tool 的模組。

引入方式考慮了 pip package 和直接 path import，選了後者。兩個專案都還在快速迭代，打包成 package 反而增加同步修改的摩擦。降級機制處理 import 失敗的情況，automation_tool 不在就退回舊的 AI Provider，再不行就用 placeholder，流程不中斷。

設計階段的關鍵是把 Git Worktree 路徑傳給 SystemDesigner 當 `project_root`，這樣 AI 的四個探索工具（get_project_structure、list_files、search_code、read_file）就能直接讀 Worktree 裡的 Unity 專案，而且每個 Jira 任務的 Worktree 互相隔離。

## 實現

**整合本身的程式碼量不大。** orchestrator.py 加了 import 檢測、初始化方法、兩個 `_with_automation_tool` 方法。agent_files.py 加了取得階段檔案路徑的 helper。核心改動集中在怎麼把 jira_poller 的資料（任務描述、Worktree 路徑、需求檔路徑）餵給 automation_tool 的介面。

**async/sync 橋接。** jira_poller 是同步的（threading + time.sleep），automation_tool 用 async Anthropic SDK。橋接方式是先檢測有沒有正在跑的 event loop，沒有就用 `asyncio.run()` 建新的。比把任何一邊全面改寫省事很多。

**反饋循環的處理。** 人工 `@rejected` 的時候會帶修改意見。需求階段直接把反饋拼進 requirement_text 重跑。設計階段麻煩一點——建一個臨時檔案把反饋附加到原始需求後面，餵給 SystemDesigner，跑完再刪掉臨時檔。

## 尾聲

| 項目 | 整合前 | 整合後 |
|------|--------|--------|
| 需求文件 | ~500 字 | ~2500 字（9 章節） |
| 設計文件 | placeholder | ~4800 字（11 章節） |
| 專案理解 | 無 | Tool Use 探索（10-20 次工具呼叫） |
| 降級保障 | 無 | 三層降級 |

兩個工具合在一起之後，AI 真的能「看懂」Unity 專案再做設計，而不是憑空猜測。

---

返回 [[專案/AI自動化Unity工作流整合/index|專案首頁]]

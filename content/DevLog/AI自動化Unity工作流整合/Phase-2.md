---
title: "#02 四階段工作流"
tags: [Python, Jira, Git Worktree, DevOps]
created: 2025-10-13
phase: 2
---

# #02 四階段工作流

> **Tech** Python, Jira REST API, Git Worktree, subprocess
> **AI** Claude Code

## 源起

工具整合完了，但整個 Jira → AI → Git → 人工審批的端到端流程還沒跑通。這篇記錄 jira_poller 的四階段工作流怎麼實際運作。

## 設計

一張 Jira 任務從建立到完成走四個階段：

1. **需求** — AI 讀任務描述，產出 9 章節需求文件，發到 Jira 評論
2. **設計** — AI 讀需求文件 + 探索 Worktree 裡的程式碼，產出 11 章節設計文件
3. **開發** — AI 依據設計修改程式碼，commit 到 Worktree 分支
4. **測試** — AI 建 Pull Request、產出測試指引

每個階段結束後等人工審批：`@approved` 往下走、`@rejected` 重做、`@sendback` 退回上一階段、`@restart` 從頭來。

Git Worktree 的隔離設計是整個流程的基礎——每個任務有獨立的 worktree 目錄，AI 在裡面怎麼改都不影響主分支和其他任務。

## 實現

**task_poller 是入口。** 每 30 秒查一次 Jira，JQL 過濾 `labels = "AI-Agent"` 的任務。偵測到新任務就交給 orchestrator 處理。

**orchestrator 管狀態流轉。** 根據任務目前的階段決定下一步動作。每個階段的產出存在 `.ai-agent/{TASK_KEY}/` 目錄下（req.md、design.md、changes.md、test_guide.md），commit 到 Git，再把內容發到 Jira 評論讓人看。

**approval_checker 輪詢評論。** 每次 poll 都去抓 Jira 評論，找最新的審批指令。看到 `@approved` 就推進、`@rejected` 就重跑當前階段。

**實際跑一次的數據：**
- 需求階段：18 秒、2543 字
- 設計階段：3.2 分鐘、4821 字、15 次工具呼叫
- 全程 Jira 評論和 Git commit 都自動完成

## 尾聲

四階段跑通之後，日常使用流程是：在 Jira 建任務加標籤，等通知看 AI 產出，覺得 OK 就 `@approved`，不行就 `@rejected` 附上修改意見。開發和測試階段還在持續迭代中。

---

返回 [[專案/AI自動化Unity工作流整合/index|專案首頁]]

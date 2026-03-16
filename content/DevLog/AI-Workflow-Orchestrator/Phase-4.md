---
title: "#4 Agent 輸出機制重構：從 JSON 解析到 HTML comment 標記"
tags: [Python, FastAPI, Claude Code SDK, Multi-Agent, Orchestrator]
created: 2026-03-12
phase: 4
---

# #4 Agent 輸出機制重構：從 JSON 解析到 HTML comment 標記

> **Tech** Python, FastAPI, Claude Code SDK, Regex
> **AI** Claude Code

## 源起

多 Agent 協作系統裡，Orchestrator 需要從 AI 的輸出中提取結構化資料——Planner 要輸出任務清單、Implementer 要回報修改了哪些檔案、Reviewer 要給出審查結論。原本的做法是要求 AI 用 ````json` fences 輸出固定格式，但 AI 的服從性很差：key 名稱對不上、結構層級不對、或是直接忽略 JSON 要求。重試三次仍然失敗的情況時有發生，整個流程卡死。

## 設計

問題的根源不是 prompt 寫得不夠好，而是方向錯了——要求 AI 精確產生機器格式，本來就是在要求 AI 做程式該做的事。

探索過程走了幾條路：

**強化 JSON prompt + 防禦性解析。** 加了 normalize 邏輯，試圖修正常見偏差，例如把 `step` 自動對應到 `id`，或把 list 包回 object。但這是治標，AI 的輸出空間太大，normalize 不可能覆蓋所有變體。

**TodoWrite 工具攔截。** 想讓 Planner 透過 Claude CLI 內建的 TodoWrite 工具建立任務清單，Orchestrator 從 tool event stream 攔截結構化資料，完全跳過文字解析。但兩次測試 AI 都不呼叫 TodoWrite，即使 prompt 明確要求。工具呼叫的選擇權在 AI，無法強制。

**HTML comment 標記。** 最終方案：讓 AI 自由輸出自然語言，但要求在回應末尾加上固定的 HTML comment 標記，程式用 regex 精確提取。AI 把 comment 當作輸出的一部分，不會改寫，而且 comment 語法天然是「附加資訊」的語意，AI 接受度高。

三個 Agent 統一採用這個模式：

| Agent | 標記 | 程式提取方式 |
|---|---|---|
| Planner | `<!-- TASKS ... TASKS -->` | regex 逐行 parse `{id}. {title}` |
| Implementer | `<!-- SUMMARY -->` + `<!-- FILES -->` | 取文字 / 逐行取路徑 |
| Reviewer | `<!-- REVIEW -->` + `<!-- VERDICT: PASS/FAIL -->` | 取文字 / 取 PASS or FAIL |

## 實現

**標記缺失的重試機制。** 提取不到標記時，過去的做法是重新執行整個 Agent，代價高。現在改為讓 Orchestrator 在同一個對話脈絡下發送一則提醒訊息，要求 AI 補上標記（最多 2 次）。AI 已有完整上下文，只需補一個 comment，比重跑省很多 token。

**user prompt 比 system prompt 更可靠。** 測試中發現 AI 更容易忽略 appended system prompt 裡的格式指令，改成把格式要求同時放在 system prompt 和 user prompt 之後，服從率明顯提升。

**兩個未定義變數 bug。** `_handle_implement` 和 `_handle_review` 裡引用了 `prompt_text`，但這個變數在重構過程中已被移除，只有到執行時才會 crash。同批修的還有 `CompletionResult` 的 import 遺漏——重構時清掉了 import 但 `_handle_review` 還在用。兩個都是重構後沒跑完整流程的後果，往後要補 integration test。

**CheckpointDialog 補上 Planning 階段的 Approve/Reject。** 原本 Planning 階段的 checkpoint 只顯示純文字，這次加了 Markdown 渲染和操作按鈕，讓使用者在 Planner 輸出完成後可以直接確認或打回票，不用另開終端機手動操作。

## 尾聲

重構後 AI 輸出的結構化資料提取穩定很多，重試機制也從「重跑 Agent」降級成「補輸出」，省下不少不必要的開銷。這次最大的收穫是想清楚了 AI 和程式的分工邊界——AI 負責思考和表達，程式負責從固定位置精確提取，不要讓兩者越界。

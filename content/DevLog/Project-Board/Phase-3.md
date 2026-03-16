---
title: "#3 API 操作、marked v17 修復、檔案模板與 MCP 整合"
tags: [FastAPI, Vue 3, marked.js, MCP, Python]
created: 2026-03-16
phase: 3
---

# #3 API 操作、marked v17 修復、檔案模板與 MCP 整合

> **Tech** FastAPI, Vue 3, marked.js, Python MCP SDK (FastMCP), httpx
> **AI** Claude Code

## 源起

這次開發有幾條線同時進行。一開始是要用 curl 直接打 API 在「素材」board 建一個整理 UI Library 連結的 block，過程中發現 markdown 裡的連結沒有渲染出來，觸發了 marked v17 相容性問題的修復。另一條線是補上檔案上傳的模板類型，讓 block 可以存附件連結並在卡片上顯示。最後做的 MCP Server 整合則是這次工作量最大的部分，目標是讓 Claude Code 能直接操作 Project Board，而不用靠手動呼叫 API。

## 設計

**MCP Server 的定位。** Project Board 本身已有完整的 REST API，MCP Server 只是在外面包一層，把每個端點轉成 Claude 可以呼叫的 tool。實作上選 Python MCP SDK 的 `FastMCP`，宣告式地用 `@mcp.tool()` decorator 定義每個 tool，比起手寫 JSON Schema 省事很多。Transport 用 stdio，讓 Claude Code 以子程序的方式啟動，透過 stdin/stdout 通訊。

工具的設計原則是輸出對 Claude 友善的純文字，而不是直接回傳原始 JSON：每個 block 的回傳格式是 `block:{id} type:{type} pos:(x,y) WxH\n  content: 預覽...`，專案和分頁也有對應的文字格式，讓 Claude 不用額外解析就能理解內容。

14 個 tools 的分佈：
- 專案：list / create / update / delete（4 個）
- 分頁：list / create / update / delete（4 個）
- Block：get_blocks / get_block_detail / create / update / delete / search（6 個）

**檔案模板的定位。** 不另建資料表，直接沿用現有的 markdown block 結構，用 `template_type: "file"` 標記。content 存一行 `[filename](url)` 格式的 markdown，BlockCard 偵測到 file 類型後解析出檔名和 URL 自行渲染成附件卡片外觀。

## 實現

**marked v17 的 listitem API 異動。** 用 curl 在「素材」board 建了一個包含三個連結的清單 block，在瀏覽器上卻顯示成純文字，連結的 `<a>` 標籤沒有出現。排查後發現是 marked v17 的 breaking change：`renderer.listitem` 原本接收 `{ text, task, checked }`，其中 `text` 已經是渲染後的 HTML。v17 改為傳入完整的 token 物件，`text` 變成原始 markdown 字串，而 inline 元素（連結、粗體）還沒被渲染。修法是把 `text` 替換成 `this.parser.parseInline(token.tokens)`，讓內部 tokens 正確走過 inline 渲染管線。

**上傳 API 的格式限制。** 後端 `/api/upload` 原本只接受圖片，這次擴充成同時接受文件類型（PDF、DOCX、XLSX、PPTX、TXT、CSV、ZIP 等），上限設為 20MB。前端的拖曳上傳區域也一起更新接受的 MIME 類型清單。

**結構化編輯與 Markdown 之間的切換。** 檔案模板的 BlockEditor 預設顯示結構化表單（只有一個「選擇或拖曳檔案」的上傳區域），但保留切換到 markdown 編輯模式的按鈕，讓使用者可以直接修改底層的 `[filename](url)` 字串。切換時需要把結構化資料序列化成 markdown，反向時再解析回來，兩邊的狀態保持同步。

**MCP Server 的 stdio 配置問題。** 早期測試時 MCP Server 無法正常啟動，查出是 `logging.basicConfig` 把 log 輸出到 stdout，污染了 stdio transport 的訊息流。把 log stream 改成 `sys.stderr` 就解了。

## 尾聲

| 功能 | 狀態 |
|------|------|
| curl API 建立 block | 完成 |
| marked v17 listitem 相容修復 | 完成 |
| 檔案上傳模板（PDF、DOCX 等） | 完成 |
| 結構化 / Markdown 編輯切換 | 完成 |
| MCP Server 14 個 tools | 完成 |
| 使用者層級 MCP 註冊（.mcp.json） | 完成 |

MCP Server 整合完成後，現在可以直接在 Claude Code 的對話裡操作 Project Board——建 block、搜尋內容、調整位置——不用再開瀏覽器或手動打 curl。這算是把工具本身整進了開發流程裡。

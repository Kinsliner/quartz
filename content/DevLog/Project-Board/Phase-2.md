---
title: "#2 Block 系統統一為 Markdown Block"
tags: [Vue, FastAPI, Markdown, md-editor-v3, 資料遷移]
created: 2026-03-12
phase: 2
---

# #2 Block 系統統一為 Markdown Block

> **Tech** Vue 3, FastAPI, md-editor-v3, marked.js, interact.js
> **AI** Claude Code

## 源起

原本的 Block 系統有 text、list、checklist、image、link 五種類型，每種各有自己的 content 結構和對應的編輯表單。新增或修改 block 要先選類型、再填對應欄位，整個編輯流程很零散。
決定把所有類型統一成一種 markdown block，讓使用者直接寫 markdown，編輯器提供一致的體驗，資料模型也大幅簡化。

## 設計

統一後的 block 只有一個 `text` 欄位存 markdown 字串，不再需要 block_type 區分。後端的遷移邏輯在 server 啟動時跑一次，把現有資料轉換成對應的 markdown 語法：text 原樣保留、link 轉成 `[title](url)` 加說明、list 轉成 `- item`、checklist 轉成 `- [ ] item` 或 `- [x] item`、image 轉成 `![caption](url)`。

前端分成兩個元件：

- **BlockEditor.vue**：改用 md-editor-v3 單一編輯器，移除原本五種類型的切換邏輯和各自的表單，支援圖片上傳 callback
- **BlockCard.vue**：用 marked.js 渲染 markdown，自訂 renderer 讓 checklist 的 checkbox 可以互動

「新增區塊」改為 dropdown 選單提供四種模板（空白、連結、清單、待辦），讓使用者有起始結構可以參考，但不強制類型。

## 實現

**Checkbox 互動的實作方式。** marked.js 渲染出來的 checkbox 預設是 `disabled`，點了沒反應。解法是自訂 renderer，把 `disabled` 屬性拿掉，然後在 BlockCard 上監聽 click 事件，判斷點到的是 `input[type=checkbox]`，再去原始 markdown 文字裡找到第幾個 checkbox 對應的 `- [ ]` 或 `- [x]` 行做字串替換，最後 emit `toggle-check` 給父層更新。

**拖曳與 resize 期間的文字選取問題。** 使用者在拖移或縮放 block 時，游標劃過其他卡片會觸發文字選取，干擾操作。解法是在 ProjectBoard 加一個 `interacting` flag，拖曳和 resize 開始時設為 true、結束時清掉，配合 Tailwind 的 `select-none` class 在互動期間禁掉整個畫布的文字選取。圈選框的拖曳也有同樣問題，一併處理。

**圈選即時高亮。** 原本圈選框的碰撞檢測放在 `mouseUp`，放開滑鼠才知道選到哪些 block，體驗不直觀。把碰撞檢測移到 `mouseMove`，每次更新框的大小時同步算一次，讓使用者拖曳過程中就能看到哪些 block 被選中。效能上還可以接受，因為 block 數量不多。

**interact.js 版本相容錯誤。** 執行時拋出 `interact.isSet is not a function` 的錯誤。查了一下是新版 interact.js 移掉了這個 API，改用 try-catch 包住 unset 呼叫來繞過。

## 尾聲

重構後資料模型從五種類型收斂成一種，BlockEditor 和 BlockCard 的程式碼量都明顯減少，後續要加新功能也不需要在各個 type 分支裡重複處理。Checklist 的 checkbox 互動算是這次比較有趣的部分，純字串操作換掉特定行，沒有引入額外的狀態管理。

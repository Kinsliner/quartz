---
title: "#1 自由畫布：讓 Block 可以放在任何地方"
tags: [Vue 3, FastAPI, interact.js, SQLAlchemy, Pinia]
created: 2026-03-12
phase: 1
---

# #1 自由畫布：讓 Block 可以放在任何地方

> **Tech** Vue 3, Pinia, Tailwind CSS 4, interact.js, FastAPI, SQLAlchemy, SQLite
> **AI** Claude Code

## 源起

Project Board 最初的 Board 頁面是固定三欄 grid 排列，block 只能依序塞進去，沒辦法自由擺放。這種限制在整理資料時很礙事——你沒辦法把相關的東西放近一點，也沒辦法空出一塊位置給某個比較重要的區塊。需要一個可以自由擺放的畫布模式。

## 設計

設計階段考慮了兩個方向：

- **方案 B（可調大小 Grid）**：保留 grid 底層，讓 block 有 `col_span`，可以橫跨多欄。實作比較保守，但還是沒辦法解決「跳列」或「同欄不同位置」的問題。
- **方案 A（自由畫布）**：每個 block 有獨立的 x/y 座標和寬度，用 CSS `position: absolute` 定位，完全自由擺放。

最終選方案 A。自由畫布才能真正解決使用需求，而不是繞過去。

拖放和縮放的實作選 **interact.js** 而非 vue-draggable-resizable，原因是後者的 Vue 3 支援不穩定，interact.js 社群比較活躍且 API 乾淨。畫布本身用 CSS absolute positioning，而非真正的 HTML Canvas element，這樣 block 裡面的 Vue 元件可以正常渲染。

整體架構的改動：

- 後端 Block 模型新增 `x`、`y`、`w` 欄位，預設放在 (0, 0)，寬 280px
- 新增 Page 模型，Block 透過 `page_id` 關聯到分頁，現有資料自動 migration 到「預設」分頁
- 前端 `ProjectBoard.vue` 改為畫布模式，背景加點狀格線，snap-to-grid 20px
- 手機裝置（`window.innerWidth < 768`）自動 fallback 為單欄列表，不載入 interact.js

## 實現

**NaN 讓 block 消失。** 拖曳時 block 偶爾會跑到畫面外消失。追查後發現是 `parseFloat` 的問題——interact.js 在第一次 move 時 `data-x` 尚未設定，`parseFloat(null)` 回傳 NaN，而 `??` 運算子只對 `null`/`undefined` 生效，不管 NaN，導致座標變成 NaN。改用 `isNaN()` 明確判斷就解了。

**群組拖曳時被拖曳的 block 不動。** 圈選多個 block 後一起拖曳，其他 block 有跟著動，但手上那個 block 自己不動。問題出在 Vue reactivity——拖曳中的 block 用 `el.style.left` 手動設位置，但同時更新其他 block 的 reactive x/y 觸發 Vue re-render，把拖曳中 block 的 style 重設回舊值。解法是讓被拖曳的 block 也走 reactive 更新，Vue 的 `:style` binding 統一管理所有 block 的位置。

**畫布下方白色區域無法互動。** 外層 `min-h-screen` 撐出來的空間不屬於畫布 div，自然沒有 mousedown handler。改用 flex 佈局讓畫布 `flex-1` 填滿剩餘空間就解了。

**Page migration 缺 timestamp。** 替現有資料建「預設」分頁時，用 raw SQL INSERT 忘了帶 `created_at`/`updated_at`，FastAPI 的 Pydantic validation 直接報錯。補上 `datetime('now')` 就過了。

**BlockEditor 點擊外部誤關。** 原本用 `@click.self="close"` 來關閉 editor，滑鼠不小心操到外面 block 就被關掉。移掉這個 handler，改為只有明確的關閉按鈕才關閉。

## 尾聲

| 功能 | 狀態 |
|------|------|
| 自由拖放 block | 完成 |
| 右側拖拉調整寬度（160~800px） | 完成 |
| 20px snap-to-grid | 完成 |
| 分頁新增 / 重命名 / 刪除 | 完成 |
| 圈選多選 + Ctrl+點擊 | 完成 |
| 群組拖曳 | 完成 |
| 手機 fallback 列表模式 | 完成 |

從固定 grid 到自由畫布，改動幅度比預期大——光是 `ProjectBoard.vue` 就加了 400 行。但架構理清之後，後續要加功能（像是 resize 高度、鎖定位置）應該都有地方放了。

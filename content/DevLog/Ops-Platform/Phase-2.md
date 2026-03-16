---
title: "#2 Member 軟刪除與 Owner 選擇改版"
tags: [FastAPI, SQLAlchemy, React, TypeScript, 軟刪除]
created: 2026-02-23
phase: 2
---

# #2 Member 軟刪除與 Owner 選擇改版

> **Tech** FastAPI, SQLAlchemy (async), React 19, TypeScript, Tailwind CSS
> **AI** Claude Code

## 源起

原本 Member 的刪除是直接從資料庫移除，但這樣一刪就斷——Task 的 owner_id 會變成懸空外鍵，協作者紀錄也沒人清。需要一套能安全下架 Member、同時把相關資料處理乾淨的機制。

## 設計

改用軟刪除，在 Member 表新增 `deleted_at` 欄位，刪除時只打時間戳記而不移除資料列。這樣外鍵不會爆，歷史紀錄也保得住。

刪除動作觸發的清理流程：
1. 把該 Member 身為協作者的所有紀錄移除
2. 重新分配剩餘協作者的百分比
3. 把所有以該 Member 為 owner 的 Task 的 `owner_id` 設為 NULL

百分比重分配的邏輯原本散在各處，趁這次整理抽成獨立的 `collaborator_service.py`，讓 Member 刪除和未來其他觸發點都能共用。

## 實現

**Schema 和路由的過濾。** Member list 端點要過濾掉 `deleted_at IS NOT NULL` 的資料，get 和 update 端點收到已刪除的 id 要回 404。SQLAlchemy 的 `where` 條件加上去直接搞定，沒有特別的障礙。

**Collaborator 端點的防呆。** 新增協作者時要防止把已刪除的 Member 加進去。在 POST collaborator 時多一層查詢確認 `deleted_at` 為 NULL，否則回 400。這個漏洞如果不補，刪除後的 Member 還是可以透過 API 繞回來當協作者。

**DB migration 的處理。** 開發環境用的是 lifespan 裡 `create_all`，不走 Alembic，但既有的 SQLite 資料庫不會自動補欄位。解法是在 lifespan 裡加一段 `ALTER TABLE` 的 fallback——嘗試加欄位，如果已存在就忽略錯誤，讓開發環境重啟就能自動同步 schema。

**前端 Owner 欄位改版。** 原本 TaskDetail 的 owner 欄位是普通下拉選單，改成 Dialog 彈窗讓使用者從 Member 列表挑選，體驗跟 Collaborator 選人一致。MemberPicker 元件新增 `allowNone` prop，讓 owner 可以選擇「無」，對應後端 `owner_id` 為 NULL 的情況。

## 尾聲

軟刪除本身不複雜，但「刪完要清哪些東西」需要事先想清楚，漏掉任何一個關聯就會留下髒資料。這次順便把百分比重分配抽成共用 service，後續邏輯比較好維護。

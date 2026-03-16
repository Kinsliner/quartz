---
title: "#1 Task Manager & Contribution Calculator 從零建立"
tags: [FastAPI, React, SQLAlchemy, TypeScript, Docker]
created: 2026-02-18
phase: 1
---

# #1 Task Manager & Contribution Calculator 從零建立

> **Tech** FastAPI, SQLAlchemy 2.0, SQLite, React 19, Vite, TypeScript, Tailwind CSS v4, Docker
> **AI** Claude Code

## 源起

需要一個工具來管理專案任務、追蹤成員完成狀況，並把點數換算成實際金額——100 點對應 50,000 NTD，作為績效獎金或外包費用的計算依據。市面上的工具要嘛太重、要嘛無法自訂欄位，所以決定自己刻一個。

## 設計

技術選型比了四個方向：Next.js+SQLite、FastAPI+React、Django+React、FastAPI+Next.js，從開發效率、部署複雜度、前後端分離彈性等八個維度加權評分。Next.js 的 full-stack 方案雖然部署最簡單，但 API 層的彈性不夠；Django 生態成熟但對這個規模來說太重。最後選 FastAPI+React（Vite）：後端邏輯清晰、非同步支援好，前端用 Vite 開發體驗快，TypeScript 加上 shadcn/ui 風格元件可以快速組出夠看的 UI。

資料模型設計了六張表：

- `projects` / `members` — 基本的專案與成員管理
- `tasks` — 任務主體，含點數、owner、狀態
- `task_collaborators` — 協作者與各自的點數比例
- `checklist_items` — 任務下的子項目，用來卡狀態變更
- `settings` — 全域可配置參數（如每點換算金額）

貢獻度計算的邏輯：任務 owner 拿完整點數扣掉協作者分走的比例，協作者按設定比例分配。Dashboard 聚合後直接算出每人的金額。

## 實現

**Checklist 卡狀態這件事。** 業務邏輯裡有一條規則：任務有未完成的 checklist item 就不能移到 `done`。這個驗證放在 service 層，狀態變更前先查一次 checklist，有未完成的直接回 400。驗證測試兩種情境——有未完成項目時拒絕、全部完成後允許——都確認通過。

**貢獻度計算的精度。** 點數分配用浮點數比例，owner 實際拿到的點數是 `task.points * (1 - sum(collaborator_ratios))`，協作者是 `task.points * ratio`。這個設計在多人協作時如果比例加起來超過 1.0 沒有保護，後來在 schema 層加了 validator 確保新增協作者時總比例不能超過 100%。

**前端 bundle 偏大。** Vite build 出來的 bundle 約 899KB，主要是 Recharts 和幾個 UI 套件沒有 tree-shaking 乾淨。這次先讓功能跑通，code-splitting 留到下一個階段處理。

後端驗證跑了完整的 API 流程，包含 CRUD、狀態機、貢獻度計算、Dashboard 聚合，全部通過。前端 TypeScript 編譯和 Vite build 也都沒有錯誤。

## 尾聲

| 項目 | 結果 |
|------|------|
| 後端 API 端點 | 30+ endpoints，全數驗證通過 |
| 前端頁面 | 10 個頁面、20+ 個元件 |
| Build 時間 | 5.4 秒 |
| Bundle 大小 | ~899KB（待優化） |
| 貢獻度計算範例 | Alice 70點=35,000 NTD / Bob 30點=15,000 NTD |

從選型評估到完整實作一次跑完，整個基礎層算是建好了。剩下 code-splitting、loading/error 狀態處理、響應式佈局這些收尾工作留到 Phase 2。

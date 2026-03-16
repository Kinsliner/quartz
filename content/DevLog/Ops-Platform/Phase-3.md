---
title: "#3 時程檢視功能——甘特圖與月曆"
tags: [FastAPI, React, TypeScript, 甘特圖, 月曆, PDF匯出]
created: 2026-03-11
phase: 3
---

# #3 時程檢視功能——甘特圖與月曆

> **Tech** FastAPI, SQLAlchemy (async), React 19, TypeScript, Tailwind CSS, html2canvas-pro, jsPDF
> **AI** Claude Code

## 源起

專案管理工具需要「時程」頁籤，提供甘特圖與月曆兩種檢視模式，讓使用者能直觀地安排與瀏覽任務排程。核心特色包括：

- 自建甘特圖與月曆（非第三方套件），完整掌控工作日跳過邏輯與視覺風格
- 拖曳互動：移動任務、調整起始日、調整工期，皆自動跳過休息日
- 三層假日系統：專案覆寫 > 全域覆寫 > 每週休息日
- 右鍵選單直接切換日期的工作日/假日屬性
- 支援里程碑（菱形標記）與無結束日任務（半透明漸層延伸）
- 含子專案任務的切換檢視
- PDF 匯出（含多頁分割與頁首頁尾）
- 全域設定頁的工作日曆管理介面

## 設計

### 資料模型

選擇 `start_date` + `duration_days`（工作天數）而非 `start_date` + `end_date`，原因：
- 更符合使用者心智模型：「這個任務要做幾天」
- 調整假日設定時，結束日期自動重算，不需手動修正

### 假日系統

三層優先級設計：
1. **專案層覆寫** — 該專案獨有的假日/補班設定
2. **全域覆寫** — 國定假日、補班日等
3. **每週休息日** — 預設週六、日，可於設定頁調整

### 自建元件

甘特圖與月曆皆為自建，主要考量：
- 工作日/假日的不等寬欄位（工作日 40px、假日 14px 灰色窄欄）
- 未排程任務區域、右鍵選單等客製需求
- 與專案整體視覺風格統一

### 拖曳實作

使用原生 Pointer Events 而非 @dnd-kit，因為甘特圖需要像素級精確控制：
- **移動**：整條橫條平移
- **左邊緣拖曳**：調整起始日，工期自動調整以保持結束日不變
- **右邊緣拖曳**：調整工期

## 實現

開發分十個階段完成：

| 階段 | 內容 |
|------|------|
| P1 | Task model 新增 start_date / duration_days / is_milestone |
| P2 | WorkCalendar + ProjectWorkCalendar model & API |
| P3 | 前端 workday-utils + types + API hooks |
| P4 | 甘特圖基本渲染 |
| P5 | 甘特圖拖曳互動（move / resize-left / resize-right + 未排程排入） |
| P6 | 日期格右鍵選單（全域/專案假日切換） |
| P7 | 日曆檢視（月視圖 + 任務跨日橫條 + 右鍵假日選單） |
| P8 | 子專案切換（後端 include_children + 前端 toggle） |
| P9 | PDF 匯出（html2canvas-pro + jsPDF，多頁支援） |
| P10 | 全域設定頁工作日曆管理介面 |

**遇到的問題：**

1. **TypeScript 嚴格模式**：`split("-").map(Number)` 回傳值可能為 undefined，改用非空斷言 `parts[0]!` 解決
2. **PDF 匯出捲動內容**：甘特圖有水平捲動，匯出前暫時展開 overflow 容器，匯出後還原
3. **拖曳精度**：原生 Pointer Events 搭配 `xToDateStr()` 將像素座標轉換為最近的工作日日期

## 尾聲

| 項目 | 結果 |
|------|------|
| 新增 API 端點 | 8 endpoints（全域假日 CRUD + 專案覆寫 + 查詢） |
| 新增前端元件 | 12 個元件 + 2 個 utility modules |
| 後端新增檔案 | 5 個（models / schemas / services / routers） |
| 前端新增檔案 | 12 個 |

自建甘特圖與月曆的工作量比預期大，但換來的是對工作日邏輯和拖曳行為的完全掌控。下一步可能加入任務間依賴關係（前置任務箭頭連線）和關鍵路徑標示。

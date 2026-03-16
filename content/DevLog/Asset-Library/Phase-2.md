---
title: "#02 Web UI 大改版與掃描器修正"
tags: [React, TypeScript, FastAPI, Unity, UI/UX]
created: 2026-03-04
phase: 2
---

# #02 Web UI 大改版與掃描器修正

> **Tech** React 18, TypeScript, Tailwind CSS, FastAPI, Unity Batch Mode
> **AI** Claude Code

## 源起

前一個 phase 把 React 前端框架建起來，但 UI 體驗還很陽春。卡片太小、選取素材的 sidebar 會把 layout 推歪、詳情頁資訊堆在一欄顯得擠。同時掃描器在 CLI 模式下有兩個 bug 導致無法正常觸發 Unity batch mode。趁這次一起清掉。

## 設計

UI 的參考對象是 CGTrader——素材電商網站的卡片和詳情頁佈局已經被驗證過，不用重新發明輪子。

下載清單的互動方式做了根本性的改變：原本是卡片上有 checkbox，右邊浮出一個 SelectionSidebar。checkbox 一多就很亂，sidebar 每次開閉都造成 layout shift。新做法是 hover 才顯示「+」按鈕，清單藏在 Header 右側的下拉面板（DownloadListDropdown）。對比如下：

| 項目 | 舊設計 | 新設計 |
|------|--------|--------|
| 進入清單 | 卡片 checkbox | hover「+」按鈕 |
| 清單位置 | 右側 SelectionSidebar | Header 下拉面板 |
| Layout shift | 有 | 無 |

色彩系統也重新定義，統一用語義化的 token（`bg-elevated`、`text-muted`、`shadow-card`），accent 換成 `#8b5cf6` 紫色，讓整體調性一致。

## 實現

**SelectionSidebar 的移除。** 這個元件跟 BrowsePage 的 grid layout 耦合在一起，刪掉之後要確保 grid 不會因為沒有右側佔位而跑版。原本 grid 是靠 sidebar 存在與否來決定寬度，改版後 grid 直接撐滿，反而更乾淨。

**Admin 側欄高度不足。** App.tsx 用的是 `min-h-screen`，在內容不夠長的 admin 頁面，側欄就只有內容的高度，右邊是白的。把根元素改成 `h-screen` + `overflow-hidden`，AdminSidebar 設 `h-full`，問題消失。

**Tag 來源不完整。** TagAutocomplete 原本只從 `GET /api/tags/vocabulary` 抓預設詞彙表，但用戶手動加的 tag 不在詞彙表裡，輸入時沒有補全提示。解法是新增一支 `GET /api/tags/all` endpoint，把 vocabulary 和 manifest 裡現有的 tag 合併回傳，前端只打這一支。

**FilterBar 缺少 tag 篩選 UI。** 原本只有文字搜尋，想按 tag 篩就得手動打 query string。改版後 FilterBar 內嵌 TagAutocomplete，選完 tag 產生 chip，Backspace 或點 × 移除，篩選條件直接反映在 URL query。

**掃描器 unity_exe fallback。** `run_scan_cli` 裡寫的是 `unity_exe or "Unity"`，CLI 不傳 `--unity` 參數時，fallback 是字串 `"Unity"` 而不是 config 裡 auto-detect 的路徑。改成 `unity_exe or config.unity_executable or "Unity"` 就好了，但這個 bug 讓掃描一直失敗，花了點時間才追到這層。

**executeMethod namespace 錯誤。** Unity batch mode 的 `-executeMethod` 參數要給完整的 namespace 路徑。原本寫的是 `AssetLibraryScanner.Scan`，Unity 找不到這個 class，log 裡印 "class could not be found" 但沒有更多資訊，一開始以為是路徑或版本問題。確認 C# 原始碼的 namespace 是 `AssetLibrary.Editor` 之後，改成 `AssetLibrary.Editor.AssetLibraryScanner.Scan`，CLI 和 async 兩個呼叫點都要改。

## 尾聲

修完掃描器之後跑了完整流程驗證：Phase 1（metadata 掃描）+ Phase 2（截圖）+ Publish，10,035 筆素材全部保留，沒有遺漏或重複。UI 改版讓整體操作感覺乾淨很多，特別是下載清單不再搶版面。

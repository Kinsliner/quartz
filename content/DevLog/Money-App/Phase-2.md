---
title: "#02 分類系統、統計圖表與設定頁"
tags: [React Native, Expo, SQLite, TypeScript, SVG]
created: 2026-02-25
phase: 2
---

> **Tech** Expo, React Native, TypeScript, SQLite, react-native-svg
>
> **AI** Claude Code

## 源起

Phase 1 完成了基本的記帳流程，但還停在「能用」的狀態——只有單層分類、沒有編輯功能、首頁一次載入所有資料、也沒有任何統計視圖。Phase 2 目標是把 APP 推進到「好用」：有結構的分類系統、可編輯記錄、看得懂花了多少錢、還能換個自己喜歡的主題色。

## 設計

**顏色語意的調整。** 支出顏色從紅色改成琥珀黃 `#D69E2E`。紅色在 UI 語境裡通常代表警示或錯誤，用來標記支出會讓人感覺「欠債」；換成偏暖的琥珀黃，語意更接近「這是花費」，不帶負面情緒。

**父子分類架構。** 單層分類在記帳 APP 裡很快就不夠用，但多層無限巢狀又太複雜。選擇固定兩層：父分類單選（決定大方向）、子分類多選選填（補充細節）。UI 上做成兩步驟的 CategoryPicker——先網格選父分類，確認後展開 chips 選子分類——視覺上清楚，操作路徑也短。

預設分類預埋了 47 個（8 支出父 + 19 子、5 收入父 + 9 子、2 系統未分類），覆蓋大多數日常場景，同時開放用戶自訂。「未分類」設計為系統保留分類，不可刪除，刪除其他分類時舊記錄自動歸入。

**動態主題系統。** 四組主題配色（藍色清新、紫色優雅、暖色自然、深色模式）。實作上選擇 `useColors()` hook + `createStyles(colors)` factory + `useMemo` 的組合。相對於靜態 StyleSheet，這樣每個元件拿到 colors 之後自行生成 style，主題切換只需要更新 SettingsContext，不用全局重渲染。所有元件在這個批次統一重構一遍。

**圓餅圖。** 統計頁要顯示各分類佔比。評估過 Victory Native 和 react-native-charts-wrapper，這類圖表庫相依複雜、體積大，而且客製化空間有限。最後選擇直接用 `react-native-svg` 從零建 donut 圖——程式碼不到 150 行，完全掌控樣式，也不需要多一個重型依賴。

**CSV 匯出。** 加 BOM（`\uFEFF`）讓 Excel 在 Windows 上直接識別 UTF-8，避免中文亂碼的常見踩坑。

## 實現

**expo-file-system v19 API 變更。** CSV 匯出功能寫完之後跑起來直接崩潰。查了一下，expo-file-system v19 廢掉了舊的 `cacheDirectory` + `EncodingType` 寫入方式，改成 `File` class + `Paths` API。把寫入邏輯換過去之後恢復正常。這種 SDK 升版帶著 breaking change 但版本號藏在 package.json 裡不顯眼，很容易踩到。

**SQLite migration 問題。** 新增 `subcategoryIds` 欄位之後，舊版 DB 在啟動時會炸。原本的 migration 邏輯是按版本號分段執行，但這有個盲點——如果用戶跳版升級，中間的 migration 可能沒被執行到。改成 idempotent 的結構檢查：每次啟動都用 `PRAGMA table_info` 確認欄位是否存在，不存在才 `ALTER TABLE` 補上。不依賴版本號，升級路徑任意，不會出錯。

**JSON.parse(undefined) 崩潰。** 舊資料的 `subcategoryIds` 欄位是 `undefined`（因為欄位是後來加的），`rowToRecord` 直接跑 `JSON.parse` 會炸。在解析前加上 fallback，舊記錄安全地回傳空陣列。

**render 中 setState 反模式。** 編輯頁（`add.tsx` 複用，透過 `?id=` 判斷模式）在載入記錄資料後需要自動選取對應分類。一開始直接在 render 流程裡呼叫 setState 來更新分類選取狀態，React 在偵測到這個模式之後會警告，嚴重時會無限迴圈。改用 `useEffect` 監聽記錄 id，載入完成後在 effect 裡統一 setState，乾淨解決。

## 尾聲

| 項目 | 內容 |
|------|------|
| 批次數 | 6 |
| 設計變更 | 8 項 |
| 預設分類 | 47 個 |
| 修復 Bug | 4 個 |
| 新增元件 | DatePicker, CategoryPicker, MonthSelector, StatsView, SettingsContext |

六個批次把 APP 從能記帳推進到真的好用——有結構的分類、可以回頭改的編輯功能、知道錢花到哪的統計頁、還有主題和匯出。Migration 那個坑讓人印象深刻，不依賴版本號、改成結構檢查的思路值得之後繼續沿用。

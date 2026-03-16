---
title: "#01 用 TypeScript 從零刻一個手機記帳 APP"
tags: [TypeScript, React Native, Expo, SQLite, expo-router]
created: 2026-02-24
phase: 1
---

> **Tech** TypeScript, React Native, Expo SDK 54, expo-sqlite, expo-router
>
> **AI** Claude Code

## 源起

C# 開發背景，想借一個實際專案把 TypeScript 跑起來。記帳是邏輯夠清楚又夠完整的題目——有資料模型、有商業邏輯、有 UI 互動，剛好適合拿來練手。目標是做到能用、架構不亂、型別安全。

## 設計

框架選 Expo 而不是裸 React Native，省去環境設定的麻煩，`npx create-expo-app` 直接生出 TypeScript 模板。路由用 expo-router 的檔案式路由，跟 Next.js 的概念一樣，直覺。

資料庫選本地 SQLite（expo-sqlite），記帳不需要後端、不需要同步，資料放裝置上最單純。

架構照分層走：

```
UI (頁面 + 元件)
  ↓
Hooks (useRecords, useMonthlySummary)
  ↓
Service (純 TS 函式，計算邏輯)
  ↓
Repository (SQL 查詢)
  ↓
SQLite
```

Service 層故意做成純函式、不碰資料庫，測試起來比較乾淨。Repository 集中管所有 SQL，UI 層完全不知道下面是什麼資料庫。

## 實現

**分類資料的放法。** 分類（13 類：支出 8、收入 5）是靜態資料，不需要存進 SQLite。最後把它定義成 TypeScript 常數，直接 import 用，避免每次開 APP 都要查一次資料庫。

**月度摘要查詢。** 首頁要顯示當月的收入總計、支出總計和結餘。Repository 裡用一條 SQL `GROUP BY type` 完成，Service 層再把結果算成 balance。分兩層做的好處是 SQL 只管拿資料，計算邏輯在 TypeScript 裡清楚可讀。

**日期分組顯示。** 記錄列表要按日期分組，每個日期是一個 section header。用 `reduce` 把陣列折成 `Record<string, TransactionRecord[]>`，再轉成有序的 section 陣列。C# 的 LINQ 思維在這裡直接套用沒有違和感。

**長按刪除的體驗。** 列表項目長按觸發刪除，加了 Alert 確認對話框避免誤刪。React Native 的 `Alert.alert` API 跟 C# 的 `MessageBox.Show` 概念一樣，上手快。

**FAB 按鈕。** 首頁右下角的浮動新增按鈕用 `position: absolute` + `bottom`/`right` 定位，搭配 `@expo/vector-icons` 的加號圖示。Safe area 的 bottom inset 要另外處理，不然會被 Home Indicator 擋住——用 `react-native-safe-area-context` 的 `useSafeAreaInsets()` 取偏移量加進去。

## 尾聲

TypeScript 編譯零錯誤，Expo export 打包成功。C# 的型別思維在 TypeScript 裡大部分都能直接對應，反而是非同步模式（Promise vs async/await 在 React hooks 裡的用法）花了比較多時間適應。分層架構讓整個專案在規模變大時還能維持清晰，這個習慣值得帶進後續開發。

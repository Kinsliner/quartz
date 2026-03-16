---
title: "#04 Records 頁面 Registry Pattern 重構"
tags: [React Native, TypeScript, Expo, Refactoring, Design Pattern]
created: 2026-02-25
phase: 4
---

> **Tech** React Native, TypeScript, Expo Router, expo-sqlite
>
> **AI** Claude Code

## 源起

`records.tsx` 同時管兩件事：顯示模式切換，以及清單本身的渲染邏輯。清單模式的 JSX 直接寫在頁面檔案裡，統計模式卻獨立成 `<StatsView>` 元件，前後不一致。Segment 按鈕是硬編碼兩個 `<TouchableOpacity>`，要新增第三種模式就得同時改 JSX、if/else 判斷、還有渲染部分，散落三處。

## 設計

目標是讓新增顯示模式只需要做兩件事：寫一個元件、在設定表加一行。

先定義兩個型別放進 `types/index.ts`：

- `ViewModeProps`：所有顯示模式共用的 props 介面（只傳 categories）
- `ViewModeConfig`：單一模式的設定結構，包含 `key`、`label`、`component` 和 `showFab`

`showFab` 放在 config 裡的原因是：FAB 要不要顯示是「這個模式的特性」，不是 parent 頁面應該判斷的事。這樣 records.tsx 就不用寫任何 if/else 來決定 FAB 的顯示。

各 View 自己管資料這個決定是刻意的。`ListView` 內建 `useRecords()`，`StatsView` 有自己的 date range fetch 策略，兩者完全獨立。Parent 只負責組合，不傳資料進去。

## 實現

**抽出 ListView。** 清單模式原本散在 records.tsx 裡，包含 `useRecords()`、日期分組、`SectionList`、空狀態 JSX。直接搬到 `components/ListView.tsx` 成為獨立元件，對齊 StatsView 的結構方式。抽出後 records.tsx 的清單渲染部分整個消失。

**SegmentControl 通用化。** 原本是兩個硬編碼的 `<TouchableOpacity>`，改成接受 `modes: ViewModeConfig[]` 陣列，自動 map 出對應按鈕。按鈕樣式、選中狀態邏輯都封裝在元件內，外部只傳 modes 和 onSelect。

**Registry 集中管理。** `components/viewRegistry.ts` 是一個純設定陣列，把 ListView 和 StatsView 用 ViewModeConfig 的格式登記進去。records.tsx 只要 import 這個陣列，剩下的事（渲染哪個元件、顯不顯示 FAB）都從 config 讀出來。

**StatsView 零修改。** 原有的 props 結構本來就和 ViewModeProps 相容，不需要調整。

重構完 records.tsx 從 88 行縮到約 48 行，只剩 SegmentControl、ActiveView、FAB 三個組合。

## 檔案影響

| 檔案 | 動作 | 說明 |
|------|------|------|
| `types/index.ts` | 修改 | 新增 ViewModeProps + ViewModeConfig |
| `components/ListView.tsx` | 新增 | 從 records.tsx 抽出清單模式 |
| `components/SegmentControl.tsx` | 新增 | 通用 Segment 控制元件 |
| `components/viewRegistry.ts` | 新增 | 模式註冊表 |
| `app/(tabs)/records.tsx` | 修改 | 88 行 → 48 行 |
| `components/StatsView.tsx` | 不動 | props 已相容 |

## 尾聲

跑 `npx tsc --noEmit` 零錯誤確認型別都接得住。未來要加新的顯示模式（例如月曆視圖），只需要新增一個元件加上 ViewModeProps，然後在 viewRegistry 加一行，records.tsx 和 SegmentControl 完全不用碰。

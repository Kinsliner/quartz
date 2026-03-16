---
title: "#03 圓餅圖互動與動畫"
tags: [React Native, SVG, Animation, TypeScript, Expo]
created: 2026-02-25
phase: 3
---

> **Tech** Expo, React Native, TypeScript, react-native-svg, requestAnimationFrame
>
> **AI** Claude Code

## 源起

Phase 2 結尾把 PieChart 的 API 重寫了一遍，但 StatsView 還沒跟上，一開 APP 就 crash。趁著修 crash 的機會，把整個統計頁面打掉重練：圓餅圖要有填充動畫、點選分類要有回饋、還要解決「編輯記錄之後統計頁不更新」的問題。

## 設計

**動畫驅動方式的選擇。** 一開始嘗試 Animated + AnimatedG 搭配 `interpolate` 做 SVG path 動畫。問題是 SVG arc path 的幾何計算需要逐幀重算，Animated 的 `interpolate` 只適合線性映射數值，處理「從一條線逐漸展開成完整圓餅」這種效果，只能用 `requestAnimationFrame` 手動逐幀驅動。最終的架構是 `useFillAnimation` hook，內部跑 rAF loop，每幀算出 0→1 的進度值，元件拿到進度值之後自行計算每個 slice 的 endAngle 和裁切邊界。

**兩段動畫分開觸發。** 外圈（父分類）和內圈（子分類）有不同的觸發時機，各自維護一個 fill 進度。外圈在資料變化時觸發（600ms），內圈在選取父分類時觸發（400ms），用 `dataFingerprint` 和 `selectedIndex` 分別作為 effect 依賴。

**觸控分層。** 圓餅圖中心的孔洞和外圍空白都需要捕捉點擊來取消選取，但不能干擾 slice 的 onPress。做法是兩層：SVG 內放一個透明 Rect（只在有選取時才出現）負責孔洞區域，StatsView 的圖表區用 Pressable 包裹負責外圍空白。slice 的 Path onPress 本身有優先權，不會被蓋過。

## 實現

**StatsView crash 修復。** 舊的 StatsView 還在傳 `innerData` prop（上個 session 已移除），PieChart 接不到直接炸。把所有 API 對齊：移除 InnerSlice import，新增 `selectedIndex` state，`buildSubData` 改成返回 `PieSlice[]`，再計算 `innerRing`、`centerLabel`、`centerAmount` 傳進去。

**填充動畫的幾何計算。** 每幀拿到 `fill`（0→1）之後，乘上 360° 得到 `visibleAngle`。跑一遍所有 slice，把每個 slice 的 `endAngle` 和 `startAngle` 都 clamp 在 `visibleAngle` 以內——如果 startAngle 已經超過 visibleAngle，這個 slice 就完全不畫；如果 endAngle 超過，就裁到邊界。% 標籤的顯示也卡在 slice 完全展開才出現，避免動畫過程中數字一直跳。

**清單排序與 LayoutAnimation。** 點選圓餅圖的父分類之後，下方清單要把選中的分類提到最上面並自動展開子項目。排序邏輯很直接：`selectedIndex !== null` 時把對應分類排到陣列第一個，其他照金額排序。麻煩的是顏色——顏色是用陣列 index 取 palette，排序之後 index 對不上了。解法是在原始資料裡記 `originalIndex`，取色時永遠用 `originalIndex`，不受排序影響。`LayoutAnimation.easeInEaseOut` 讓清單位置交換有滑順過渡，Android 需要額外呼叫 `UIManager.setLayoutAnimationEnabledExperimental(true)` 才能啟用。

**外圈標籤從 SvgText 改成 View overlay。** 原本用 SVG 的 `<Text>` 畫 % 數字，但要在標籤裡加 MaterialIcons 圖示就做不到——SVG text 不能混入 React Native 元件。改成絕對定位的 View，蓋在 SVG 上方，每個標籤的位置由 arc 中心點算出來再轉換成螢幕座標。`pointerEvents="none"` 讓這層 View 不影響底下 SVG 的觸控事件。非選取狀態的標籤在選取發生後同步降低 opacity，視覺上突出選中的分類。

**統計頁面即時更新。** 發現問題的路徑很直接：在記帳頁編輯一筆記錄，切回統計頁，數字沒動。原因是 StatsView 用 `useEffect` 監聽 `dateRange`，切頁面不會觸發 dateRange 變化，所以不重新查詢。換成 `useFocusEffect`，每次頁面從背景回到前景都重新跑一次資料庫查詢。

## 尾聲

| 項目 | 內容 |
|------|------|
| 主要修改檔案 | PieChart.tsx, StatsView.tsx |
| 新增動畫 | 外圈填充（600ms）、內圈填充（400ms）、清單排序、中心文字 fade-in |
| 修復問題 | API crash、統計頁不更新、顏色排序錯位 |
| 新增互動 | 點選切換父分類、點空白取消選取、清單自動展開排序 |

這次大部分時間花在 SVG 動畫的幾何計算和觸控分層邏輯上。requestAnimationFrame 驅動 path 動畫雖然比 Animated API 手動，但完全掌控每幀輸出，debug 起來反而比較直覺。

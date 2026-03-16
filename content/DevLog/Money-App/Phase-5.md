---
title: "#05 PagerView 分頁滑動 + 首頁動態月份卡"
tags: [React Native, Expo, PagerView, SectionList, UX]
created: 2026-02-27
phase: 5
---

> **Tech** React Native, react-native-pager-view, SectionList, expo-router
>
> **AI** Claude Code

## 源起

原本的 Tab 滑動切換是用 PanResponder 自己刻的 `SwipeableTabView`——手勢偵測邏輯複雜，動畫也不夠流暢。同時，首頁的收支總結卡永遠顯示當月數字，使用者往上滾查舊記錄時，卡片內容不會跟著變，資訊對不上。這兩塊都影響使用體驗，決定一起處理。

## 設計

**Tab 滑動方案選型。** PanResponder 的問題在於要自己計算手勢偏移量、接管 scroll 事件衝突，長期維護成本高。`react-native-pager-view` 是原生 ViewPager（Android）/ UIScrollView（iOS）的包裝，滑動動畫和邊界回彈都交給原生層處理，不需要 JS 端的動畫計算。缺點是換掉之後要同步改掉所有 tab 頁面的依賴方式。

原本各 tab 頁面透過 `useFocusEffect`（expo-router）判斷自己是否被看到，改成 PagerView 之後這個 hook 不再可靠，因為 PagerView 不走 expo-router 的頁面生命週期。解法是新增一個 `PagerFocusContext`，由 layout 層注入目前的 active index，各 tab 頁面訂閱它來判斷是否可見。

**首頁動態月份的資料流。**

1. SectionList 的資料按月分組，跨月時插入分隔線
2. `onViewableItemsChanged` 追蹤畫面最上方可見的記錄，取出它的 `date` 欄位換算成年月
3. 總結卡根據這個月份重新查詢收支，標題從固定當月改成動態顯示
4. `useMonthlySummary` 加入 `Map` 快取，已查過的月份直接回傳，不再打 DB

## 實現

**移除 SwipeableTabView 的連帶改動。** 四個 tab 頁面都有 import SwipeableTabView 並把自己的內容包在裡面，需要逐一拆掉。重構完才發現 header bar 原本是由 expo-router 的 `<Tabs>` 提供，移除之後整個 header 就消失了，內容頂到狀態列。補回的方式是在 `_layout.tsx` 最外層加 SafeAreaView，自己刻一個標題列顯示當前 tab 名稱。

**`PagerFocusContext` 取代 `useFocusEffect`。** 直接把 PagerView 的 `onPageSelected` 回傳的 index 存進 context，各 tab 頁面拿 index 跟自己的 tab index 比對就知道是否 active。改法比 useFocusEffect 更明確，也不需要依賴 expo-router 的路由狀態。

**`viewabilityConfigCallbackPairs` 與 SectionList 不相容。** 原本想照 FlatList 的做法用 `viewabilityConfigCallbackPairs` 傳入一個 ref，但 SectionList 內部的 `_convertViewable` 會繞過這個 API 的 section 轉換邏輯，導致回調中拿不到正確的 section 資訊，回調也沒觸發。改回傳統的 `onViewableItemsChanged` + `viewabilityConfig` 兩個獨立 prop，並改從 `item.date`（記錄物件本身）取日期而非依賴 section 轉換。

`keyExtractor` 也遇到防禦性問題——SectionList 在 viewability 計算的某些時機會傳入未完全初始化的 item，導致 `item.id.toString()` crash。加了 optional chaining 防禦。

**快取 invalidation 的時機。** `useMonthlySummary` 的快取用 `Map<string, Summary>` 存，key 是 `YYYY-MM` 字串。使用者新增記錄後切回首頁，快取可能還在導致畫面不更新。解法是在 `usePagerFocus` 偵測到切回首頁 tab 時，呼叫 hook 暴露的 `invalidate()` 清掉快取，讓下一次的月份查詢強制重打 DB。

## 尾聲

| 項目 | 狀態 |
|---|---|
| Tab 原生滑動動畫 | 完成，移除 PanResponder 方案 |
| 跨月分隔線 | 完成 |
| 總結卡動態切月 | 完成 |
| useMonthlySummary 快取 | 完成，含 invalidation |

Tab 層整個換過，首頁的資訊密度也提升了。比較值得記的是 SectionList 的 viewability API 跟 FlatList 行為不一致這件事——文件沒寫清楚，靠實測才發現。

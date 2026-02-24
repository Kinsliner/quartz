---
title: "#03 多指令管理"
tags: [WPF, MVVM, C#, ObservableCollection]
created: 2025-10-24
phase: 3
---

# #03 多指令管理

> **Tech** WPF, C#, ObservableCollection, DataTrigger
> **AI** Claude Code

## 源起

Phase 2 做完用了幾天，發現一個專案只存一條指令根本不夠。前端專案光常用的就有 dev、build、test、lint，每次只能記一條，其他還是要手打。這次要把單一指令升級成指令列表。

## 設計

資料結構從 `string` 換成 `ObservableCollection<string>`。ViewModel 新增一組 CRUD 操作的 Command：StartAddCommand、ConfirmAddCommand、CancelAddCommand、RemoveCustomCommand。

UI 用 DataTrigger 控制新增輸入框的顯示隱藏，不在 code-behind 寫邏輯。每條指令都有獨立的 Run 和刪除按鈕。

## 實現

**List 不會通知 UI。** 第一版用 `List<string>`，新增指令後畫面完全不動。查了才知道 List 不發 CollectionChanged 事件，改用 ObservableCollection 後瞬間解決。

**Binding 預設雙向的坑。** DataTemplate 裡的 TextBlock Binding 一啟動就崩，錯誤訊息說「雙向繫結需要 Path」。WPF 在某些情況下預設雙向，明確指定 `Mode=OneWay` 修好。

**三輪 UI 調整：**

1. Add 按鈕從列表下方搬到標題旁邊，固定位置不被擠走
2. 右側面板外包 ScrollViewer，指令多了也能滾動，不會溢出
3. 統一所有按鈕樣式——圓角、hover 變色、顏色語意化（藍=新增、綠=執行、紅=刪除、灰=取消）

XAML 巢狀太深容易迷路。寫到一半搞不清楚在哪層，加 Margin 加錯位置整個跑版。後來 checkout 回穩定狀態重寫，用更扁平的結構，維護起來清楚很多。

## 尾聲

| 項目 | 結果 |
|------|------|
| 指令數量 | 不限（ObservableCollection） |
| UI 迭代 | 3 輪 |
| 按鈕樣式 | 統一圓角 + 顏色語意 |

從單一指令到多指令是使用體驗上質的變化。Fast CLI Tool 的核心功能到這邊基本完整。

---

返回 [[專案/Fast CLI Tool/index|Fast CLI Tool 專案]]

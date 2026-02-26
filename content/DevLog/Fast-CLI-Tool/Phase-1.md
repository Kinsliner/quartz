---
title: "#01 設定系統"
tags: [WPF, MVVM, C#]
created: 2025-10-24
phase: 1
---

> **Tech** WPF, C#, MVVM, JSON
>
> **AI** Claude Code

## 源起

Fast CLI Tool 已經能管理多個專案路徑、選擇不同的 CLI 命令來開啟專案，但預設的 CLI 命令寫死在程式裡。每次新增路徑都要手動改，用久了很煩。需要一個設定系統讓使用者自訂預設值。

## 設計

設定系統的架構分三層：

1. **AppSettings model** — 存設定資料（目前只有預設 CLI 命令）
2. **SettingsService** — 負責讀寫 AppData 下的 `settings.json`
3. **SettingsView** — 右側面板用 Tab 切換 Path Details 和 Settings

選 Tab 而不是彈窗，是考慮到未來可能加更多設定項目，Tab 比較好擴充。

保存策略是即時寫入——透過 PropertyChanged 事件，使用者一改就自動存。設定項少、改動頻率低，沒必要做延遲保存。

## 實現

**先清掉魔法參數。** 動手之前先把程式裡散落的硬編碼字串統一成常數。PathItem 預設 `claude.cmd`、MainViewModel 備用值卻是 `gemini.cmd`，這種不一致早晚出問題。提取成單一常數後，全部指向同一個來源。

**Tab 切換的狀態問題。** 一開始切到 Settings 時會清空目前選中的路徑，結果切回 Path Details 要重新選。改成切換時不清空選擇狀態，使用者回來就看到剛才的路徑，直覺很多。

**Command 職責要分清。** 偷懶想用既有的 SelectPathCommand 處理 Tab 切換，但它收到 null 參數就直接 return，導致點 Tab 沒反應。最後老實新增 ShowPathDetailsCommand 和 ShowSettingsCommand，各管各的事。

## 尾聲

設定系統本身功能不多，但把 JSON 持久化、自動保存、Tab UI 的基礎都搭好了。後續要加新設定項只需要在 model 加屬性、在 view 加控制項就行。


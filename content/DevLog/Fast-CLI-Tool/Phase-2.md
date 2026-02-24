---
title: "#02 自訂指令"
tags: [WPF, MVVM, C#]
created: 2025-10-24
phase: 2
---

# #02 自訂指令

> **Tech** WPF, C#, Process, cmd.exe
> **AI** Claude Code

## 源起

每天開發都在重複同一件事：cd 到專案目錄、打 `npm run dev` 或 `python manage.py runserver`。Fast CLI Tool 已經在管理這些路徑了，讓它順便記住每個專案要跑的指令是很自然的延伸。

## 設計

在 PathItem model 加一個 CustomCommand 屬性，因為 PathItem 本來就有 PropertyChanged 和自動保存機制，新屬性直接繼承這些能力，不用額外寫儲存邏輯。

執行用 `cmd.exe /k`（不是 `/c`），視窗保持開啟讓使用者看 log。ProcessStartInfo 設定好工作目錄，確保指令在正確路徑下執行。

UI 放在右側 Path Details 區塊：一個 TextBox 輸入指令、一個綠色 Run 按鈕。指令為空時按鈕自動 disabled。

## 實現

這次開發很順，基本上就是 Phase 1 架構的收益：model 加屬性、ViewModel 加 Command、View 加 UI 元素，兩小時內搞定，沒有破壞既有功能。

**發佈方式選了 self-contained single file：**

```
dotnet publish -c Release -r win-x64 --self-contained true -p:PublishSingleFile=true
```

產出 121 MB 的 exe，偏大，但使用者不用裝 .NET Runtime，下載就能跑。

## 尾聲

| 項目 | 結果 |
|------|------|
| 新增屬性 | PathItem.CustomCommand |
| 執行方式 | cmd.exe /k |
| 發佈大小 | 121 MB (self-contained) |

單一指令的版本已經能用，但很快就發現一個專案只能存一條指令不夠用。

---

返回 [[專案/Fast CLI Tool/index|Fast CLI Tool 專案]]

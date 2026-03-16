---
title: "#03 Tool Use 專案探索"
tags: [Anthropic Tool Use, Claude API, Unity]
created: 2025-10-13
phase: 3
---

> **Tech** Anthropic Tool Use API, Python, asyncio
>
> **AI** Claude Sonnet

## 源起

整個系統最有價值的部分是讓 AI 在設計階段「真的看過程式碼」再做設計，而不是憑需求描述空想。這篇拆解 Tool Use API 的實作細節。

## 設計

給 Claude 定義四個工具：

- `get_project_structure` — 取得目錄樹（可控深度）
- `list_files` — 列出指定目錄的檔案（支援 glob pattern）
- `search_code` — 在專案裡搜正則 pattern
- `read_file` — 讀取特定檔案內容

所有工具的操作範圍限制在傳入的 `project_root`（即 Git Worktree 路徑），AI 碰不到 Worktree 以外的東西。

對話上限設 30 輪。Claude 每輪可以選擇呼叫工具或結束探索。實務上大部分任務 10-20 輪就夠了。

## 實現

**典型的探索過程：** 以「優化 Unity 主選單載入速度」為例，AI 的實際行為是：

1. 先看整體目錄結構
2. 搜尋 "MainMenu" 找到相關檔案
3. 讀 MainMenuController.cs，發現用 `Resources.Load()` 同步載入
4. 列 Resources 目錄看有哪些 prefab
5. 搜尋 "Addressables" 確認專案沒用過
6. 讀 manifest.json 確認套件依賴

最後產出的設計文件能精確到「MainMenuController.cs 第 45 行的 Start() 要從 Resources.Load 改成 Addressables.LoadAssetAsync」，不是泛泛而談。

**多輪對話的實作。** 用 messages list 累積對話歷史。每輪 response 如果 `stop_reason == "tool_use"` 就執行工具、把結果塞回 messages 繼續；`stop_reason == "end_turn"` 就提取最終文本。

**工具執行的安全邊界。** read_file 會把使用者給的 file_path 和 project_root 拼接，不允許 `..` 跳出。search_code 用 subprocess 跑 grep，工作目錄鎖在 project_root。

**踩到的坑：API 速率限制。** SystemDesigner 一個任務會打 10-20 次 API，偶爾會撞到 429。目前的處理是 catch exception 然後降級，沒做自動重試。實務上不常發生，但如果要上 production 應該加指數退避。

## 尾聲

| 項目 | 數據 |
|------|------|
| 平均工具呼叫 | 10-20 次 / 任務 |
| 設計階段耗時 | 2-5 分鐘 |
| 設計文件長度 | ~4800 字 |
| 對話上限 | 30 輪 |

Tool Use 讓 AI 從「猜測式生成」變成「理解式設計」。生出來的設計文件能指向具體檔案和行號，對後續開發階段的幫助大很多。


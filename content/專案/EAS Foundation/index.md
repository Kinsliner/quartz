---
title: EAS Foundation - Unity 遊戲框架全面重寫之旅
tags: [Unity, C#, 框架重寫, 編輯器工具, 架構設計, EAS Foundation]
created: 2026-02-15
status: 已完成
---

# EAS Foundation

## 專案簡介

EAS Foundation 是一套 Unity 遊戲開發基礎框架，提供 Runtime 核心系統、Editor 工具、資源管理、UI 元件與擴充方法等全面性基礎設施。本次記錄的是將整個框架從舊版本以「重新撰寫」方式移植到新專案的完整歷程——不是複製貼上，而是在保留所有公開 API 相容性的前提下，逐一用不同的方式重新實作每一個模組。

## 主要功能

- **Runtime 核心系統**：ObserverList 零 GC 迭代安全列表、UpdateHandler 系列、CursorLocker 優先權系統、SceneLoader API
- **Editor 工具集**：EditorKit 統一 UI 元件庫、AssetHub 資源管理系統、DirectoryTreeDrawer 樹狀檢視器、SerializeDic 可序列化字典
- **BuildTool 包檔工具**：多平台批次建置、五頁式 EditorWindow、Pipeline 擴充機制、BuildSession 會話管理
- **Extension 擴充方法**：CheckExtension、ColliderExtension、CollectionExtension、MathExtension、ReflectionExtension、TransformExtension、ValueExtension 七個精簡模組
- **AssetHub 資源系統**：Provider/Registrar 可插拔模式、AI 友善資源清單(ASSET_MANIFEST.md)、引用計數管理

## 技術棧

- **語言/框架**：C#、Unity Editor IMGUI、Unity UI EventSystem
- **設計模式**：Provider 模式、Observer 模式、策略模式、開放封閉原則
- **AI 協作工具**：Claude Code

## 重寫規模

| 統計項目 | 數字 |
|---------|------|
| 完成檔案總數 | 169 個 .cs 檔 |
| 移除冗餘檔案 | 22+ 個 |
| 涵蓋模組數 | 15+ 個模組 |
| 開發週期 | 2026-02-15 ~ 2026-02-16 |

## 開發日誌

1. [[DevLog/EAS-Foundation/Phase-1|#1 框架重寫啟動]] - 建立重寫規則與開發慣例，完成 74 個腳本
2. [[DevLog/EAS-Foundation/Phase-2|#2 Runtime 核心與效能]] - ObserverList 零 GC、CursorLocker 優先權系統、SceneLoader 簡化
3. [[DevLog/EAS-Foundation/Phase-3|#3 AssetHub 架構翻新]] - Provider/Registrar 模式取代繼承體系，AI 友善資源清單
4. [[DevLog/EAS-Foundation/Phase-4|#4 Editor 工具、UI 元件、Extension]] - DirectoryTreeDrawer、SerializeDic、UI 元件重寫、Extension 9→7 精簡
5. [[DevLog/EAS-Foundation/Phase-5|#5 BuildTool 收官]] - 9 檔 2,600 行→11 檔模組化架構，169 個檔案全部完成

## 架構亮點

### ObserverList — 零 GC 迭代安全列表

用快取快照 + isDirty 機制解決「迭代中修改集合」的問題，同時透過 struct Enumerator 實現完全零 GC 的 foreach 遍歷。遊戲執行期 UpdateHandler 從「每幀產生垃圾」變成「完全零配置」。

### Provider/Registrar 模式

AssetHub 放棄多層繼承的 AssetLink 體系，改採扁平化的 Provider/Registrar 可插拔模式。AssetHubEntry 變成純資料，Provider 負責 Runtime 載入邏輯，Registrar 負責 Editor 註冊邏輯，透過 TypeResolver 自動探索所有擴充實作，完全符合開放封閉原則。

### BuildSession 會話機制

多 preset 批次建置時，BuildSession 提供 SessionId、CurrentIndex、IsFirst、IsLast 等上下文資訊，讓 Pipeline 能精準控制「只在第一個 preset 前初始化」或「只在最後一個 preset 後清理」的邏輯。

---

返回 [[專案/index|所有專案]]

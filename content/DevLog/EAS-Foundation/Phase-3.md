---
title: "#03 AssetHub 架構翻新"
tags: [Unity, C#, Architecture, Provider Pattern, Editor Tools]
created: 2026-02-16
phase: 3
---

# #03 AssetHub 架構翻新

> **Tech** C#, Unity Editor IMGUI, TypeResolver, ReorderableTable
> **AI** Claude Code

## 源起

AssetHub 是整個框架的資源載入中樞——音效、圖片、Prefab 全部跟它要。舊版用多層繼承的 AssetLink 體系（ResourceLink、AssetBundleLink、AddressableLink...），擴充困難、多型序列化麻煩、Editor 和 Runtime 邏輯糾纏不清。

這個模組不適合「輕度差異化」，需要架構級的重設計。重寫規則從「核心邏輯不變」調整為「公開 API 相容，內部架構可以大改」。

## 設計

把繼承樹拆成三個獨立職責：

**AssetHubEntry** 變成純資料類別，只存 providerTypeName、label、description、assetType、assetPath 等中繼資料，不含載入邏輯。

**AssetProvider** 是 Runtime 端的抽象基底，負責 Load / Release / IsLoaded。內建 ResourceProvider 和 CacheProvider 兩個實作。

**AssetRegistrar** 是 Editor 端的對應物，負責 Register 和 GetAssetType。

自動探索機制是關鍵：`TypeResolver.FindDerivedTypes<AssetProvider>()` 在初始化時掃描所有 Provider 實作，不需要手動註冊。想新增 AddressableProvider？寫一個類別繼承 AssetProvider，核心程式碼完全不用改。開放封閉原則的實踐。

架構設計討論了幾個方案才定案：繼續用繼承但簡化層級（根本問題沒解決）、用介面取代抽象類別（沒有共用程式碼）、完全拋棄繼承改用組合（太複雜降低可讀性）。最後選 Provider 模式——保留繼承的共用程式碼優勢，又有介面的擴充彈性，自動探索讓擴充無痛。反射只在初始化時用，效能影響可接受。

另外設計了 `FormerProviderNameAttribute`，Provider 重新命名時舊 setting 檔案還能找到對應的 Provider，不破壞相容性。

## 實現

**AssetHubEditor 是目前最複雜的 UI。** 基於 `ReorderableTable<EditEntry>` 建構，6 個 Column 類別各管各的事：IDColumn（唯讀 ID）、LabelColumn（可編輯文字+搜尋過濾）、DescriptionColumn（可編輯文字+搜尋過濾）、ProviderColumn（動態下拉選單）、ObjectColumn（拖放資源+搜尋過濾）、InfoColumn（路徑顯示+警告圖示）。每個 Column 專注繪製自己的欄位，Table 只管排版和捲動，改某欄行為直接找對應 Column 就好。

**拖放雙重觸發。** ObjectField 處理完拖放事件後不標記為已消費，事件繼續往上傳被 IDragDropReceiver 再處理一次——拖一個物件結果出現兩筆。在 ObjectColumn 裡加 `Event.current.Use()` 解決。Unity 事件傳播機制有時候很隱晦。

**命名衝突。** 程式碼產生器要生一個常數類別供強型別存取資源：`AssetHub.Load<AudioClip>(???.explosion)`。AssetKeys 會跟 AssetCollector 撞名、AssetHubKeys 太長、Hub 太籠統。最後選 `Assets`——`AssetHub.Load<AudioClip>(Assets.explosion)` 簡潔清楚不衝突。命名真的比寫邏輯還難。

**InfoColumn 的 NullRef。** 建構子裡忘記指派 iconContent 欄位，DrawColumn 一用就炸。debug 了 10 分鐘才發現是漏了一行。教訓：寫完建構子立刻檢查所有欄位是否都指派了。

**AI 友善設計。** 在 AssetHubEntry 加入 description、assetType、assetPath 欄位，建立 AssetHubManifestGenerator 掃描所有 Entry 產出 Markdown 清單放在 `UserSettings/ASSET_MANIFEST.md`。AI 協作時直接查表找資源，不用每次手動提供路徑。這個功能的思路是：與其每次手動告訴 AI，不如建一個機器可讀的清單讓它自己查。

## 尾聲

| 項目 | 結果 |
|------|------|
| 提交檔案 | 16 個（5 Editor + 11 Runtime） |
| 累計完成 | 115 個 |
| 已刪除 | 16 個（MapID、Localization 等棄用模組） |
| 進度 | ~62% |

單次提交檔案數最多的一次。好的架構不是一開始就想出來的，是在推敲、比較、試錯中逐漸成形的。Provider 模式解決了繼承體系的所有痛點，還保留了擴充的靈活性。

---

返回 [[專案/EAS Foundation/index|EAS Foundation 專案首頁]]

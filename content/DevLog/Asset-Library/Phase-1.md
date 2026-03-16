---
title: "#01 Scanner"
tags: [Unity, C#, EditorWindow, Batch Mode, AssetLibrary]
created: 2026-02-28
phase: 1
---

# #01 Scanner

> **Tech** Unity C#, Editor Scripting, Batch Mode, Newtonsoft.Json, SHA256
> **AI** Claude Code

## 源起

專案需要一套 Unity 素材庫管理系統，讓遊戲自動建立流程可以從中取用素材。整個系統分三段：Scanner 掃 Unity 專案裡的素材產出 manifest，Python Importer 從 manifest 下載素材，中間用 JSON 溝通。Scanner 是起點，沒它其他東西都動不了。

## 設計

Scanner 的工作是遍歷指定資料夾、識別 Prefab 和獨立資源、指派穩定 ID、產出 `manifest_raw.json`，同時附上縮圖。幾個關鍵決策：

**兩階段掃描。** 縮圖需要 GPU（`AssetPreview`），但元資料掃描不需要。分開成 Phase 1（`-nographics`）和 Phase 2 讓 Batch Mode 跑得更乾淨，也讓 CI 有機會只跑 Phase 1。

**ID 系統。** `categoryCode × 100000 + 流水號`，與 AssetHub 共用同一套。ID 跟 GUID 的對應關係存在 `id_registry.json`，重新掃描時優先沿用舊 ID，不會因為掃描順序改變而跳號。

**Hash Cache。** 掃描時計算每個檔案的 SHA256 作為 `content_hash`，同時把 GUID → Hash 的結果快取在記憶體。同一個 Prefab 的依賴檔案可能被多個條目共用，快取避免重複讀檔。

**排除規則。** 一開始設計了 `HiddenFolders` 黑名單，後來發現跟 `ignorePatterns` 功能重疊，直接合併成一組 glob 規則，設定介面也因此簡化。

**遵循 EAS Foundation 模式。** 所有 JSON I/O 透過 `FileHandler + IFilePath + IFileParser` 封裝，不在業務邏輯裡直接讀寫檔案。

整體模組結構：

```
Assets/Editor/AssetLibrary/
├── AssetLibraryScanner.cs       ← Scan / GenerateThumbnails 兩個靜態入口
├── ScannerConfigEditor.cs       ← EditorWindow
├── CatalogueFileHandler.cs      ← _Catalogue/ JSON I/O
├── Core/
│   ├── ScannerConfig.cs         ← CategoryEntry + ScannerConfig
│   ├── IdRegistry.cs            ← GUID → ID 映射
│   ├── IgnorePatternMatcher.cs  ← 排除規則
│   ├── DependencyResolver.cs    ← 依賴解析
│   ├── BoundsCalculator.cs      ← Prefab bounds
│   ├── TagGenerator.cs          ← 自動 tag 生成
│   ├── HashCalculator.cs        ← content_hash (SHA256)
│   └── ThumbnailGenerator.cs    ← 縮圖生成
└── Data/
    └── ManifestEntry.cs         ← Manifest 資料模型
```

## 實現

**首次掃描讓 Unity 凍結。** 第一版沒有進度條也沒有快取，跑到一半 Editor 就沒有回應。加了 `EditorUtility.DisplayProgressBar` 和 Hash Cache 之後，掃描期間 UI 雖然卡頓但不會死當，Batch Mode 更是完全沒問題。

**縮圖的 Texture not readable 錯誤。** `AssetPreview.GetMiniThumbnail` 吐回來的 `Texture2D` 預設不可讀，直接 `EncodeToPNG` 會炸。解法是先把原始 texture blit 到 `RenderTexture`，再用 `Texture2D.ReadPixels` 讀回來，之後就能正常編碼輸出。這個 `ToReadableTexture()` 步驟是縮圖流程的關鍵：

```csharp
var rt = RenderTexture.GetTemporary(tex.width, tex.height);
Graphics.Blit(tex, rt);
var readable = new Texture2D(tex.width, tex.height);
readable.ReadPixels(new Rect(0, 0, rt.width, rt.height), 0, 0);
readable.Apply();
RenderTexture.ReleaseTemporary(rt);
```

**UI 架構從單頁改成兩頁。** 早期把分類設定和掃描設定塞在同一個 EditorWindow，欄位一多就很擠。參考 BuildTool 的側邊欄風格改成左側分頁切換，「素材分類」和「掃描設定」各自一頁，左下角放動作按鈕。素材分類使用 EAS Foundation 的 `ReorderableTable<T>`，四欄：Code、Label、AssetTypes、EntryType。

**TagGenerator 的 PascalCase 問題。** 拆字邏輯把 `SciFiWorlds` 拆成 `sci`、`fi`、`worlds` 三個 token，`fi` 單獨成詞沒有意義。這是已知問題，等 LLM 分析模組上來之後，自動 tag 的角色會大幅降低，目前先留著。

**Batch Mode 驗證。** 最後用 Batch Mode 跑了完整的兩階段驗證：

Phase 1 命令：

```
Unity.exe -batchmode -nographics -projectPath <path> -executeMethod AssetLibraryScanner.Scan -quit
```

Phase 2 命令：

```
Unity.exe -batchmode -projectPath <path> -executeMethod AssetLibraryScanner.GenerateThumbnails -quit
```

## 尾聲

| 指標                | 數值      |
| ----------------- | ------- |
| Phase 1 掃描時間      | 18.9 秒  |
| Phase 2 縮圖時間      | 277 秒   |
| Prefab 條目         | 2,623   |
| Resource 條目       | 49      |
| 總條目               | 2,672   |
| 縮圖成功率             | 100%    |
| ID registry       | 3,664 筆 |
| manifest_raw.json | 2.9 MB  |

Scanner 作為整個系統的第一段，現在可以穩定在 Batch Mode 跑完兩階段。下一步是 Web Server 和 Python Importer 的 Server 端。

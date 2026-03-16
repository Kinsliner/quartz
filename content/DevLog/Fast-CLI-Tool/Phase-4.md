---
title: "#4 功能收尾與 GitHub 發佈"
tags: [WPF, dotnet publish, GitHub CLI, Release, Git]
created: 2026-02-19
phase: 4
---

# #4 功能收尾與 GitHub 發佈

> **Tech** WPF, .NET 9, dotnet publish, GitHub CLI
> **AI** Claude Code

## 源起

Phase 3 把多指令管理做完後，工具本身的核心功能算是齊了。這次要做的事比較雜：補一個刪除路徑的確認機制（之前點下去就直接刪，太危險），然後把整個專案打包、整理好對外發佈到 GitHub。

## 設計

確認機制的部分沒什麼好選的，WPF 內建的 `MessageBox.Show` 就夠用了。顯示確認對話框，使用者按「是」才執行刪除，按「否」就取消，邏輯很直接。

發佈流程的規劃：
- `dotnet publish` 產出 self-contained 的單一 exe，使用者不需要預裝 .NET Runtime
- README 用繁體中文寫，說明安裝和基本使用方式
- 補上 MIT LICENSE
- 整理好後推到 GitHub，用 `gh release create` 建立 v1.0.0

## 實現

**刪除確認對話框。** 在 ViewModel 的 `RemovePath` 方法裡加上 `MessageBox.Show`，`MessageBoxButton.YesNo` 搭配 `MessageBoxImage.Question`。邏輯判斷回傳值是否為 `MessageBoxResult.Yes` 才繼續刪除。這是最小的改動，不需要額外的 UI 元件。

**dotnet publish 打包。** 指令：

```bash
dotnet publish -c Release -r win-x64 --self-contained -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o bin/publish-single
```

self-contained 會把 .NET Runtime 一起打進去，讓 exe 在沒裝 .NET 的環境也能跑。`PublishSingleFile=true` 讓輸出壓縮成一個檔案，減少部署的複雜度。產出的 exe 體積較大是因為帶著 runtime，這是 trade-off。

**git branch 改名。** 本地 `master` 改成 `main`：

```bash
git branch -m master main
```

因為還沒推到 GitHub，只需要改本地就好，沒有額外的 upstream 設定問題。

**GitHub CLI 安裝與發佈。** 機器上沒有裝 `gh`，用 `winget install GitHub.cli` 安裝後登入。建好 repo 後，把 exe 打包成 zip，然後用 `gh release create v1.0.0` 建立 release 並附上 zip 作為附件。這樣使用者可以直接從 Releases 頁面下載，不用自己 clone 再 build。

## 尾聲

v1.0.0 正式發佈在 [eason-devkit/fast-cli-tool](https://github.com/eason-devkit/fast-cli-tool)。從 Phase 1 的設定系統到這次的打包發佈，Fast CLI Tool 算是完整走完了從開發到上線的流程。

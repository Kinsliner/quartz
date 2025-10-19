# Quartz v4 專案概要

## 專案基本資訊

- **專案名稱**: Quartz v4
- **版本**: 4.5.1
- **作者**: jackyzha0
- **用途**: 靜態網站生成器，將 Markdown 筆記轉換成數位花園網站
- **官方文件**: https://quartz.jzhao.xyz/
- **技術棧**: TypeScript, Preact, esbuild, remark/rehype

## 主要特點

### 核心功能

- **Markdown 支援**: 完整的 Markdown 語法支援，包含 GFM (GitHub Flavored Markdown)
- **數學公式**: 支援 KaTeX 和 MathJax 渲染數學公式
- **程式碼高亮**: 使用 Shiki 進行語法高亮
- **全文搜尋**: 基於 FlexSearch 的快速全文搜尋功能
- **圖形視覺化**: 使用 D3.js 繪製筆記關聯圖
- **熱重載**: 開發模式下支援即時預覽

### 可擴展性

- 插件系統支援自訂 transformers、filters 和 emitters
- 可自訂主題和樣式
- 支援多種內容格式 (Markdown, YAML, TOML)

### 其他特色

- **引用功能**: rehype-citation 支援學術引用
- **自動連結**: 自動為標題添加錨點連結
- **圖片處理**: Sharp 進行圖片優化
- **雙向連結**: 支援 Wiki-style 連結和反向連結

## 工作目錄結構

### Content 資料夾 (`content/`)

這是主要的內容工作目錄，所有 Markdown 筆記都放在這裡：

```
content/
├── index.md          # 網站首頁
└── 日誌/              # 日誌目錄
    └── hello-world.md
```

### 其他重要目錄

- `quartz/`: Quartz 核心程式碼
- `quartz.config.ts`: 網站配置文件
- `quartz.layout.ts`: 版面配置設定
- `public/`: 靜態資源 (圖片、CSS、JS 等)
- `docs/`: 專案文件

## 常用指令

- `npx quartz build`: 建置網站
- `npx quartz build --serve`: 建置並啟動本地伺服器
- `npm run docs`: 建置並提供文件服務
- `npm run check`: TypeScript 類型檢查和代碼格式檢查
- `npm run format`: 自動格式化代碼

## 開發注意事項

- Node.js 版本需求: >=22
- npm 版本需求: >=10.9.2
- 所有內容文件都應放在 `content/` 目錄下
- 支援中文路徑和檔名（如 `日誌/` 目錄）

## 內容架構規範

### 專案文章架構

每個專案的 `index.md` 應遵循以下架構：

```markdown
---
# Frontmatter（文章元資料）
title: [專案名稱 - 專案標語]
tags: [標籤陣列]
created: [建立日期 YYYY-MM-DD]
status: [專案狀態：進行中/已完成/暫停]
github: [GitHub 連結]
demo: [Demo 連結]
---

# [專案名稱]

## 專案簡介
[專案的核心功能和用途描述]

## 主要功能
- 功能 1：...
- 功能 2：...
- 功能 3：...

## 技術棧
- 語言/框架：[使用的技術]
- AI 協作工具：[使用的 AI 工具]

## 開發日誌
開發過程的詳細記錄：

1. [[日誌連結|#1 日誌標題]] - 簡短描述
2. [[日誌連結|#2 日誌標題]] - 簡短描述

## 相關連結
- GitHub: [連結]
- Demo: [連結]

---

返回 [[專案/index|所有專案]]
```

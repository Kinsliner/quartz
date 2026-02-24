---
title: "#06 Web 介面"
tags: [Streamlit, Python, Web UI]
created: 2025-10-13
phase: 6
---

# #06 Web 介面

> **Tech** Streamlit, Python
> **AI** Claude Code

## 源起

CLI 版本功能完整但公司有 10 位同事要用，不是每個人都會操作命令列。需要一個 Web 介面，內網部署，資料不外洩。

## 設計

選 Streamlit：純 Python、1 天能做完、內建聊天元件和檔案上傳、10 人使用綽綽有餘。比起 Flask+Vue（2 週）或 Django+React（3 週），開發成本差一個量級。

功能只做三個頁面：AI 對話（首頁）、上傳文件、文件管理。資料存 JSON 不用資料庫——文件量不到 100 個，JSON 夠用而且好除錯。

## 實現

**三次迭代才定型。** 第一版功能太多、頁面太多，使用者說太複雜。第二版矯枉過正只留一頁，又太簡單。第三版三個頁面加左側導航，剛好。

**別跟框架對著幹。** 試過用 CSS 覆蓋 Streamlit 的 chat_input 定位，怎麼改都被框架蓋回去。最後放棄客製化讓 Streamlit 自己處理，反而一切正常。

**UTF-8 又來了。** CLI 版的 `sys.stdout` UTF-8 wrapper 在 Streamlit 裡會衝突（stdout 已被關閉）。解法是直接移除——Streamlit 自己就能正確處理編碼。

上傳檔案加時間戳避免重名。文件列表用 `st.columns` 模擬表格，狀態用顏色標示（綠=已完成、黃=處理中、藍=已上傳）。刪除按鈕每個文件獨立 key。

內網部署一行指令：`streamlit run app.py --server.address=0.0.0.0`。

## 尾聲

| 項目 | 結果 |
|------|------|
| 開發時間 | 1 天（3 次迭代，共 7 小時） |
| 程式碼 | 302 行（app.py） |
| CSS | ~50 行 |
| 適用人數 | ~10 人 |

UI 層完成，RAG 後端整合還在進行中。對小團隊內部工具來說，Streamlit 是開發效率最高的選擇。

---

返回 [[專案/RAG智能文檔檢索系統/index|專案首頁]]

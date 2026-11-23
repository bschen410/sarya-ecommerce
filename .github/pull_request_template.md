<!-- PR 標題會成為 squash 後的 commit 訊息，請使用 Conventional Commits，例如：feat(oms): 建立訂單與預扣庫存 -->

## 摘要

<!-- 這個 PR 做了什麼、為什麼 -->

## 對應需求

<!-- SRS 需求編號與商業規則，例如 OMS-F-001、BR-004 -->

-

## 測試

<!-- 如何驗證：執行的測試、手動測試步驟與結果 -->

-

## 檢查清單

- [ ] PR 標題符合 Conventional Commits
- [ ] 有 schema 變更時，已新增 migration（未修改已提交的 migration）
- [ ] 有 schema 變更時，migration + `seed.sql` 能在全新資料庫上執行成功
- [ ] SQL 皆為參數化查詢
- [ ] 已新增或更新相關測試
- [ ] 文件（README / AGENTS.md）已同步更新

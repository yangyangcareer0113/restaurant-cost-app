-- ============================================================
-- 修復：items_masked 遮蔽版 view 漏了 serving_qty 欄位
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
--
-- 背景：migration_serving_cost.sql（7/16）幫 items 資料表新增了
-- serving_qty（每份用量）欄位，但沒有同步更新 migration_confidential_items.sql
-- （7/13）建立的 items_masked view。結果門店帳號（非 admin）用到的頁面
-- （套餐管理 setmeals.html、進貨成本參考 ingredients.html、成品菜單 dishes.html）
-- 只要查詢 items_masked 時 select 到 serving_qty，整條查詢就會失敗、
-- 回傳空清單 —— 這正是「原物料選單打字找不到品項」「選到品項成本不會自動帶入」
-- 「進貨成本參考卡在載入中」這幾個問題的根本原因。
--
-- serving_qty 只是用量數字，不是機密成本金額，直接原樣暴露即可，
-- 不需要像 unit_cost 一樣用 CASE 遮蔽。
--
-- 注意：serving_qty 加在 SELECT 清單最後面（不是插在中間）——
-- PostgreSQL 的 CREATE OR REPLACE VIEW 只能在既有欄位「後面」加新欄位，
-- 插在中間會被當成「把某個既有欄位改名」而報錯（42P16）。
-- ============================================================

CREATE OR REPLACE VIEW items_masked
WITH (security_invoker = true) AS
SELECT
  id, store_id, name, unit, category, supplier, spec_note,
  min_stock_qty, abc_class, bom_unit, bom_conversion, is_active,
  is_confidential, created_at,
  CASE WHEN is_confidential AND NOT is_admin() THEN NULL ELSE unit_cost END AS unit_cost,
  serving_qty
FROM items;

GRANT SELECT ON items_masked TO authenticated;

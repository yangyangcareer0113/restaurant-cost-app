-- ============================================================
-- 品項「銷售定位」：主銷 / 副銷 / 利潤類 → 對應定價倍率 ×3 / ×4 / ×5
-- 請在 Supabase Dashboard → SQL Editor 執行
--
-- 依九和集團 威利執行長 建議的定價法：
--   主銷（主推、常出）        建議售價 = 成本 × 3
--   副銷（炸類、副餐、費工的）  建議售價 = 成本 × 4
--   利潤類（甜點、飲料）        建議售價 = 成本 × 5
--
-- pricing_role 留空 = 系統依類別／品名關鍵字自動判斷（預設主銷）。
-- 這是定位標籤、不是機密，門店帳號也看得到，直接原樣暴露。
-- ============================================================

ALTER TABLE items ADD COLUMN IF NOT EXISTS pricing_role text;   -- '主銷' | '副銷' | '利潤類' | null(自動)

-- items_masked 遮蔽版 view 同步補上 pricing_role（欄位一律加最後面，避免 42P16）
CREATE OR REPLACE VIEW items_masked
WITH (security_invoker = true) AS
SELECT
  id, store_id, name, unit, category, supplier, spec_note,
  min_stock_qty, abc_class, bom_unit, bom_conversion, is_active,
  is_confidential, created_at,
  CASE WHEN is_confidential AND NOT is_admin() THEN NULL::numeric ELSE unit_cost END AS unit_cost,
  serving_qty,
  is_income,
  count_unit,
  serving_price,
  pricing_role
FROM items;

GRANT SELECT ON items_masked TO authenticated;

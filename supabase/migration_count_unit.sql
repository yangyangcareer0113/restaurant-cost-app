-- ============================================================
-- 新增「盤點單位」欄位（2026-09-03）
-- 請在 Supabase Dashboard → SQL Editor 執行
--
-- 有些品項進貨與盤點用不同單位（例：可樂進貨用「箱」、盤點用「罐」）。
-- items 新增 count_unit；留空 = 盤點時沿用進貨單位（unit）。
-- 只有「月底盤點」頁會用 count_unit，其他頁面維持用 unit。
-- ============================================================

ALTER TABLE items ADD COLUMN IF NOT EXISTS count_unit text;

-- items_masked 遮蔽版 view 同步補上 count_unit（欄位一律加在最後面，
-- 否則 CREATE OR REPLACE VIEW 會當成改欄名而報 42P16）
CREATE OR REPLACE VIEW items_masked
WITH (security_invoker = true) AS
SELECT
  id, store_id, name, unit, category, supplier, spec_note,
  min_stock_qty, abc_class, bom_unit, bom_conversion, is_active,
  is_confidential, created_at,
  CASE WHEN is_confidential AND NOT is_admin() THEN NULL ELSE unit_cost END AS unit_cost,
  serving_qty,
  count_unit
FROM items;

GRANT SELECT ON items_masked TO authenticated;

-- 可口可樂：進貨用「箱」、盤點用「罐」
UPDATE items SET unit = '箱', count_unit = '罐' WHERE name LIKE '%可樂%';

-- 驗證
SELECT name, unit AS 進貨單位, count_unit AS 盤點單位 FROM items WHERE name LIKE '%可樂%';

-- ============================================================
-- 原物料「每份售價」：讓品項管理可直接 key 單品加點的對客售價，
-- 建議總覽用「每份成本 vs 每份售價」算成本佔比、比對火鍋業建議區間。
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案。
--
-- 背景：烽味多數菜單是「單品加點」＝一個進貨品項用一份的量對外賣
-- （例：巴沙魚片 每包五片、每份 100g、售 $XX）。這類不會另外開菜品 BOM，
-- 所以直接在 items 存 serving_price（每份售價），總覽就能算成本率。
--
-- serving_price 不是成本、不是機密，門店帳號也看得到，直接原樣暴露。
-- ============================================================

ALTER TABLE items ADD COLUMN IF NOT EXISTS serving_price numeric;

-- items_masked 遮蔽版 view（門店帳號用）同步補上 serving_price。
-- 欄位一律加在 SELECT 清單「最後面」，插在中間會被 CREATE OR REPLACE VIEW
-- 當成把既有欄位改名而報 42P16（serving_qty、is_income 都踩過這個坑）。
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
  serving_price
FROM items;

GRANT SELECT ON items_masked TO authenticated;

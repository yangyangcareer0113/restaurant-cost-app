-- ============================================================
-- Migration：品項新增「收入項目」標記
-- 背景：像「廢油回收」這種進帳（把用過的油賣給回收商），
--       之前只能用一般品項記錄，會被誤算成一筆進貨成本（正數，
--       疊加進總成本），但實際上它是收入，應該是負數去抵扣總成本。
--       新增 is_income 欄位後，這類品項存進 inventory_records 的
--       purchase_cost 會自動存成負數，所有既有的成本加總邏輯
--       （儀表板／報表／每日進貨總金額）都是單純加總 purchase_cost，
--       不用逐一改，負數自然會把總成本往下扣。
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================

ALTER TABLE items ADD COLUMN IF NOT EXISTS is_income boolean NOT NULL DEFAULT false;

-- items_masked view（門店帳號用）也要能看到 is_income，
-- 否則門店記進貨時前端判斷不到這個品項該存成負數。
-- 注意：CREATE OR REPLACE VIEW 只能在既有欄位「最後面」加新欄位，
-- 插在中間會被當成改名既有欄位而報錯（42P16，之前 serving_qty 就踩過這個坑），
-- 所以 is_income 加在目前 SELECT 清單的最後（serving_qty 之後）。
CREATE OR REPLACE VIEW items_masked
WITH (security_invoker = true) AS
SELECT
  id, store_id, name, unit, category, supplier, spec_note,
  min_stock_qty, abc_class, bom_unit, bom_conversion, is_active,
  is_confidential, created_at,
  CASE WHEN is_confidential AND NOT is_admin() THEN NULL ELSE unit_cost END AS unit_cost,
  serving_qty, is_income
FROM items;

GRANT SELECT ON items_masked TO authenticated;

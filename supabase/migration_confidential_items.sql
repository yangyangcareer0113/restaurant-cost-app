-- ============================================================
-- Phase 3 Migration：機密原物料成本隔離（大陸進貨 15 品項）
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
--
-- 背景：大陸進貨的 15 項原物料成本不能讓門店員工看到，
-- 但其他品項的日常進貨成本、以及套餐/菜品的「總成本」員工要能正常看到與試算。
-- 做法：items 加 is_confidential 旗標；建立遮蔽 view（機密品項的成本對非
-- admin 回傳 null）；建立 SECURITY DEFINER RPC 用真實數字算總成本，只回傳總數。
--
-- 需求 Postgres 15+（security_invoker view）。若執行時對
-- `WITH (security_invoker = true)` 報錯，代表專案 PG 版本較舊，請回報我改用
-- SECURITY DEFINER function 的替代寫法。
-- ============================================================

-- 1. items 新增機密旗標
ALTER TABLE items ADD COLUMN IF NOT EXISTS is_confidential boolean DEFAULT false;

-- 2. 標記 15 項大陸進貨原物料（依名稱比對，之後新增門店若同名品項也會一併標記）
UPDATE items SET is_confidential = true WHERE name IN (
  '響鈴卷','保鮮膜','潮汕沙茶醬','豆醬','紅棗','海底椰','五指毛桃',
  '黃耆','黨參','麥冬','人參','蜜棗','玉竹','山藥','茯苓'
);

-- 3. 遮蔽版 items view：機密品項的 unit_cost，非 admin 一律回傳 null
--    其餘欄位（含 is_confidential 本身）不遮蔽，門店仍看得到品名/類別/廠商/單位等。
CREATE OR REPLACE VIEW items_masked
WITH (security_invoker = true) AS
SELECT
  id, store_id, name, unit, category, supplier, spec_note,
  min_stock_qty, abc_class, bom_unit, bom_conversion, is_active,
  is_confidential, created_at,
  CASE WHEN is_confidential AND NOT is_admin() THEN NULL ELSE unit_cost END AS unit_cost
FROM items;

GRANT SELECT ON items_masked TO authenticated;

-- 4. 遮蔽版 inventory_records view：機密品項的當筆進貨成本，非 admin 回傳 null
--    （數量 purchase_qty 不遮蔽，只遮成本金額）
CREATE OR REPLACE VIEW inventory_records_masked
WITH (security_invoker = true) AS
SELECT
  ir.id, ir.item_id, ir.store_id, ir.record_date, ir.purchase_qty,
  CASE WHEN i.is_confidential AND NOT is_admin() THEN NULL ELSE ir.purchase_cost END AS purchase_cost,
  ir.waste_qty, ir.current_stock, ir.notes, ir.created_by, ir.created_at,
  i.name AS item_name, i.unit AS item_unit, i.category AS item_category, i.supplier AS item_supplier,
  i.is_confidential
FROM inventory_records ir
JOIN items i ON i.id = ir.item_id;

GRANT SELECT ON inventory_records_masked TO authenticated;

-- 5. 遮蔽版 set_meal_items view：機密品項的套餐內成本估算，非 admin 回傳 null
CREATE OR REPLACE VIEW set_meal_items_masked
WITH (security_invoker = true) AS
SELECT
  smi.id, smi.set_meal_id, smi.item_id, smi.item_name,
  CASE WHEN i.is_confidential AND NOT is_admin() THEN NULL ELSE smi.cost_est END AS cost_est,
  smi.choice_group, smi.notes, smi.sort_order, smi.created_at,
  COALESCE(i.is_confidential, false) AS is_confidential,
  smi.dish_id, smi.qty
FROM set_meal_items smi
LEFT JOIN items i ON i.id = smi.item_id;

GRANT SELECT ON set_meal_items_masked TO authenticated;

-- 6. RPC：半成品真實總成本（給 dish_total_cost 內部呼叫用，只回傳總數）
CREATE OR REPLACE FUNCTION semi_total_cost(p_semi_id uuid)
RETURNS numeric LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT COALESCE(SUM(
    (i.unit_cost / NULLIF(i.bom_conversion, 0)) * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
  ), 0)
  FROM bom_lines bl
  JOIN items i ON i.id = bl.child_id
  WHERE bl.parent_type = 'semi' AND bl.parent_id = p_semi_id AND bl.child_type = 'item';
$$;

-- 7. RPC：單一菜品真實總成本
CREATE OR REPLACE FUNCTION dish_total_cost(p_dish_id uuid)
RETURNS numeric LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT COALESCE(SUM(
    CASE bl.child_type
      WHEN 'item' THEN (i.unit_cost / NULLIF(i.bom_conversion, 0)) * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
      WHEN 'semi' THEN (semi_total_cost(bl.child_id) / NULLIF(sp.output_qty, 0)) * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
      ELSE 0
    END
  ), 0)
  FROM bom_lines bl
  LEFT JOIN items i ON bl.child_type = 'item' AND i.id = bl.child_id
  LEFT JOIN semi_products sp ON bl.child_type = 'semi' AND sp.id = bl.child_id
  WHERE bl.parent_type = 'dish' AND bl.parent_id = p_dish_id;
$$;

-- 8. RPC：整間門店所有菜品的真實總成本（bom.html 一次撈完，避免逐筆呼叫）
CREATE OR REPLACE FUNCTION dishes_total_cost(p_store_id uuid)
RETURNS TABLE(dish_id uuid, total_cost numeric)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT d.id,
    COALESCE(SUM(
      CASE bl.child_type
        WHEN 'item' THEN (i.unit_cost / NULLIF(i.bom_conversion, 0)) * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
        WHEN 'semi' THEN (semi_total_cost(bl.child_id) / NULLIF(sp.output_qty, 0)) * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
        ELSE 0
      END
    ), 0) AS total_cost
  FROM dishes d
  LEFT JOIN bom_lines bl ON bl.parent_type = 'dish' AND bl.parent_id = d.id
  LEFT JOIN items i ON bl.child_type = 'item' AND i.id = bl.child_id
  LEFT JOIN semi_products sp ON bl.child_type = 'semi' AND sp.id = bl.child_id
  WHERE d.store_id = p_store_id
  GROUP BY d.id;
$$;

-- 9. RPC：單一套餐真實總成本
CREATE OR REPLACE FUNCTION set_meal_total_cost(p_set_meal_id uuid)
RETURNS numeric LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT COALESCE(SUM(cost_est), 0) FROM set_meal_items WHERE set_meal_id = p_set_meal_id;
$$;

-- 10. RPC：整間門店所有套餐的真實總成本
CREATE OR REPLACE FUNCTION set_meals_total_cost(p_store_id uuid)
RETURNS TABLE(set_meal_id uuid, total_cost numeric)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT sm.id, COALESCE(SUM(smi.cost_est), 0) AS total_cost
  FROM set_meals sm
  LEFT JOIN set_meal_items smi ON smi.set_meal_id = sm.id
  WHERE sm.store_id = p_store_id
  GROUP BY sm.id;
$$;

GRANT EXECUTE ON FUNCTION semi_total_cost(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION dish_total_cost(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION dishes_total_cost(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION set_meal_total_cost(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION set_meals_total_cost(uuid) TO authenticated;

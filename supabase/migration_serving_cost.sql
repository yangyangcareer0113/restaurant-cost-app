-- ============================================================
-- Phase 4 Migration：原物料「每份成本」作為系統成本計算基準
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
--
-- 背景：進貨單位（如 Kg）跟出餐用量（如每份 140g）不同，店家希望在
-- 品項管理直接設定「每份用量」，系統就用「每份成本」去算配方/菜品/套餐
-- 成本，而不是每個配方各自輸入原始公克數。
--
-- 做法：items 新增 serving_qty（每份用量，單位＝bom_unit）。
-- 有設定 serving_qty 的品項，bom_lines.std_qty 改為代表「幾份」；
-- 沒有設定的品項維持舊制（std_qty＝原始 bom_unit 數量，例如公克數），
-- 兩者相容，舊資料不用搬遷。
-- ============================================================

ALTER TABLE items ADD COLUMN IF NOT EXISTS serving_qty numeric;

-- 半成品真實總成本
CREATE OR REPLACE FUNCTION semi_total_cost(p_semi_id uuid)
RETURNS numeric LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT COALESCE(SUM(
    CASE WHEN i.serving_qty > 0
      THEN (i.unit_cost / NULLIF(i.bom_conversion, 0)) * i.serving_qty * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
      ELSE (i.unit_cost / NULLIF(i.bom_conversion, 0)) * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
    END
  ), 0)
  FROM bom_lines bl
  JOIN items i ON i.id = bl.child_id
  WHERE bl.parent_type = 'semi' AND bl.parent_id = p_semi_id AND bl.child_type = 'item';
$$;

-- 單一菜品真實總成本
CREATE OR REPLACE FUNCTION dish_total_cost(p_dish_id uuid)
RETURNS numeric LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT COALESCE(SUM(
    CASE bl.child_type
      WHEN 'item' THEN (
        CASE WHEN i.serving_qty > 0
          THEN (i.unit_cost / NULLIF(i.bom_conversion, 0)) * i.serving_qty * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
          ELSE (i.unit_cost / NULLIF(i.bom_conversion, 0)) * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
        END
      )
      WHEN 'semi' THEN (semi_total_cost(bl.child_id) / NULLIF(sp.output_qty, 0)) * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
      ELSE 0
    END
  ), 0)
  FROM bom_lines bl
  LEFT JOIN items i ON bl.child_type = 'item' AND i.id = bl.child_id
  LEFT JOIN semi_products sp ON bl.child_type = 'semi' AND sp.id = bl.child_id
  WHERE bl.parent_type = 'dish' AND bl.parent_id = p_dish_id;
$$;

-- 整間門店所有菜品的真實總成本
CREATE OR REPLACE FUNCTION dishes_total_cost(p_store_id uuid)
RETURNS TABLE(dish_id uuid, total_cost numeric)
LANGUAGE sql SECURITY DEFINER SET search_path = public STABLE AS $$
  SELECT d.id,
    COALESCE(SUM(
      CASE bl.child_type
        WHEN 'item' THEN (
          CASE WHEN i.serving_qty > 0
            THEN (i.unit_cost / NULLIF(i.bom_conversion, 0)) * i.serving_qty * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
            ELSE (i.unit_cost / NULLIF(i.bom_conversion, 0)) * bl.std_qty * (1 + COALESCE(bl.waste_rate, 0) / 100)
          END
        )
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

GRANT EXECUTE ON FUNCTION semi_total_cost(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION dish_total_cost(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION dishes_total_cost(uuid) TO authenticated;

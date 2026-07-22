-- ============================================================
-- 套餐品項成本自動同步
-- 背景：set_meal_items.cost_est 是新增品項時算好存住的快照，
-- 之後如果去改了該原物料的標準單位成本/BOM換算/每份用量，
-- 已經存在套餐裡的品項成本不會自動跟著更新，導致套餐成本失真
-- （2026-07-21 發現：清甜椰子鍋煲（大份）的溫體全雞卡在舊數字 $0.15）。
-- 做法：items 的 unit_cost / bom_conversion / serving_qty 一有變動，
-- 觸發器自動重算所有引用該原物料的 set_meal_items.cost_est，
-- 不需要手動逐筆重新打開品項存一次。
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案。
-- ============================================================

CREATE OR REPLACE FUNCTION sync_set_meal_items_cost_on_item_change()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  UPDATE set_meal_items smi
  SET cost_est = round(
    CASE WHEN NEW.serving_qty > 0
      THEN (NEW.unit_cost / NULLIF(NEW.bom_conversion, 0)) * NEW.serving_qty * COALESCE(smi.qty, 1)
      ELSE (NEW.unit_cost / NULLIF(NEW.bom_conversion, 0)) * COALESCE(smi.qty, 1)
    END, 2)
  WHERE smi.item_id = NEW.id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_set_meal_items_cost ON items;
CREATE TRIGGER trg_sync_set_meal_items_cost
AFTER UPDATE OF unit_cost, bom_conversion, serving_qty ON items
FOR EACH ROW
WHEN (
  NEW.unit_cost IS DISTINCT FROM OLD.unit_cost OR
  NEW.bom_conversion IS DISTINCT FROM OLD.bom_conversion OR
  NEW.serving_qty IS DISTINCT FROM OLD.serving_qty
)
EXECUTE FUNCTION sync_set_meal_items_cost_on_item_change();

-- 注：成品菜品（dishes）、半成品（semi_products）的 BOM 成本本來就是即時
-- 用目前的原物料單位成本算出來（dish_total_cost / semi_total_cost RPC），
-- 不是存快照，所以不需要另外建觸發器，改了原物料成本會自動反映。
-- 只有 set_meal_items.cost_est 這一格是快照，才需要這個觸發器補上。

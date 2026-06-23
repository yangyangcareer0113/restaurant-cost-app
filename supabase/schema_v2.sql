-- ============================================================
-- Phase 2 Migration：成本 BOM + 套餐管理
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================

-- 1. items 表新增成本欄位
ALTER TABLE items ADD COLUMN IF NOT EXISTS cost_low    numeric(10,2) DEFAULT 0;
ALTER TABLE items ADD COLUMN IF NOT EXISTS cost_high   numeric(10,2) DEFAULT 0;
ALTER TABLE items ADD COLUMN IF NOT EXISTS spec_note   text;
ALTER TABLE items ADD COLUMN IF NOT EXISTS cost_rating text
  CHECK (cost_rating IN ('star','good','warn','danger','crit','unk')) DEFAULT 'unk';

-- 2. 套餐主表
CREATE TABLE IF NOT EXISTS set_meals (
  id          uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  store_id    uuid REFERENCES stores(id) ON DELETE CASCADE,
  name        text NOT NULL,
  price       numeric(10,2) DEFAULT 0,
  description text,
  is_active   boolean DEFAULT true,
  created_at  timestamptz DEFAULT now()
);

-- 3. 套餐 BOM 明細（每一行 = 套餐內一個品項）
CREATE TABLE IF NOT EXISTS set_meal_items (
  id           uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  set_meal_id  uuid REFERENCES set_meals(id) ON DELETE CASCADE,
  item_id      uuid REFERENCES items(id) ON DELETE SET NULL,
  item_name    text NOT NULL,
  cost_est     numeric(10,2) DEFAULT 0,
  choice_group text,          -- e.g. "鍋底選一"、"炸物選一"
  notes        text,
  sort_order   int DEFAULT 0,
  created_at   timestamptz DEFAULT now()
);

-- 4. RLS
ALTER TABLE set_meals      ENABLE ROW LEVEL SECURITY;
ALTER TABLE set_meal_items ENABLE ROW LEVEL SECURITY;

CREATE POLICY "set_meals_admin"   ON set_meals FOR ALL USING (is_admin());
CREATE POLICY "set_meals_manager" ON set_meals FOR ALL USING (store_id = get_user_store_id());

CREATE POLICY "smi_all" ON set_meal_items FOR ALL USING (
  EXISTS (
    SELECT 1 FROM set_meals sm
    WHERE sm.id = set_meal_id
      AND (is_admin() OR sm.store_id = get_user_store_id())
  )
);

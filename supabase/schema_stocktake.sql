-- ============================================================
-- 月底盤點功能 — 資料表建立
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================

-- 1. 盤點單（每月每門店一張）
CREATE TABLE IF NOT EXISTS stocktakes (
  id            uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  store_id      uuid REFERENCES stores(id) ON DELETE CASCADE,
  period        text NOT NULL,   -- 格式 YYYY-MM，例如 2026-06
  status        text CHECK (status IN ('draft', 'submitted', 'reviewed')) DEFAULT 'draft',
  notes         text,
  created_by    uuid REFERENCES auth.users(id),
  created_at    timestamptz DEFAULT now(),
  submitted_at  timestamptz,
  reviewed_by   uuid REFERENCES auth.users(id),
  reviewed_at   timestamptz,
  UNIQUE(store_id, period)
);

-- 2. 盤點明細（每張盤點單下的品項行）
CREATE TABLE IF NOT EXISTS stocktake_items (
  id            uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  stocktake_id  uuid REFERENCES stocktakes(id) ON DELETE CASCADE,
  item_id       uuid REFERENCES items(id) ON DELETE CASCADE,
  counted_qty   numeric(10,2),       -- 實際盤點數量
  unit_cost     numeric(10,2),       -- 當下快照成本（取 items.cost_low）
  notes         text,
  updated_at    timestamptz DEFAULT now(),
  UNIQUE(stocktake_id, item_id)
);

-- 3. RLS
ALTER TABLE stocktakes      ENABLE ROW LEVEL SECURITY;
ALTER TABLE stocktake_items ENABLE ROW LEVEL SECURITY;

-- stocktakes：admin 全部操作；store_manager 只能管自己門店
CREATE POLICY "stocktakes_admin"   ON stocktakes FOR ALL USING (is_admin());
CREATE POLICY "stocktakes_manager_select" ON stocktakes FOR SELECT
  USING (store_id = get_user_store_id());
CREATE POLICY "stocktakes_manager_insert" ON stocktakes FOR INSERT
  WITH CHECK (store_id = get_user_store_id());
CREATE POLICY "stocktakes_manager_update" ON stocktakes FOR UPDATE
  USING (store_id = get_user_store_id() AND status = 'draft');

-- stocktake_items：admin 全部操作；store_manager 只能在 draft 狀態下操作自己門店
CREATE POLICY "stocktake_items_admin" ON stocktake_items FOR ALL USING (is_admin());

CREATE POLICY "stocktake_items_manager_select" ON stocktake_items FOR SELECT
  USING (EXISTS (
    SELECT 1 FROM stocktakes st
    WHERE st.id = stocktake_id AND st.store_id = get_user_store_id()
  ));

CREATE POLICY "stocktake_items_manager_insert" ON stocktake_items FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM stocktakes st
    WHERE st.id = stocktake_id AND st.store_id = get_user_store_id() AND st.status = 'draft'
  ));

CREATE POLICY "stocktake_items_manager_update" ON stocktake_items FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM stocktakes st
    WHERE st.id = stocktake_id AND st.store_id = get_user_store_id() AND st.status = 'draft'
  ));

CREATE POLICY "stocktake_items_manager_delete" ON stocktake_items FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM stocktakes st
    WHERE st.id = stocktake_id AND st.store_id = get_user_store_id() AND st.status = 'draft'
  ));

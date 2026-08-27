-- ============================================================
-- 每日提領記錄
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================
--
-- 記錄門店每天從庫存「提領」出去使用的量，以及提領後的剩餘庫存。
-- 剩餘庫存由前端自動算：該品項目前庫存 − 本次提領數量（會接著上一筆提領往下扣），
-- 這張表不會回寫 inventory_records，不影響儀表板／報表的消耗量計算。

CREATE TABLE IF NOT EXISTS withdrawal_records (
  id              uuid DEFAULT uuid_generate_v4() PRIMARY KEY,
  item_id         uuid REFERENCES items(id) ON DELETE CASCADE,
  store_id        uuid REFERENCES stores(id) ON DELETE CASCADE,
  record_date     date NOT NULL DEFAULT current_date,
  withdraw_qty    numeric(10,2) NOT NULL DEFAULT 0,
  remaining_stock numeric(10,2),
  notes           text,
  created_by      uuid REFERENCES auth.users(id),
  created_at      timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_withdrawal_item_date
  ON withdrawal_records (item_id, record_date DESC, created_at DESC);

-- RLS：比照 inventory_records，admin 管全部、門店管自己店
ALTER TABLE withdrawal_records ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "withdrawal_admin" ON withdrawal_records;
CREATE POLICY "withdrawal_admin" ON withdrawal_records
  FOR ALL USING (is_admin());

DROP POLICY IF EXISTS "withdrawal_manager" ON withdrawal_records;
CREATE POLICY "withdrawal_manager" ON withdrawal_records
  FOR ALL USING (store_id = get_user_store_id());

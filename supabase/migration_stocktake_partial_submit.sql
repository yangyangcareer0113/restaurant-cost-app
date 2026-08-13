-- ============================================================
-- 盤點改為可多次分段提交
-- 請在 Supabase Dashboard → SQL Editor 執行此檔案
-- ============================================================
--
-- 原本的 RLS 政策寫死「只有 draft 狀態」門店才能寫入盤點資料，
-- 導致員工按下「提交盤點」（status 變 submitted）之後，
-- 就算前端解鎖了輸入框，資料庫還是會擋掉後續的補填/修改。
-- 這裡把門店可寫入的狀態從 status = 'draft' 放寬成 status IN ('draft','submitted')，
-- 只有老闆按下「確認審核」（status = 'reviewed'）之後才真正鎖死。

DROP POLICY IF EXISTS "stocktakes_manager_update" ON stocktakes;
CREATE POLICY "stocktakes_manager_update" ON stocktakes FOR UPDATE
  USING (store_id = get_user_store_id() AND status IN ('draft', 'submitted'));

DROP POLICY IF EXISTS "stocktake_items_manager_insert" ON stocktake_items;
CREATE POLICY "stocktake_items_manager_insert" ON stocktake_items FOR INSERT
  WITH CHECK (EXISTS (
    SELECT 1 FROM stocktakes st
    WHERE st.id = stocktake_id AND st.store_id = get_user_store_id() AND st.status IN ('draft', 'submitted')
  ));

DROP POLICY IF EXISTS "stocktake_items_manager_update" ON stocktake_items;
CREATE POLICY "stocktake_items_manager_update" ON stocktake_items FOR UPDATE
  USING (EXISTS (
    SELECT 1 FROM stocktakes st
    WHERE st.id = stocktake_id AND st.store_id = get_user_store_id() AND st.status IN ('draft', 'submitted')
  ));

DROP POLICY IF EXISTS "stocktake_items_manager_delete" ON stocktake_items;
CREATE POLICY "stocktake_items_manager_delete" ON stocktake_items FOR DELETE
  USING (EXISTS (
    SELECT 1 FROM stocktakes st
    WHERE st.id = stocktake_id AND st.store_id = get_user_store_id() AND st.status IN ('draft', 'submitted')
  ));

// ============================================================
// Supabase 設定 — 建立後請填入你的 Project URL 和 anon key
// 取得位置：Supabase Dashboard → Project Settings → API
// ============================================================

const SUPABASE_URL = 'https://rzdsyzquqdyuxzgytbcz.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_GBgDcZkAkaQzBEB1jVwNnQ_SSMoZZ24';

// 覆寫 CDN 暴露的 library 物件為 client 實例（避免 const 重複宣告衝突）
window.supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// ============================================================
// 共用工具函數
// ============================================================

// 計算毛利率（%）
function calcGrossMargin(sellingPrice, costPerUnit) {
  if (!sellingPrice || sellingPrice <= 0) return null;
  return ((sellingPrice - costPerUnit) / sellingPrice * 100).toFixed(1);
}

// 計算成本佔比（%）
function calcCostRatio(sellingPrice, costPerUnit) {
  if (!sellingPrice || sellingPrice <= 0) return null;
  return (costPerUnit / sellingPrice * 100).toFixed(1);
}

// 計算單位成本
function calcCostPerUnit(purchaseCost, purchaseQty) {
  if (!purchaseQty || purchaseQty <= 0) return 0;
  return (purchaseCost / purchaseQty).toFixed(2);
}

// ============================================================
// BOM 成本共用計算（每份成本為基準）
// 有設定 serving_qty（每份用量）的原物料：std_qty 代表「幾份」，
// 成本＝每份成本 × 份數；沒設定的維持舊制：std_qty＝原始 bom_unit 數量。
// ============================================================

// 每 bom_unit 成本（例：每克多少錢）
function costPerBomUnit(item) {
  if (!item || !(item.bom_conversion > 0)) return 0;
  return (item.unit_cost || 0) / item.bom_conversion;
}

// 每份成本（僅在原物料有設定 serving_qty 時有意義）
function costPerServing(item) {
  if (!item || !(item.serving_qty > 0)) return 0;
  return costPerBomUnit(item) * item.serving_qty;
}

// 一筆 BOM 明細的成本（qty 依 serving_qty 是否設定，代表「份數」或原始 bom_unit 數量）
function calcItemLineCost(item, qty, wasteRate) {
  const q = qty || 0;
  const wasteMult = 1 + (wasteRate || 0) / 100;
  if (item?.serving_qty > 0) return costPerServing(item) * q * wasteMult;
  return costPerBomUnit(item) * q * wasteMult;
}

// ── 銷售定位 → 定價倍率（九和集團 威利執行長建議：主銷×3、副銷×4、利潤類×5）──
const PRICING_MULT = { '主銷': 3, '副銷': 4, '利潤類': 5 };

// 回傳 { role, mult, auto }。o 可帶 pricing_role（手動指定）/ category / name。
function pricingRoleOf(o) {
  if (o && PRICING_MULT[o.pricing_role]) {
    return { role: o.pricing_role, mult: PRICING_MULT[o.pricing_role], auto: false };
  }
  const s = `${(o && o.category) || ''} ${(o && o.name) || ''}`;
  let role = '主銷';
  if (/甜點|布丁|愛玉|仙草|豆花|杏仁豆腐|雪花冰|剉冰|冰淇淋|甜湯|飲料|飲品|茶飲|奶茶|紅茶|綠茶|烏龍茶|青茶|汽水|可樂|沙士|雪碧|果汁|冬瓜茶|梅[汁子]|沙瓦|氣泡/.test(s)) {
    role = '利潤類';
  } else if (/炸|酥|天婦羅|唐揚|鹽酥|副餐|點心|鍋貼|燒賣|春捲|蝦捲|月亮蝦餅|銀絲卷|饅頭|薯條|薯餅|甜不辣|黑輪|白飯|白米|米飯|炒飯|燴飯|滷肉飯|拌麵|炒麵|拉麵|烏龍麵|王子麵|科學麵|冬粉|米粉|年糕|蘿蔔糕|粿/.test(s)) {
    role = '副銷';
  }
  return { role, mult: PRICING_MULT[role], auto: true };
}

// 建議售價 = 成本 × 倍率，未滿 $30 取整數、否則四捨五入到 $5
function suggestPrice(cost, mult) {
  const raw = (cost || 0) * (mult || 0);
  if (raw <= 0) return 0;
  return raw < 30 ? Math.round(raw) : Math.round(raw / 5) * 5;
}

// 格式化數字（加千分位）
function formatNumber(num, decimals = 0) {
  if (num === null || num === undefined) return '—';
  return Number(num).toLocaleString('zh-TW', {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals
  });
}

// 庫存警示等級
function stockAlertLevel(currentStock, minStock) {
  if (currentStock <= 0) return 'danger';
  if (currentStock < minStock * 0.5) return 'danger';
  if (currentStock < minStock) return 'warning';
  return 'ok';
}

// Toast 提示
function showToast(message, type = 'success') {
  const container = document.getElementById('toast-container');
  if (!container) return;
  const id = 'toast-' + Date.now();
  const bgClass = type === 'success' ? 'bg-success' : type === 'danger' ? 'bg-danger' : 'bg-warning';
  container.insertAdjacentHTML('beforeend', `
    <div id="${id}" class="toast align-items-center text-white ${bgClass} border-0" role="alert">
      <div class="d-flex">
        <div class="toast-body">${message}</div>
        <button type="button" class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast"></button>
      </div>
    </div>
  `);
  const el = document.getElementById(id);
  const toast = new bootstrap.Toast(el, { delay: 3000 });
  toast.show();
  el.addEventListener('hidden.bs.toast', () => el.remove());
}

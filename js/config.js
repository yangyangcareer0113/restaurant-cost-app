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

// ── 銷售定位 → 定價倍率（烽味 à la carte 火鍋版）──
// 純鍋底 ×4（每桌必買＋扛免費冰淇淋，利潤引擎）
// 一般加點 ×3.2（脆皮雞肉、豬、非招牌雞、丸餃火鍋料、一般海鮮、罐裝飲料）
// 比價肉品 ×2.2（牛肉、高階海鮮——價格透明、薄利）
// 配料主食 ×5（菜盤、麵飯年糕、醬料——成本低、不透明）
// 利潤飲品 ×7（自製茶飲／氣泡飲——冰淇淋免費後唯一利潤類）
const PRICING_MULT = {
  '純鍋底': 4, '一般加點': 3.2, '比價肉品': 2.2, '配料主食': 5, '利潤飲品': 7,
  // 舊值相容（主銷/副銷/利潤類）
  '主銷': 3.2, '副銷': 5, '利潤類': 7,
};

// 回傳 { role, mult, auto }。o 可帶 pricing_role（手動指定）/ category / name。
function pricingRoleOf(o) {
  if (o && PRICING_MULT[o.pricing_role]) {
    const raw = o.pricing_role;
    const role = { '主銷': '一般加點', '副銷': '配料主食', '利潤類': '利潤飲品' }[raw] || raw;
    return { role, mult: PRICING_MULT[raw], auto: false };
  }
  const s = `${(o && o.category) || ''} ${(o && o.name) || ''}`;
  let role = '一般加點';
  if (/套餐|雙人|四人|多人|饗宴/.test(s)) {
    return { role: '套餐', mult: 0, auto: true };   // 套餐請用「套餐管理」檢視，不套倍率
  }
  if (/鍋底|湯底|湯頭|純鍋|清湯鍋|個人鍋|共鍋/.test(s)) {
    role = '純鍋底';
  } else if (/牛肉|牛五花|牛小排|牛舌|沙朗|霜降|雪花|翼板|板腱|嫩肩|安格斯|和牛|龍蝦|帝王蟹|松葉蟹|生蠔|鮑魚|大干貝/.test(s)) {
    role = '比價肉品';
  } else if (/自製|手作|氣泡|沙瓦|水果茶|果茶|冬瓜茶|梅子綠|檸檬|奶蓋|多多/.test(s)) {
    role = '利潤飲品';
  } else if (/菜盤|蔬菜|高麗菜|白菜|茼蒿|青菜|菇盤|金針菇|鴻喜菇|香菇|杏鮑菇|木耳|豆腐|凍豆腐|油豆腐|王子麵|科學麵|意麵|烏龍麵|冬粉|米粉|白飯|米飯|飯$|年糕|粿|玉米|南瓜|地瓜|冬粉|醬料|沾醬/.test(s)) {
    role = '配料主食';
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

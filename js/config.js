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
// 配料主食 ×4（菜盤、菇、豆腐、王子麵、冬粉、白飯、醬料——成本低、不透明，但市場價有天花板）
// 利潤飲品 ×7（自製茶飲／氣泡飲——冰淇淋免費後唯一利潤類）
const PRICING_MULT = {
  '純鍋底': 4, '一般加點': 3.2, '比價肉品': 2.2, '費工副銷': 4, '配料主食': 4, '利潤飲品': 7,
  '特殊定價': -1,   // 老闆指定維持現價，不套倍率也不亮燈
  // 舊值相容（主銷/副銷/利潤類）
  '主銷': 3.2, '副銷': 4, '利潤類': 7,
};

// 回傳 { role, mult, auto }。o 可帶 pricing_role（手動指定）/ category / name。
function pricingRoleOf(o) {
  if (o && PRICING_MULT[o.pricing_role] !== undefined) {
    const raw = o.pricing_role;
    const role = { '主銷': '一般加點', '副銷': '費工副銷', '利潤類': '利潤飲品' }[raw] || raw;
    return { role, mult: PRICING_MULT[raw], auto: false };
  }
  const s = `${(o && o.category) || ''} ${(o && o.name) || ''}`;
  let role = '一般加點';
  if (/套餐|雙人|四人|多人|饗宴/.test(s)) {
    return { role: '套餐', mult: 0, auto: true };   // 套餐用成本率判斷，不套倍率
  }
  if (/鍋底|湯底|湯頭|純鍋|清湯鍋|個人鍋|共鍋|潤鍋|藥膳鍋|養生鍋|鍋$/.test(s)) {
    role = '純鍋底';
  } else if (/牛肉|牛五花|牛小排|牛舌|沙朗|霜降|雪花|翼板|板腱|嫩肩|安格斯|和牛|龍蝦|帝王蟹|松葉蟹|生蠔|鮑魚|大干貝/.test(s)) {
    role = '比價肉品';
  } else if (/蝦餅|月亮蝦餅|天婦羅|唐揚|鹽酥|酥炸|炸物|香酥|春捲|蝦捲|鍋貼|燒賣/.test(s)) {
    role = '費工副銷';
  } else if (/自製|手作|氣泡|沙瓦|水果茶|果茶|冬瓜茶|梅子綠|檸檬|奶蓋|多多/.test(s)) {
    role = '利潤飲品';
  } else if (/菜盤|蔬菜|時蔬|蔬果|高麗菜|大陸妹|白菜|茼蒿|青菜|地瓜葉|A菜|菇盤|綜合菇|菇菇|金針菇|鴻喜菇|香菇|杏鮑菇|美白菇|木耳|豆腐|凍豆腐|油豆腐|蛋豆腐|日式豆腐|王子麵|科學麵|統一麵|泡麵|冬粉|寬冬粉|米粉|白飯|白米飯|米飯|飯$|玉米|南瓜|地瓜|醬料|沾醬|沙茶醬/.test(s)) {
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

// 定價體檢：給 成本 / 售價 / 定位，回傳「現在該怎麼修正」
// 回傳 { status:'low'|'ok'|'high'|'na', target, rate, sev, advice }
// sev 數字越大越該處理（給排序用）
function pricingCheck(cost, price, roleInfo) {
  if (!(cost > 0) || !(price > 0)) {
    return { status: 'na', sev: -1, advice: '缺成本或售價，先補齊才能評估' };
  }
  // 特殊定價：老闆指定維持現價，不評估
  if (roleInfo && roleInfo.mult < 0) {
    const rate = cost / price * 100;
    return { status: 'ok', rate, sev: -1, advice: `維持現價（老闆指定不套倍率）　成本率 ${rate.toFixed(0)}%` };
  }
  // 套餐（mult=0）：改用成本率判斷（合理帶 28–42%）
  if (!roleInfo || roleInfo.mult === 0) {
    const rate = cost / price * 100;
    if (rate < 28) {
      const cutPrice = Math.round((price - cost / 0.33) / 10) * 10;
      const addCost  = Math.round(cost * (0.33 / (rate / 100) - 1));
      return { status: 'high', rate, sev: 28 - rate,
        advice: `成本率 ${rate.toFixed(0)}%，套餐偏貴（客人拿到的量相對定價偏少）→ 加約 $${addCost} 的食材，或降價約 $${cutPrice}，讓成本率到 30–35%` };
    }
    if (rate > 58) {
      return { status: 'high', rate, sev: 100 + rate,
        advice: `成本率 ${rate.toFixed(0)}%，套餐正在虧錢 → 先到「套餐管理」展開此套餐，看哪一行成本特別大：多半是該品項沒設「每份用量」而用到整包／整條的量（像之前的響鈴捲、豆醬）。份量確認無誤後，再抽掉高成本品項或漲價` };
    }
    if (rate > 42) {
      const upPrice = Math.round((cost / 0.40 - price) / 10) * 10;
      return { status: 'low', rate, sev: rate,
        advice: `成本率 ${rate.toFixed(0)}%，套餐偏虧 → 抽掉高成本品項，或漲價約 $${upPrice}` };
    }
    return { status: 'ok', rate, sev: 0, advice: `成本率 ${rate.toFixed(0)}%，合理` };
  }
  const target = suggestPrice(cost, roleInfo.mult);
  const ratio  = target > 0 ? price / target : 1;
  if (ratio < 0.9) {
    const inc = Math.round(target - price);
    const cutPct = Math.max(0, Math.round((1 - (price / roleInfo.mult) / cost) * 100));
    return { status: 'low', target, sev: (0.9 - ratio) * 100,
      advice: `售價偏低 → 漲到 $${target}（+$${inc}），或維持售價但每份少放約 ${cutPct}% 的料` };
  }
  if (ratio > 1.1) {
    const dec = Math.round(price - target);
    const addPct = Math.max(0, Math.round(((price / roleInfo.mult) / cost - 1) * 100));
    return { status: 'high', target, sev: (ratio - 1.1) * 100,
      advice: `售價偏高 → 降到 $${target}（−$${dec}），或維持售價但每份多給約 ${addPct}% 的料` };
  }
  return { status: 'ok', target, sev: 0, advice: '定價合理' };
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

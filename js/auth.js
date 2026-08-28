// ============================================================
// 認證相關函數
// ============================================================

// 取得目前登入用戶（含 profile）
async function getCurrentUser() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return null;

  const { data: profile } = await supabase
    .from('profiles')
    .select('*, stores(*)')
    .eq('id', session.user.id)
    .single();

  return { user: session.user, profile };
}

// 檢查是否已登入，未登入就跳轉到登入頁
async function requireAuth() {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) {
    window.location.href = 'login.html';
    return null;
  }
  // 閒置逾時檢查（先擋掉逾時的 session，再啟動監聽）
  if (await enforceIdleTimeout()) return null;
  startIdleWatch();
  return session;
}

// 僅 admin 可進入，否則跳回儀表板
async function requireAdmin() {
  const session = await requireAuth();
  if (!session) return null;
  const { data: profile } = await supabase.from('profiles').select('role').eq('id', session.user.id).single();
  if (!profile || profile.role !== 'admin') {
    window.location.href = 'dashboard.html';
    return null;
  }
  return session;
}

// 登出
async function logout() {
  await supabase.auth.signOut();
  window.location.href = 'login.html';
}

// ============================================================
// 閒置自動登出：連續 30 分鐘沒有任何操作就登出，回登入頁
// ============================================================
const IDLE_LIMIT_MS = 30 * 60 * 1000; // 30 分鐘
const IDLE_KEY = 'fw_last_active';

let _idleLastWrite = 0;
function markActive() {
  const now = Date.now();
  if (now - _idleLastWrite < 5000) return; // 節流：最多每 5 秒寫一次 localStorage
  _idleLastWrite = now;
  try { localStorage.setItem(IDLE_KEY, String(now)); } catch (e) {}
}

function idleExceeded() {
  let last = 0;
  try { last = parseInt(localStorage.getItem(IDLE_KEY) || '0', 10); } catch (e) { return false; }
  if (!last) return false;
  return Date.now() - last > IDLE_LIMIT_MS;
}

// 逾時就登出並轉回登入頁；回傳是否已逾時
async function enforceIdleTimeout() {
  if (!idleExceeded()) return false;
  try { localStorage.removeItem(IDLE_KEY); } catch (e) {}
  try { await supabase.auth.signOut(); } catch (e) {}
  window.location.href = 'login.html?expired=1';
  return true;
}

let _idleWatchStarted = false;
function startIdleWatch() {
  if (_idleWatchStarted) return;
  _idleWatchStarted = true;
  markActive();
  ['click', 'keydown', 'mousedown', 'touchstart', 'scroll'].forEach(evt => {
    window.addEventListener(evt, markActive, { passive: true });
  });
  // 每 30 秒主動檢查一次（涵蓋整頁沒動、放著不管的情況）
  setInterval(enforceIdleTimeout, 30 * 1000);
  // 分頁切回前景時立即檢查
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') enforceIdleTimeout();
  });
  // 其他分頁 / 裝置登出時，本頁也跟著回登入頁
  supabase.auth.onAuthStateChange((event) => {
    if (event === 'SIGNED_OUT') window.location.href = 'login.html';
  });
}

// 頁面載入即啟動閒置監聽（登入頁除外；沒有 session 就交給各頁 requireAuth 處理）
async function initIdleGuard() {
  if (location.pathname.split('/').pop() === 'login.html') return;
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) return;
  if (await enforceIdleTimeout()) return;
  startIdleWatch();
}
document.addEventListener('DOMContentLoaded', initIdleGuard);

// 渲染導覽列用戶資訊
async function renderUserInfo() {
  const data = await getCurrentUser();
  if (!data) return;
  const { profile } = data;

  const storeName = profile?.stores?.name || '（未分配門店）';
  const roleBadge = profile?.role === 'admin'
    ? '<span class="badge bg-warning text-dark">總部管理</span>'
    : profile?.role === 'accountant'
    ? '<span class="badge bg-purple" style="background:#7c3aed;">會計</span>'
    : '<span class="badge bg-info">門店</span>';

  const el = document.getElementById('user-info');
  if (el) el.innerHTML = `${roleBadge} ${storeName}`;

  const nameEl = document.getElementById('user-name');
  if (nameEl) nameEl.textContent = profile?.full_name || data.user.email;

  return { profile };
}

// 設定目前頁面的 nav 連結 active 狀態
function setActiveNav() {
  const currentPage = location.pathname.split('/').pop();
  document.querySelectorAll('.sidebar-nav a').forEach(link => {
    if (link.getAttribute('href') === currentPage) {
      link.classList.add('active');
    }
  });
}

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

// 渲染導覽列用戶資訊
async function renderUserInfo() {
  const data = await getCurrentUser();
  if (!data) return;
  const { profile } = data;

  const storeName = profile?.stores?.name || '（未分配門店）';
  const roleBadge = profile?.role === 'admin'
    ? '<span class="badge bg-warning text-dark">總部管理</span>'
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

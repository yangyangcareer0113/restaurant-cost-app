// ============================================================
// 通用導覽列（所有頁面共用）
// ============================================================

function injectNav() {
  const nav = `
    <div class="sidebar-overlay" id="sidebar-overlay" onclick="toggleSidebar()"></div>

    <div class="sidebar" id="sidebar">
      <div class="sidebar-brand">
        <h5>🍜 烽味營運管理</h5>
        <div id="user-info" style="font-size:0.78rem;margin-top:0.25rem;"></div>
      </div>

      <nav class="sidebar-nav">
        <a href="dashboard.html">
          <span class="nav-icon">📊</span> 儀表板
        </a>
        <a href="records.html">
          <span class="nav-icon">✏️</span> 每日記錄
        </a>
        <a href="inventory.html">
          <span class="nav-icon">🏪</span> 庫存總覽
        </a>
        <a href="stocktake.html">
          <span class="nav-icon">📋</span> 月底盤點
        </a>
        <!-- 品項管理 / BOM：store_manager 可見；accountant 不顯示 -->
        <a href="items.html" class="nav-not-accountant">
          <span class="nav-icon">📦</span> 品項管理
        </a>
        <a href="bom.html" class="nav-not-accountant">
          <span class="nav-icon">🧾</span> 成本 BOM
        </a>
        <a href="setmeals.html" class="nav-not-accountant">
          <span class="nav-icon">🎉</span> 套餐管理
        </a>
        <!-- 以下僅 admin 可見 -->
        <a href="semis.html" class="nav-admin-only">
          <span class="nav-icon">🥣</span> 半成品
        </a>
        <a href="dishes.html" class="nav-not-accountant">
          <span class="nav-icon">🍽️</span> 成品菜單
        </a>
        <a href="analysis.html" class="nav-admin-only">
          <span class="nav-icon">🔍</span> 月度分析
        </a>
        <a href="reports.html" class="nav-admin-only">
          <span class="nav-icon">📈</span> 報表導出
        </a>
        <a href="cost_compare.html" class="nav-admin-only">
          <span class="nav-icon">📊</span> 成本結構分析
        </a>
        <a href="price_variance.html" class="nav-admin-only">
          <span class="nav-icon">📉</span> 進價波動分析
        </a>
        <div style="height:1px;background:rgba(255,255,255,0.08);margin:0.4rem 1.25rem;"></div>
        <!-- 薪資區：admin（查看）+ accountant（編輯）可見；store_manager 不顯示 -->
        <a href="staff.html" class="nav-payroll">
          <span class="nav-icon">👥</span> 員工管理
        </a>
        <a href="payroll.html" class="nav-payroll">
          <span class="nav-icon">💰</span> 薪資計算
        </a>
        <a href="import_payroll.html" class="nav-admin-only">
          <span class="nav-icon">📥</span> 歷史薪資匯入
        </a>
        <a href="salary-chart.html" class="nav-admin-only">
          <span class="nav-icon">🥧</span> 薪資結構分析
        </a>
      </nav>

      <div class="sidebar-footer">
        <div id="user-name" style="margin-bottom:0.4rem;"></div>
        <button class="btn btn-sm btn-outline-secondary w-100" onclick="logout()">登出</button>
      </div>
    </div>

    <div id="toast-container"></div>
  `;

  document.body.insertAdjacentHTML('afterbegin', nav);
  setActiveNav();
}

// 依角色過濾 nav（在 renderUserInfo 取得 profile 後呼叫）
function filterNavByRole(role) {
  // nav-admin-only：僅 admin 可見
  document.querySelectorAll('.nav-admin-only').forEach(el => {
    if (role !== 'admin') el.style.display = 'none';
  });

  // nav-payroll：admin + accountant 可見；store_manager 不顯示
  document.querySelectorAll('.nav-payroll').forEach(el => {
    if (role !== 'admin' && role !== 'accountant') el.style.display = 'none';
  });

  // nav-not-accountant：accountant 不顯示（品項管理、成本BOM）
  document.querySelectorAll('.nav-not-accountant').forEach(el => {
    if (role === 'accountant') el.style.display = 'none';
  });
}

function toggleSidebar() {
  const sidebar = document.getElementById('sidebar');
  const overlay = document.getElementById('sidebar-overlay');
  sidebar.classList.toggle('show');
  overlay.classList.toggle('show');
}

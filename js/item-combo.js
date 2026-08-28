// ============================================================
// 可搜尋的品項下拉選單（打字過濾 + 點選；選中的值一律是品項 ID）
// 不依賴任何第三方套件，樣式自帶。
//
// 用法：
//   const combo = createItemCombo({
//     input:  <input type="text">,
//     panel:  <div class="ic-panel">（需放在 class="ic-wrap" 的相對定位容器裡）,
//     hidden: <input type="hidden">（存品項 ID）,
//     caret:  <button>（可選，點了展開全部）,
//     onSelect: (itemId) => {}   // 選到品項或清空時呼叫（清空時 itemId === ''）
//   });
//   combo.setItems([{ id, name, unit, category }, ...]);
//   combo.clear();
//   combo.getItem();  // 目前選定的品項物件（或 null）
// ============================================================

(function injectComboStyle() {
  if (document.getElementById('ic-style')) return;
  const s = document.createElement('style');
  s.id = 'ic-style';
  s.textContent = `
    .ic-wrap { position: relative; }
    .ic-wrap input.form-control { padding-right: 2rem; }
    .ic-caret {
      position: absolute; right: 4px; top: 50%; transform: translateY(-50%);
      border: 0; background: transparent; color: #64748b; font-size: 0.8rem;
      padding: 6px 8px; cursor: pointer; line-height: 1;
    }
    .ic-panel {
      position: absolute; left: 0; right: 0; top: calc(100% + 2px);
      background: #fff; border: 1px solid #cbd5e1; border-radius: 8px;
      box-shadow: 0 8px 24px rgba(0,0,0,0.12);
      max-height: 300px; overflow-y: auto; z-index: 1060; padding: 4px 0;
    }
    .ic-group {
      font-size: 0.72rem; font-weight: 700; color: #64748b;
      padding: 6px 12px 2px; letter-spacing: 0.03em;
      position: sticky; top: 0; background: #fff;
    }
    .ic-opt {
      padding: 8px 12px; font-size: 0.9rem; cursor: pointer;
      display: flex; justify-content: space-between; gap: 8px; align-items: baseline;
    }
    .ic-opt small { color: #94a3b8; flex-shrink: 0; }
    .ic-opt:hover, .ic-opt.ic-active { background: #eff6ff; }
    .ic-empty { padding: 10px 12px; color: #94a3b8; font-size: 0.85rem; }
  `;
  document.head.appendChild(s);
})();

function createItemCombo(opts) {
  const { input, panel, hidden, caret, onSelect } = opts;
  let items = [];
  let selectedId = '';
  let open = false;

  const displayText = (it) => {
    const nm = (it.name || '').trim();
    const u = (it.unit || '').trim();
    return u ? `${nm}（${u}）` : nm;
  };
  const norm = (s) => (s || '').toString().trim().toLowerCase();

  function filtered() {
    const sel = items.find(i => i.id === selectedId);
    const raw = input.value;
    // 已選中、而且輸入框內容就是該品項顯示字串 → 視為沒在搜尋，列出全部
    if (!norm(raw) || (sel && raw === displayText(sel))) return items.slice();
    const tokens = norm(raw).split(/\s+/).filter(Boolean);
    return items.filter(i => {
      const hay = norm(i.name) + ' ' + norm(i.category) + ' ' + norm(i.unit);
      return tokens.every(t => hay.includes(t));
    });
  }

  function render() {
    const list = filtered();
    panel.innerHTML = '';
    if (!list.length) {
      panel.innerHTML = '<div class="ic-empty">找不到符合的品項</div>';
      return;
    }
    const groups = {};
    list.forEach(i => {
      const c = (i.category || '未分類').trim() || '未分類';
      (groups[c] = groups[c] || []).push(i);
    });
    Object.keys(groups).forEach(cat => {
      const gh = document.createElement('div');
      gh.className = 'ic-group';
      gh.textContent = cat;
      panel.appendChild(gh);
      groups[cat].forEach(i => {
        const row = document.createElement('div');
        row.className = 'ic-opt';
        row.dataset.id = i.id;
        const nm = document.createElement('span');
        nm.textContent = (i.name || '').trim();
        const u = document.createElement('small');
        u.textContent = (i.unit || '').trim();
        row.appendChild(nm);
        row.appendChild(u);
        row.addEventListener('mousedown', (e) => e.preventDefault()); // 不要讓 input 失焦
        row.addEventListener('click', () => pick(i));
        panel.appendChild(row);
      });
    });
  }

  function show() {
    if (!open) { render(); panel.classList.remove('d-none'); open = true; }
  }
  function hide() {
    if (open) { panel.classList.add('d-none'); open = false; clearActive(); }
  }
  function clearActive() {
    panel.querySelectorAll('.ic-opt.ic-active').forEach(el => el.classList.remove('ic-active'));
  }
  function activeEl() { return panel.querySelector('.ic-opt.ic-active'); }
  function moveActive(dir) {
    const els = Array.from(panel.querySelectorAll('.ic-opt'));
    if (!els.length) return;
    let idx = els.indexOf(activeEl()) + dir;
    if (idx < 0) idx = els.length - 1;
    if (idx >= els.length) idx = 0;
    clearActive();
    els[idx].classList.add('ic-active');
    els[idx].scrollIntoView({ block: 'nearest' });
  }

  function pick(it) {
    selectedId = it.id;
    hidden.value = it.id;
    input.value = displayText(it);
    hide();
    if (onSelect) onSelect(it.id);
  }
  function clearSelection(fire) {
    if (selectedId === '') return;
    selectedId = '';
    hidden.value = '';
    if (fire && onSelect) onSelect('');
  }

  input.addEventListener('focus', show);
  input.addEventListener('click', show);
  input.addEventListener('input', () => { clearSelection(true); show(); render(); });
  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowDown') { e.preventDefault(); show(); moveActive(1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); show(); moveActive(-1); }
    else if (e.key === 'Enter') {
      const el = activeEl();
      if (el) {
        e.preventDefault();
        const it = items.find(i => i.id === el.dataset.id);
        if (it) pick(it);
      }
    } else if (e.key === 'Escape') { hide(); }
  });
  input.addEventListener('blur', () => {
    setTimeout(() => {
      if (!selectedId) {
        const f = filtered();
        if (f.length === 1) pick(f[0]); // 打完整名字直接跳走時，唯一結果自動選取
      }
      hide();
    }, 120);
  });

  if (caret) {
    caret.addEventListener('mousedown', (e) => {
      e.preventDefault();
      if (open) hide();
      else { input.focus(); show(); }
    });
  }

  document.addEventListener('click', (e) => {
    if (!open) return;
    if (e.target === input || panel.contains(e.target) || (caret && caret.contains(e.target))) return;
    hide();
  });

  return {
    setItems(arr) {
      items = (arr || []).slice();
      if (selectedId && !items.find(i => i.id === selectedId)) clearSelection(false);
      if (open) render();
    },
    clear() { clearSelection(false); input.value = ''; hide(); },
    getItem() { return items.find(i => i.id === selectedId) || null; },
    getId() { return selectedId; }
  };
}

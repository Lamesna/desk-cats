// The tray menu: cat list, care, laser, language, and the cat editor.
(function () {
  'use strict';
  const K = globalThis.K, tr = (s) => K.tr(s);
  const api = window.kotiki;
  const app = document.getElementById('app');

  let state = null, stats = {}, editingId = null;

  const h = (tag, attrs, ...kids) => {
    const el = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs || {})) {
      if (k === 'class') el.className = v;
      else if (k.startsWith('on')) el.addEventListener(k.slice(2), v);
      else if (v !== false && v !== null && v !== undefined) el.setAttribute(k, v === true ? '' : v);
    }
    for (const kid of kids.flat()) if (kid !== null && kid !== undefined && kid !== false) el.append(kid.nodeType ? kid : document.createTextNode(kid));
    return el;
  };
  const send = (type, data) => api.send('action', Object.assign({ type }, data || {}));

  /** A cat picture on a small canvas, drawn by the same renderer as the overlay. */
  function thumb(cfg, size) {
    const dpr = window.devicePixelRatio || 1;
    const cv = document.createElement('canvas');
    cv.width = cv.height = Math.round(size * dpr);
    cv.style.width = cv.style.height = size + 'px';
    const ctx = cv.getContext('2d');
    ctx.scale(dpr, dpr);
    const s = size / 64;
    ctx.translate(size / 2, size - 6 * s);
    ctx.scale(s, -s);
    const ri = { pose: 'sit', facing: 1, phase: 0, t: 0.6, eyes: 'open', look: { x: 0, y: 0 }, mouthOpen: false, climbSide: -1, rotation: 0, shake: 0, blush: false, swing: 0, progress: 0 };
    K.draw(new K.G(ctx), K.makeLook(cfg), ri);
    return cv;
  }

  const sw = (on, onclick) => h('div', { class: 'switch' + (on ? ' on' : ''), onclick });

  function bar(icon, v, color) {
    return h('div', { class: 'bar' }, icon, h('i', {}, h('b', { style: `width:${Math.max(3, v * 100)}%;background:${v < 0.3 ? '#e04b4b' : color}` })));
  }

  // ---------- main view ----------
  function catRow(c) {
    const st = stats[c.id] || { food: 0.8, water: 0.8, energy: 0.8, fun: 0.7, mood: 'Roaming' };
    return h('div', { class: 'cat' + (c.visible ? '' : ' hidden') },
      thumb(c, 44),
      h('div', { class: 'grow' },
        h('div', { class: 'row', style: 'gap:6px' }, h('span', { class: 'name' }, c.name), h('span', { class: 'muted' }, c.visible ? tr(st.mood) : tr('Hidden'))),
        c.visible ? h('div', { class: 'bars' }, bar('🍗', st.food, '#f0a030'), bar('💧', st.water, '#4a90e2'), bar('⚡', st.energy, '#e8c020'), bar('❤️', st.fun, '#ee5fa0')) : null),
      h('button', { class: 'icon', title: c.visible ? tr('Hide') : tr('Show'), onclick: () => send('updateCat', { cat: Object.assign({}, c, { visible: !c.visible }) }) }, c.visible ? '👁' : '🚫'),
      h('button', { class: 'icon', title: tr('Customize'), onclick: () => { editingId = c.id; render(); } }, '✎'));
  }

  function careButton(label, icon, onclick) { return h('button', { onclick }, icon + '  ' + tr(label)); }

  function mainView() {
    const on = state.running;
    const kids = [
      h('div', { class: 'row' }, h('h1', {}, 'Kotiki'), h('div', { class: 'grow' }), sw(on, () => send('running', { value: !on }))),
      h('div', { class: 'muted', style: 'margin:4px 0 10px' }, on ? tr('Cats are roaming your screen') : tr('All cats are hidden. Switch on to bring them back.')),
    ];
    if (on) {
      kids.push(
        ...state.cats.map(catRow),
        h('button', { class: 'primary', style: 'margin-top:4px', onclick: () => {
          const cat = K.randomCat(state.cats, K.catNames[K.lang]);
          send('addCat', { cat }); editingId = cat.id;
        } }, '＋  ' + tr('Add a cat')),
        h('hr'),
        h('div', { class: 'row' }, h('span', { class: 'grow' }, '🔴  ' + tr('Laser pointer instead of cursor')), sw(state.laser, () => send('laser', { value: !state.laser }))),
        h('h2', {}, tr('Care')),
        h('div', { class: 'grid2' },
          careButton('Food bowl', '🍽', () => send('placing', { kind: 'food' })),
          careButton('Water bowl', '💧', () => send('placing', { kind: 'water' })),
          careButton('Refill food', '↻', () => send('bowlAction', { name: 'refillFood' })),
          careButton('Refill water', '↻', () => send('bowlAction', { name: 'refillWater' })),
          careButton('Feed everyone', '♥', () => send('bowlAction', { name: 'feedAll' })),
          careButton('Remove bowls', '🗑', () => send('bowlAction', { name: 'clear' }))),
        state.placing ? h('div', { class: 'warn' }, tr('Click anywhere on the screen to place the bowl. Right-click to cancel.')) : null,
        h('div', { class: 'small', style: 'margin-top:10px' },
          h('div', {}, tr('• Hold the cursor over a cat and it purrs')),
          h('div', {}, tr('• Ctrl + drag: pick up a cat or a bowl')),
          h('div', {}, tr('• Close a window and the cat on it tumbles down'))));
    }
    kids.push(
      h('hr'),
      h('div', { class: 'row' }, '🌐',
        h('select', { onchange: (e) => send('lang', { value: e.target.value }) },
          K.langs.map((l) => h('option', Object.assign({ value: l.id }, l.id === state.lang ? { selected: true } : {}), l.title))),
        h('div', { class: 'grow' })),
      h('button', { class: 'danger', style: 'margin-top:10px;width:100%', onclick: () => send('quit') }, '⏻  ' + tr('Quit (remove all cats)')));
    return kids;
  }

  // ---------- editor ----------
  function tile(cfg, name, selected, onclick) {
    return h('div', { class: 'tile' + (selected ? ' sel' : ''), onclick }, thumb(cfg, 54), h('span', {}, tr(name)));
  }

  function editorView(cat) {
    const update = (patch) => send('updateCat', { cat: Object.assign({}, cat, patch) });
    const hatOf = (id) => Object.assign({}, cat, { hat: id }), outOf = (id) => Object.assign({}, cat, { outfit: id });
    const eyeSwatches = K.eyeColors.map((e) => {
      const [a, b] = K.eyeRGB(e);
      return h('span', { class: 'eye' + (cat.eyes === e ? ' sel' : ''), title: tr(K.eyeName[e]), onclick: () => update({ eyes: e }) },
        h('i', { style: `background:${K.css(a)}` }), h('i', { style: `background:${K.css(b)}` }));
    });
    return [
      h('div', { class: 'row' }, h('button', { onclick: () => { editingId = null; render(); } }, '‹  ' + tr('Back'))),
      h('div', { class: 'row', style: 'gap:14px;margin:10px 0' },
        thumb(cat, 90),
        h('div', { class: 'grow' },
          h('input', { type: 'text', value: cat.name, placeholder: tr('Name'), oninput: (e) => update({ name: e.target.value }) }),
          h('div', { class: 'muted', style: 'margin:4px 0' }, tr(K.preset(cat.coat).name)),
          h('div', { class: 'row' }, h('span', { class: 'muted' }, tr('Size')),
            h('input', { type: 'range', min: 0.7, max: 2, step: 0.05, value: cat.size, oninput: (e) => update({ size: parseFloat(e.target.value) }) })))),
      h('h2', {}, tr('Coat')),
      h('div', { class: 'tiles c4' }, K.coatPresets.map((p) => tile(Object.assign({}, cat, { coat: p.id }), p.name, cat.coat === p.id, () => update({ coat: p.id })))),
      h('h2', {}, tr('Eyes')), h('div', {}, eyeSwatches),
      h('h2', {}, tr('Hat')),
      h('div', { class: 'tiles c3' }, K.hatOptions.map((o) => tile(hatOf(o.id), o.name, (cat.hat || 'none') === o.id, () => update({ hat: o.id })))),
      h('h2', {}, tr('Costume')),
      h('div', { class: 'tiles c3' }, K.outfitOptions.map((o) => tile(outOf(o.id), o.name, (cat.outfit || 'none') === o.id, () => update({ outfit: o.id })))),
      h('div', { class: 'row', style: 'margin-top:14px' },
        h('button', { class: 'danger', onclick: () => { send('deleteCat', { id: cat.id }); editingId = null; } }, '🗑  ' + tr('Delete cat')),
        h('div', { class: 'grow' }),
        h('button', { class: 'primary', style: 'width:auto;padding:8px 18px', onclick: () => { editingId = null; render(); } }, tr('Done'))),
    ];
  }

  let renderPending = false;
  function render() {
    if (!state) return;
    K.lang = state.lang;
    const cat = editingId && state.cats.find((c) => c.id === editingId);
    if (editingId && !cat) editingId = null;
    // keep the scroll position and the focused input while the state refreshes
    const scroll = document.body.scrollTop, active = document.activeElement, keepFocus = active && active.tagName === 'INPUT' && active.type === 'text';
    const pos = keepFocus ? active.selectionStart : 0;
    app.replaceChildren(...(cat ? editorView(cat) : mainView()).flat().filter(Boolean));
    document.body.scrollTop = scroll;
    if (keepFocus) { const i = app.querySelector('input[type=text]'); if (i) { i.focus(); i.setSelectionRange(pos, pos); } }
  }
  const scheduleRender = () => { if (!renderPending) { renderPending = true; requestAnimationFrame(() => { renderPending = false; render(); }); } };

  api.onState((s) => { state = s; scheduleRender(); });
  api.onStats((s) => { stats = s; if (!editingId) scheduleRender(); });
  api.ready();
})();

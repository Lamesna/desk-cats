// Kotiki for Windows: main process. Owns the cat list, the tray icon, the menu window and the
// transparent overlay window the cats live in.
const { app, BrowserWindow, Tray, ipcMain, screen, nativeImage } = require('electron');
const fs = require('fs');
const path = require('path');

globalThis.K = globalThis.K || {};
require('./src/loc.js');
require('./src/model.js');
const K = globalThis.K;
const { listWindows } = require('./winlist.js');

if (!app.requestSingleInstanceLock()) { app.quit(); process.exit(0); }

let overlay = null, menu = null, tray = null;
let overlayReady = false, quitting = false;
let state = null;
let capturing = false;
let lastStats = {};
const SMOKE = process.env.KOTIKI_SMOKE || '';

// ---------- saved settings ----------
const dataFile = () => path.join(app.getPath('userData'), 'kotiki.json');
const logFile = () => path.join(app.getPath('userData'), 'kotiki.log');
const log = (msg) => { try { fs.appendFileSync(logFile(), new Date().toISOString() + ' ' + msg + '\n'); } catch (e) { /* ignore */ } };

function loadState() {
  let saved = {};
  try { saved = JSON.parse(fs.readFileSync(dataFile(), 'utf8')); } catch (e) { /* first launch */ }
  const lang = ['en', 'ru', 'zh'].includes(saved.lang) ? saved.lang : K.detectLang(app.getLocale());
  K.lang = lang;
  let cats = Array.isArray(saved.cats) && saved.cats.length ? saved.cats : null;
  if (!cats) cats = [K.newCat(K.catNames[lang][0], 'grayWhite', 'green', 1.2)];
  state = { cats, running: saved.running !== false, laser: false, placing: null, lang, pixel: saved.pixel === true || process.env.KOTIKI_PIXEL === '1' };
  if (process.env.KOTIKI_DEMO) {                                           // for development: a few dressed cats
    const mk = (n, coat, hat, outfit) => Object.assign(K.newCat(n, coat, K.preset(coat).eyes, 1.3), { hat, outfit });
    state.cats = [mk('A', 'grayWhite', 'none', 'c_dino'), mk('B', 'ginger', 'bunny', 'none'), mk('C', 'calico', 'witch', 'none'), mk('D', 'siamese', 'none', 'c_bee')];
  }
}
function saveState() {
  try {
    fs.mkdirSync(app.getPath('userData'), { recursive: true });
    fs.writeFileSync(dataFile(), JSON.stringify({ cats: state.cats, running: state.running, lang: state.lang, pixel: state.pixel }, null, 1));
  } catch (e) { log('save failed: ' + e.message); }
}

// ---------- display ----------
const primary = () => screen.getPrimaryDisplay();
function displayInfo() {
  const d = primary(), b = d.bounds, wa = d.workArea;
  return { width: b.width, height: b.height, workArea: { x: wa.x - b.x, y: wa.y - b.y, width: wa.width, height: wa.height } };
}
function fullState() { return Object.assign({ display: displayInfo() }, state); }

function broadcast() {
  const s = fullState();
  if (overlay && overlayReady) overlay.webContents.send('state', s);
  if (menu && !menu.isDestroyed()) menu.webContents.send('state', s);
}

// ---------- windows ----------
function createOverlay() {
  const b = primary().bounds;
  overlay = new BrowserWindow({
    x: b.x, y: b.y, width: b.width, height: b.height,
    transparent: true, frame: false, hasShadow: false, resizable: false, movable: false, skipTaskbar: true,
    focusable: false, show: false, alwaysOnTop: true, type: process.platform === 'win32' ? 'toolbar' : undefined,
    webPreferences: { preload: path.join(__dirname, 'preload.js'), backgroundThrottling: false, contextIsolation: true, sandbox: true },
  });
  overlay.setAlwaysOnTop(true, 'screen-saver');
  overlay.setIgnoreMouseEvents(true, { forward: true });
  if (process.platform === 'darwin') overlay.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  overlay.loadFile(path.join(__dirname, 'overlay.html'));
  overlay.on('closed', () => { overlay = null; });
}

function placeOverlay() {
  if (!overlay) return;
  const b = primary().bounds;
  overlay.setBounds({ x: b.x, y: b.y, width: b.width, height: b.height });
}

function createMenu() {
  menu = new BrowserWindow({
    width: 360, height: 640, show: false, frame: false, resizable: false, skipTaskbar: true, alwaysOnTop: true,
    fullscreenable: false, minimizable: false, maximizable: false, backgroundColor: '#00000000',
    webPreferences: { preload: path.join(__dirname, 'preload.js'), contextIsolation: true, sandbox: true },
  });
  menu.setAlwaysOnTop(true, 'pop-up-menu');
  menu.loadFile(path.join(__dirname, 'menu.html'));
  menu.on('blur', () => { if (!SMOKE && menu && !menu.isDestroyed()) menu.hide(); });
  menu.on('close', (e) => { if (!quitting) { e.preventDefault(); menu.hide(); } });
}

function showMenu() {
  if (!menu) return;
  const wa = primary().workArea;
  const w = 360, h = Math.min(640, wa.height - 24);
  let x, y;
  const tb = tray && tray.getBounds();
  if (tb && tb.width > 0) {
    x = Math.round(tb.x + tb.width / 2 - w / 2);
    y = tb.y > wa.y + wa.height / 2 ? tb.y - h - 8 : tb.y + tb.height + 8;      // above a bottom taskbar, below a top one
  } else { x = wa.x + wa.width - w - 12; y = wa.y + wa.height - h - 12; }
  x = Math.min(Math.max(x, wa.x + 6), wa.x + wa.width - w - 6);
  y = Math.min(Math.max(y, wa.y + 6), wa.y + wa.height - h - 6);
  menu.setBounds({ x, y, width: w, height: h });
  menu.webContents.send('state', fullState());
  menu.webContents.send('stats', lastStats);
  menu.show();
  menu.focus();
}

function createTray() {
  const img = nativeImage.createFromPath(path.join(__dirname, 'assets', 'tray.png'));
  tray = new Tray(img.isEmpty() ? nativeImage.createEmpty() : img);
  tray.setToolTip('Kotiki');
  tray.on('click', () => { if (menu && menu.isVisible()) menu.hide(); else showMenu(); });
  tray.on('right-click', () => { if (menu && menu.isVisible()) menu.hide(); else showMenu(); });
}

// ---------- actions from the menu ----------
function applyRunning() {
  if (!overlay) return;
  if (state.running) overlay.showInactive(); else overlay.hide();
  if (!state.running) { state.laser = false; state.placing = null; }
}

function handleAction(a) {
  switch (a.type) {
    case 'running': state.running = !!a.value; applyRunning(); break;
    case 'laser': state.laser = !!a.value; break;
    case 'pixel': state.pixel = !!a.value; break;
    case 'placing': state.placing = a.kind; if (menu) menu.hide(); break;       // get out of the way so you can click
    case 'bowlAction': if (overlay) overlay.webContents.send('bowlAction', a.name); return;
    case 'addCat': state.cats.push(a.cat); break;
    case 'updateCat': state.cats = state.cats.map((c) => (c.id === a.cat.id ? a.cat : c)); break;
    case 'deleteCat': state.cats = state.cats.filter((c) => c.id !== a.id); break;
    case 'lang': if (['en', 'ru', 'zh'].includes(a.value)) { state.lang = a.value; K.lang = a.value; } break;
    case 'quit': quitting = true; app.quit(); return;
    default: return;
  }
  saveState();
  broadcast();
}

ipcMain.on('ready', () => {
  // each page asks for the state when it has loaded
  if (overlay && !overlay.isDestroyed()) overlayReady = true;
  broadcast();
  applyRunning();
});
ipcMain.on('capture', (_e, want) => {
  capturing = !!want;
  if (overlay && !overlay.isDestroyed()) overlay.setIgnoreMouseEvents(!want, { forward: true });
});
ipcMain.on('stats', (_e, s) => { lastStats = s; if (menu && !menu.isDestroyed() && menu.isVisible()) menu.webContents.send('stats', s); });
ipcMain.on('placed', () => { state.placing = null; broadcast(); });
ipcMain.on('action', (_e, a) => handleAction(a));

// ---------- the two polling loops: cursor and windows ----------
function startPolling() {
  setInterval(() => {
    if (!overlay || overlay.isDestroyed() || !overlayReady || !state.running) return;
    const p = screen.getCursorScreenPoint(), b = primary().bounds;
    overlay.webContents.send('cursor', { x: p.x - b.x, y: b.height - (p.y - b.y) });
  }, 16);

  let warned = false;
  setInterval(() => {
    if (!overlay || overlay.isDestroyed() || !overlayReady || !state.running) return;
    try {
      const b = primary().bounds, list = listWindows();
      const out = [];
      for (const w of list) {
        const x = w.x - b.x, top = w.y - b.y;
        if (x + w.width < 0 || x > b.width || top + w.height < 0 || top > b.height) continue;     // on another monitor
        out.push({ id: w.id, x, y: b.height - (top + w.height), w: w.width, h: w.height });         // y is the bottom edge, y-up
      }
      overlay.webContents.send('windows', out);
    } catch (e) {
      if (!warned) { warned = true; log('window list failed: ' + (e.stack || e.message)); }
    }
  }, 100);
}

// ---------- start ----------
app.on('second-instance', () => showMenu());
app.on('window-all-closed', (e) => { if (!quitting) e.preventDefault(); });
app.on('before-quit', () => { quitting = true; });

app.whenReady().then(() => {
  loadState();
  createOverlay();
  createMenu();
  createTray();
  startPolling();
  screen.on('display-metrics-changed', () => { placeOverlay(); broadcast(); });
  screen.on('display-added', () => { placeOverlay(); broadcast(); });
  screen.on('display-removed', () => { placeOverlay(); broadcast(); });
  if (state.running) overlay.once('ready-to-show', () => overlay.showInactive());
  overlay.webContents.once('did-finish-load', () => { if (state.running) overlay.showInactive(); });
  if (SMOKE) runSmokeTest();
});

// A self-test for development: lets the cats play for a few seconds, then saves what the overlay and the menu look like.
async function runSmokeTest() {
  const wait = (ms) => new Promise((r) => setTimeout(r, ms));
  await wait(9000);
  const o = await overlay.webContents.capturePage();
  fs.writeFileSync(SMOKE + '-overlay.png', o.toPNG());
  showMenu();
  await wait(1500);
  const m = await menu.webContents.capturePage();
  fs.writeFileSync(SMOKE + '-menu.png', m.toPNG());
  const err = await overlay.webContents.executeJavaScript('window.__errors || []');
  console.log('smoke test done, page errors:', JSON.stringify(err));
  quitting = true; app.quit();
}

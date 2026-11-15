// Lists the open windows on Windows (front to back) so the cats can walk on top of them.
// Uses the Win32 API through koffi. Everything is wrapped in try/catch: if anything fails the cats simply
// have no windows to climb and still walk on the taskbar.
const { screen } = require('electron');

let api = null, failed = false;

function load() {
  const koffi = require('koffi');
  const user32 = koffi.load('user32.dll');
  const dwmCloak = koffi.load('dwmapi.dll');
  const dwmRect = koffi.load('dwmapi.dll');
  const RECT = koffi.struct('RECT', { left: 'int32', top: 'int32', right: 'int32', bottom: 'int32' });
  const Proc = koffi.proto('bool __stdcall EnumWindowsProc(void *hwnd, intptr_t lParam)');
  return {
    koffi,
    RECT,
    EnumWindows: user32.func('bool __stdcall EnumWindows(EnumWindowsProc *cb, intptr_t lParam)'),
    IsWindowVisible: user32.func('bool __stdcall IsWindowVisible(void *hwnd)'),
    IsIconic: user32.func('bool __stdcall IsIconic(void *hwnd)'),
    GetWindowRect: user32.func('bool __stdcall GetWindowRect(void *hwnd, _Out_ RECT *rect)'),
    GetWindowLongW: user32.func('int32 __stdcall GetWindowLongW(void *hwnd, int index)'),
    GetWindowTextLengthW: user32.func('int __stdcall GetWindowTextLengthW(void *hwnd)'),
    GetWindowThreadProcessId: user32.func('uint32 __stdcall GetWindowThreadProcessId(void *hwnd, _Out_ uint32 *pid)'),
    GetClassNameA: user32.func('int __stdcall GetClassNameA(void *hwnd, _Out_ uint8_t *buf, int max)'),
    DwmCloaked: dwmCloak.func('int32 __stdcall DwmGetWindowAttribute(void *hwnd, uint32 attr, _Out_ int32 *value, uint32 size)'),
    DwmFrame: dwmRect.func('int32 __stdcall DwmGetWindowAttribute(void *hwnd, uint32 attr, _Out_ RECT *value, uint32 size)'),
  };
}

const SKIP_CLASSES = new Set(['Progman', 'WorkerW', 'Shell_TrayWnd', 'Shell_SecondaryTrayWnd', 'Windows.UI.Core.CoreWindow',
  'NotifyIconOverflowWindow', 'TopLevelWindowForOverflowXamlIsland', 'XamlExplorerHostIslandWindow', 'ForegroundStaging']);
const WS_EX_TRANSPARENT = 0x20, WS_EX_TOOLWINDOW = 0x80, WS_EX_LAYERED = 0x80000, WS_EX_NOACTIVATE = 0x08000000;
const GWL_EXSTYLE = -20, DWMWA_CLOAKED = 14, DWMWA_EXTENDED_FRAME_BOUNDS = 9;

/** Windows front to back as {id, x, y, width, height} in screen DIPs (y-down). */
function listWindows() {
  if (process.platform !== 'win32') {
    // for testing on other systems: KOTIKI_FAKE_WINDOWS='[{"id":1,"x":200,"y":300,"width":500,"height":400}]'
    try { return JSON.parse(process.env.KOTIKI_FAKE_WINDOWS || '[]'); } catch (e) { return []; }
  }
  if (failed) return [];
  try {
    if (!api) api = load();
    const a = api, out = [], pidBuf = [0], rect = {}, frame = {}, cloaked = [0];
    a.EnumWindows((hwnd) => {
      try {
        if (!a.IsWindowVisible(hwnd) || a.IsIconic(hwnd)) return true;
        const ex = a.GetWindowLongW(hwnd, GWL_EXSTYLE);
        if ((ex & WS_EX_TOOLWINDOW) || (ex & WS_EX_NOACTIVATE) || ((ex & WS_EX_TRANSPARENT) && (ex & WS_EX_LAYERED))) return true;
        if (a.GetWindowTextLengthW(hwnd) <= 0) return true;
        a.DwmCloaked(hwnd, DWMWA_CLOAKED, cloaked, 4);
        if (cloaked[0] !== 0) return true;
        a.GetWindowThreadProcessId(hwnd, pidBuf);
        if (pidBuf[0] === process.pid) return true;
        const cls = Buffer.alloc(128);
        const n = a.GetClassNameA(hwnd, cls, 128);
        if (SKIP_CLASSES.has(cls.toString('latin1', 0, Math.max(0, n)))) return true;
        let r;
        if (a.DwmFrame(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, frame, 16) === 0) r = frame;
        else if (a.GetWindowRect(hwnd, rect)) r = rect; else return true;
        const phys = { x: r.left, y: r.top, width: r.right - r.left, height: r.bottom - r.top };
        if (phys.width < 100 || phys.height < 50) return true;
        const dip = screen.screenToDipRect(null, phys);                       // physical pixels to DIPs (display scaling)
        out.push({ id: Number(a.koffi.address(hwnd)), x: dip.x, y: dip.y, width: dip.width, height: dip.height });
      } catch (e) { /* one odd window must not stop the list */ }
      return true;
    }, 0);
    return out;
  } catch (e) {
    failed = true;
    throw e;
  }
}

module.exports = { listWindows };

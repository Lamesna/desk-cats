// The overlay window: a transparent full-screen canvas on top of everything. Clicks pass through to your
// apps except while placing a bowl, dragging something, or holding Ctrl over a cat or a bowl.
(function () {
  'use strict';
  const K = globalThis.K;
  const api = window.kotiki;
  const cv = document.getElementById('c');
  const ctx = cv.getContext('2d');

  let world = null, W = 0, H = 0, dpr = 1;
  let cursor = { x: 0, y: 0 };            // world coordinates, from the main process
  let leftDown = false, modifierHeld = false, capturing = false;

  function setup(display) {
    W = display.width; H = display.height;
    dpr = window.devicePixelRatio || 1;
    cv.width = Math.round(W * dpr); cv.height = Math.round(H * dpr);
    cv.style.width = W + 'px'; cv.style.height = H + 'px';
    const wa = display.workArea;                                         // screen coordinates, y-down
    const visible = { minX: wa.x, maxX: wa.x + wa.width, maxY: H - wa.y, minY: H - (wa.y + wa.height) };
    if (!world) {
      world = new K.World({ width: W, height: H, visible });
      world.events.stats = (d) => api.send('stats', d);
      world.events.placed = () => api.send('placed');
    } else {
      world.W = W; world.H = H; world.setVisible(visible);
    }
  }

  function applyState(s) {
    K.lang = s.lang;
    setup(s.display);
    world.running = s.running;
    world.laser = s.laser;
    world.placing = s.placing;
    world.setCats(s.cats);
  }

  api.onState(applyState);
  api.onWindows((list) => { if (world) world.setWindows(list); });
  api.onCursor((c) => { cursor = c; });
  api.onBowlAction((name) => { if (world) world.bowlAction(name); });
  window.__errors = [];
  window.addEventListener('error', (e) => window.__errors.push(String(e.message) + ' @' + e.filename + ':' + e.lineno));

  // mouse events only arrive while the window captures the mouse (or as forwarded moves while it does not)
  const pos = (e) => ({ x: e.clientX, y: H - e.clientY });
  window.addEventListener('mousemove', (e) => {
    modifierHeld = e.ctrlKey || e.altKey;
    leftDown = (e.buttons & 1) === 1;
    if (world && (world.dragCat || world.dragBowl)) world.mouseEvent('dragged', pos(e));
  });
  window.addEventListener('mousedown', (e) => {
    if (!world) return;
    if (e.button === 2) { world.mouseEvent('rightDown', pos(e)); return; }
    if (e.button === 0) { leftDown = true; world.mouseEvent('down', pos(e)); }
  });
  window.addEventListener('mouseup', (e) => {
    if (e.button === 0) { leftDown = false; if (world) world.mouseEvent('up', pos(e)); }
  });
  window.addEventListener('contextmenu', (e) => e.preventDefault());

  let last = 0;
  function frame(t) {
    requestAnimationFrame(frame);
    if (!world) return;
    if (t - last < 1000 / 45) return;                                   // about 45 frames a second is plenty
    last = t;
    const now = t / 1000;
    world.tick(now, cursor, leftDown);

    // catch the mouse only when a cat or bowl needs it
    const want = world.wantsMouse(modifierHeld);
    if (want !== capturing) { capturing = want; api.send('capture', want); }

    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, W, H);
    if (!world.running) return;
    for (const b of world.bowls) K.drawBowl(ctx, b, H);
    if (world.placing) K.drawBowl(ctx, { kind: world.placing, x: cursor.x, y: cursor.y - 1, amount: 1 }, H, 0.6);
    // the cat hanging with its back to you goes in front of the others
    const cats = [...world.cats.values()].sort((a, b) => (a.state === 'hang' && a.hangSlot === 2 ? 1 : 0) - (b.state === 'hang' && b.hangSlot === 2 ? 1 : 0));
    for (const c of cats) K.drawCat(ctx, c, world.renderInfo(c), H, now);
    if (world.laser) K.drawLaser(ctx, cursor, H, now);
  }
  requestAnimationFrame(frame);

  api.ready();
})();

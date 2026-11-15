// Headless simulation of the cats' behavior (no screen needed). Run: node test/sim.js
const path = require('path');
globalThis.Path2D = class { addPath() {} moveTo() {} lineTo() {} closePath() {} arc() {} ellipse() {} quadraticCurveTo() {} bezierCurveTo() {} rect() {} roundRect() {} };
for (const f of ['loc', 'model', 'render-core', 'costumes', 'world', 'world-brain', 'world-play']) require(path.join('..', 'src', f + '.js'));
const K = globalThis.K;
let failures = 0;
const check = (name, ok, extra) => { console.log((ok ? 'PASS ' : 'FAIL ') + name + (extra ? '  ' + extra : '')); if (!ok) failures++; };

function makeWorld(windows, cats, setup) {
  const w = new K.World({ width: 1710, height: 1107, visible: { minX: 0, minY: 0, maxX: 1710, maxY: 1073 } });
  w.now = 0;
  w.setWindows(windows);
  const cfgs = cats.map((c, i) => Object.assign(K.newCat('C' + i, c.coat || 'ginger', 'green', 1.2), { id: 'cat' + i }));
  w.setCats(cfgs);
  cats.forEach((c, i) => {
    const cat = w.cats.get('cat' + i);
    cat.x = c.x; cat.y = c.y; cat.vy = 0; cat.socialReady = 1e9;
    if (c.surface !== undefined) { cat.surface = c.surface; cat.state = 'sit'; cat.until = 0; }
  });
  if (setup) setup(w);
  return w;
}
function run(w, seconds, each) {
  const dt = 1 / 40;
  for (let t = 0; t < seconds; t += dt) {
    w.tick(w.now + dt, { x: 800, y: 600 }, false);
    if (each) each(w);
  }
}

// ---- 1. stairs: the top window cannot be reached from the floor, so the cat has to hop from window to window
{
  const wins = [
    { id: 901, x: 200, y: 0, w: 420, h: 300 }, { id: 902, x: 700, y: 120, w: 400, h: 300 }, { id: 903, x: 1180, y: 460, w: 400, h: 100 },
  ];
  const w = makeWorld(wins, [{ x: 100, y: 0, surface: 'ground' }]);
  const cat = w.cats.get('cat0');
  let stage = 0; const seen = new Set();
  run(w, 90, () => {
    if (stage === 0 && cat.surface === 'ground') { stage = 1; cat.goal = { k: 'visit', id: 901 }; cat.goalX = 400; cat.goalDeadline = w.now + 90; w.pursueGoal(cat); }
    else if (stage === 1 && cat.surface === 901) { stage = 2; cat.goal = { k: 'visit', id: 903 }; cat.goalX = 1400; cat.goalDeadline = w.now + 90; w.pursueGoal(cat); }
    if (typeof cat.surface === 'number') seen.add(cat.surface);
  });
  check('stairs: cat climbed window 1, hopped to 2 and on to 3', seen.has(901) && seen.has(902) && seen.has(903), 'surfaces visited: ' + [...seen].join(','));
}

// ---- 2. hanging under a window whose bottom edge is partly covered (covered span x=342..558)
{
  const wins = [{ id: 902, x: 350, y: 60, w: 200, h: 240 }, { id: 901, x: 200, y: 150, w: 500, h: 250 }];
  const w = makeWorld(wins, [{ x: 100, y: 0, surface: 'ground' }]);
  const cat = w.cats.get('cat0');
  let under = 0, bad = 0;
  run(w, 60, () => {
    if (cat.surface === 'ground' && cat.state !== 'jump' && !cat.goal && w.tryUnder(cat)) { /* started */ }
    if (cat.state === 'underWin' && cat.underWin === 901) { under++; if (cat.x > 342 && cat.x < 558) bad++; }
  });
  check('under-window: hung on the visible part only', under > 20 && bad === 0, 'samples ' + under + ', inside covered span ' + bad);
}

// ---- 3. a window slides over a standing cat: it either falls or grabs the front window
{
  let fell = 0, grabbed = 0;
  for (let i = 0; i < 24; i++) {
    const A = { id: 901, x: 200, y: 150, w: 500, h: 250 };
    const w = makeWorld([A], [{ x: 450, y: 400, surface: 901 }]);
    const cat = w.cats.get('cat0');
    run(w, 2, () => { cat.until = w.now + 5; });
    w.setWindows([{ id: 903, x: 330, y: 100, w: 240, h: 550 }, A]);
    let sawClimb = false, sawFall = false;
    run(w, 6, () => { if (cat.state === 'climb') sawClimb = true; if (cat.state === 'fall') sawFall = true; });
    if (sawClimb) grabbed++; else if (sawFall) fell++;
  }
  check('covered cat: sometimes falls, sometimes grabs the front window', fell > 0 && grabbed > 0, 'fell ' + fell + ', grabbed ' + grabbed + ' of 24');
}

// ---- 4. five cats for ten simulated minutes: nothing throws, nobody ends up stuck in the air
{
  const wins = [{ id: 901, x: 200, y: 100, w: 500, h: 400 }, { id: 902, x: 800, y: 0, w: 500, h: 300 }];
  const cats = [0, 1, 2, 3, 4].map((i) => ({ x: 300 + i * 220, y: 900, coat: K.coatPresets[i].id }));
  const w = makeWorld(wins, cats, (wd) => { for (const c of wd.cats.values()) c.socialReady = 0; });
  const states = {}; let stuck = 0, err = null;
  try {
    run(w, 600, () => {
      for (const c of w.cats.values()) {
        states[c.state] = (states[c.state] || 0) + 1;
        if (c.surface === null && ['sit', 'loaf', 'sleep', 'walk', 'groom'].includes(c.state)) stuck++;
        if (!isFinite(c.x) || !isFinite(c.y) || c.x < -50 || c.x > 1760 || c.y < -50 || c.y > 1200) stuck++;
      }
    });
  } catch (e) { err = e; }
  check('long run: no exceptions, no cat stuck in the air or off screen', !err && stuck === 0, err ? String(err.stack) : 'states: ' + Object.keys(states).sort().join(' '));
}

console.log(failures ? '\n' + failures + ' check(s) failed' : '\nall checks passed');
process.exit(failures ? 1 : 0);

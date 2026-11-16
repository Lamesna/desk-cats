// Draws the whole scene on the overlay canvas: cats, speech bubbles, hearts, bowls, laser dot.
// Port of the view code in Overlay.swift. World coordinates are y-up; the canvas is y-down, so every
// call converts with Y = H - y.
(function (K) {
  'use strict';
  const PI = Math.PI;
  const { P, css } = K;

  const FONT = '"Segoe UI", "Microsoft YaHei", system-ui, -apple-system, sans-serif';

  function drawBowl(ctx, b, H, alpha) {
    const w = 46, kind = b.kind, amount = b.amount;
    ctx.save();
    ctx.globalAlpha = alpha === undefined ? 1 : alpha;
    ctx.translate(b.x - 23, H - (b.y - 3));
    ctx.scale(1, -1);                                         // local y-up, origin at the bowl's bottom-left
    const color = kind === 'food' ? 0xE2604F : 0x4D8FDB;
    const oval = (x, y, ow, oh) => { const p = new Path2D(); p.ellipse(x + ow / 2, y + oh / 2, ow / 2, oh / 2, 0, 0, 2 * PI); return p; };
    // shadow
    ctx.fillStyle = 'rgba(0,0,0,0.15)';
    ctx.fill(oval(4, 1, w - 8, 5));
    // contents
    const top = { x: 6, y: 12, w: w - 12, h: 8 };
    if (amount > 0.01) {
      if (kind === 'food') {
        const n = Math.ceil(amount * 9);
        const pts = [[12, 16], [18, 18], [24, 17], [30, 18], [35, 16], [15, 19], [21, 20], [27, 20], [32, 19]];
        pts.slice(0, n).forEach((p, i) => {
          ctx.fillStyle = css(i % 2 === 0 ? 0x9B5E34 : 0xB9773F);
          ctx.fill(oval(p[0] - 3, p[1] - 2 + amount * 2, 6, 4.5));
        });
      } else {
        ctx.fillStyle = css(0x8CCBF5, 0.95);
        ctx.fill(oval(top.x + 1, 14 + amount * 2, top.w - 2, 3 + amount * 4));
      }
    } else {
      ctx.fillStyle = css(0x6B3A2E, 0.35);
      ctx.fill(oval(top.x + 2, top.y + 1, top.w - 4, top.h - 2));
    }
    // bowl body
    const body = new Path2D();
    body.moveTo(4, 16);
    body.lineTo(w - 4, 16);
    body.bezierCurveTo(w - 5, 9, w - 7, 4, w - 10, 3);
    body.lineTo(10, 3);
    body.bezierCurveTo(7, 4, 5, 9, 4, 16);
    body.closePath();
    ctx.fillStyle = css(color);
    ctx.fill(body);
    ctx.strokeStyle = css(0x34302E, 0.8);
    ctx.lineWidth = 1.4;
    ctx.stroke(body);
    // rim
    ctx.strokeStyle = K.darker(color, 1.15);
    ctx.lineWidth = 1.4;
    ctx.stroke(oval(3, 13.5, w - 6, 5));
    // paw print
    ctx.fillStyle = 'rgba(255,255,255,0.85)';
    const cx = w / 2, cy = 8;
    ctx.fill(oval(cx - 2.5, cy - 2.5, 5, 4));
    for (const dx of [-3.2, -1.1, 1.1, 3.2]) ctx.fill(oval(cx + dx - 1, cy + 1.8 - Math.abs(dx) * 0.25, 2, 2));
    ctx.restore();
  }

  function drawLaser(ctx, m, H, t) {
    const pulse = 1 + 0.15 * Math.sin(t * 12), x = m.x, y = H - m.y;
    for (const [r, a] of [[13, 0.12], [8, 0.25], [4.5, 0.9]]) {
      ctx.fillStyle = `rgba(255,26,26,${a})`;
      ctx.beginPath(); ctx.arc(x, y, r * pulse, 0, 2 * PI); ctx.fill();
    }
    ctx.fillStyle = 'rgba(255,255,255,0.9)';
    ctx.beginPath(); ctx.arc(x + 0.3, y - 0.8, 1.3, 0, 2 * PI); ctx.fill();
  }

  /** One cat with its extras. `ri` is the render info from World.renderInfo. */
  function drawCat(ctx, gc, c, ri, H, now) {
    const s = c.scale, ax = c.x, ay = c.y, sy = H - ay;       // feet in canvas coordinates
    if (K.pixelMode && K.pixel) K.pixel.drawCat(ctx, c, ri, H, now);
    else {
      ctx.save();
      ctx.translate(ax, sy);
      ctx.scale(s, -s);
      K.draw(gc, c.look, ri);
      ctx.restore();
    }

    const headTop = ['sleep', 'loaf', 'crouch', 'eat'].includes(ri.pose) ? 30 : ri.pose === 'climb' ? 52 : ri.pose === 'dangle' ? 58 : 46;
    const up = (dy) => sy - dy * s;                            // a point `dy` cat pixels above the feet

    // fight cloud
    if (c.state === 'social' && c.socialPose === 'roll') {
      for (let i = 0; i < 7; i++) {
        const ang = i / 7 * 2 * PI + now * 2.5, rr = (13 + 4 * Math.sin(now * 9 + i)) * s;
        ctx.fillStyle = 'rgba(209,209,209,0.5)';
        ctx.beginPath(); ctx.arc(ax + Math.cos(ang) * 22 * s, up(15 + Math.sin(ang) * 13), rr / 2, 0, 2 * PI); ctx.fill();
      }
    }

    // zzz
    if (c.state === 'sleep') {
      for (let i = 0; i < 3; i++) {
        const ph = (now * 0.5 + i / 3) % 1;
        ctx.font = `bold ${(8 + ph * 6) * s}px ${FONT}`;
        ctx.fillStyle = css(0x6E7DB8, 1 - ph);
        ctx.fillText('z', ax + (14 + ph * 16) * s * ri.facing, up(26 + ph * 30));
      }
    }

    // hearts
    for (const h of c.hearts) {
      const age = now - h.born, a = Math.max(0, 1 - age / 1.6);
      ctx.font = `bold ${12 * s}px ${FONT}`;
      ctx.fillStyle = css(0xF0527A, a);
      ctx.fillText('♥', ax + h.dx * s - 5 * s, up(headTop - 4 + age * 26));
    }

    // speech bubble
    if (c.bubble) {
      const size = Math.max(10, 10.5 * s);
      ctx.font = `bold ${size}px ${FONT}`;
      const tw = ctx.measureText(c.bubble).width, bw = tw + 12, bh = size * 1.25 + 6;
      let x = ax - bw / 2 + 6 * s * ri.facing;
      x = Math.min(Math.max(ax - 75 * s + 2, x), ax + 75 * s - bw - 2);
      const yb = up(headTop + 6);                              // bottom edge of the bubble (canvas y)
      const top = yb - bh;
      const path = new Path2D();
      path.roundRect(x, top, bw, bh, bh / 2);
      ctx.fillStyle = 'rgba(255,255,255,0.96)';
      ctx.strokeStyle = 'rgba(52,48,46,0.7)';
      ctx.lineWidth = 1.2;
      ctx.fill(path); ctx.stroke(path);
      const tail = new Path2D();
      tail.moveTo(ax - 3, yb - 1); tail.lineTo(ax + 1, yb + 5); tail.lineTo(ax + 5, yb - 1); tail.closePath();
      ctx.fill(tail);
      ctx.fillStyle = c.bubbleAlert ? '#D93A3A' : '#34302E';
      ctx.textBaseline = 'middle';
      ctx.fillText(c.bubble, x + 6, top + bh / 2 + 0.5);
      ctx.textBaseline = 'alphabetic';
    }
  }

  K.drawBowl = drawBowl;
  K.drawLaser = drawLaser;
  K.drawCat = drawCat;
})(globalThis.K = globalThis.K || {});

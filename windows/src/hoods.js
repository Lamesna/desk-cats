// Hood hats. Port of Costumes.swift, second half.
(function (K) {
  'use strict';
  const PI = Math.PI;
  const { P, lerp, R, ovalRect, ellipse, poly, stroked, css } = K;
  const rr = (gc, x, y, w, h, r) => { const p = new Path2D(); p.roundRect(x, y, w, h, r); gc.addPath(p); };

  /** A hood around the face; `behind` draws ears and antennae first, `top` draws the face printed on the hood. */
  function hood(gc, g, fx, k, color, rim, behind, top) {
    const h = g.head;
    if (behind) behind();
    const outer = ellipse(P(h.x, h.y + 1.5 * k), 15.5 * k, 15 * k);
    const opening = ellipse(P(fx, h.y - 0.6 * k), 11.6 * k, 10.2 * k);
    const path = new Path2D();
    path.addPath(outer);
    if (!g.backView) path.addPath(opening);
    gc.fill(css(color));
    gc.addPath(path);
    gc.fillPath('evenodd');
    if (!g.backView && rim !== undefined && rim !== null) {
      const ring = new Path2D();
      ring.addPath(ellipse(P(fx, h.y - 0.6 * k), 13 * k, 11.5 * k));
      ring.addPath(opening);
      gc.fill(css(rim));
      gc.addPath(ring);
      gc.fillPath('evenodd');
    }
    if (!g.backView && top) top();
  }

  function dots(gc, x, y, gap, r) {
    gc.fill(css(0x1B1B1F));
    gc.fillEllipse(ovalRect(x - gap, y, r, r * 1.1));
    gc.fillEllipse(ovalRect(x + gap, y, r, r * 1.1));
    gc.fill(css(0xFFFFFF));
    gc.fillEllipse(ovalRect(x - gap + r * 0.35, y + r * 0.4, r * 0.35, r * 0.35));
    gc.fillEllipse(ovalRect(x + gap + r * 0.35, y + r * 0.4, r * 0.35, r * 0.35));
  }
  function blush(gc, x, y, gap, k) {
    gc.fill(css(0xF48FB1, 0.7));
    gc.fillEllipse(ovalRect(x - gap, y, 1.8 * k, 1.1 * k));
    gc.fillEllipse(ovalRect(x + gap, y, 1.8 * k, 1.1 * k));
  }
  function smile(gc, x, y, k) {
    gc.stroke(css(0x1B1B1F));
    gc.lw(0.6 * k);
    gc.move(P(x - 1.6 * k, y)); gc.quad(P(x, y), P(x - 0.8 * k, y - 1 * k));
    gc.quad(P(x + 1.6 * k, y), P(x + 0.8 * k, y - 1 * k));
    gc.strokePath();
  }
  function roundEars(gc, h, k, color, inner) {
    for (const s of [-1, 1]) {
      const e = P(h.x + s * 11 * k, h.y + 14 * k);
      gc.fill(css(color));
      gc.fillEllipse(ovalRect(e.x, e.y, 4.6 * k, 4.6 * k));
      if (inner !== undefined) { gc.fill(css(inner)); gc.fillEllipse(ovalRect(e.x, e.y, 2.4 * k, 2.4 * k)); }
    }
  }
  function pointEars(gc, h, k, color, inner) {
    for (const s of [-1, 1]) {
      const tri = [P(h.x + s * 14 * k, h.y + 8 * k), P(h.x + s * 11 * k, h.y + 22 * k), P(h.x + s * 4 * k, h.y + 14 * k)];
      gc.fill(css(color)); gc.addPath(poly(tri)); gc.fillPath();
      if (inner !== undefined) {
        const c = P((tri[0].x + tri[1].x + tri[2].x) / 3, (tri[0].y + tri[1].y + tri[2].y) / 3);
        gc.fill(css(inner));
        gc.addPath(poly(tri.map((p) => P(p.x + (c.x - p.x) * 0.45, p.y + (c.y - p.y) * 0.45))));
        gc.fillPath();
      }
    }
  }
  /** The mouth with teeth shared by the shark-like hoods: seven small triangles around the opening. */
  function teeth(gc, fx, h, k, ex, ey, tx, ty) {
    gc.fill(css(0xFFFFFF));
    for (let i = 0; i < 7; i++) {
      const a = (152 - i * 21) * PI / 180, da = 8 * PI / 180;
      const e = (ang) => P(fx + Math.cos(ang) * ex * k, h.y - 0.6 * k + Math.sin(ang) * ey * k);
      gc.addPath(poly([e(a - da), P(fx + Math.cos(a) * tx * k, h.y - 0.6 * k + Math.sin(a) * ty * k), e(a + da)]));
    }
    gc.fillPath();
  }

  function drawHood(gc, look, g, ri, fx, k) {
    const h = g.head;
    const fy = h.y + 12.5 * k;            // the face printed on the hood
    const back = g.backView;
    switch (look.hat) {
      case 'chick':
        hood(gc, g, fx, k, 0xF6D44A, 0xFBE58A, () => {
          gc.fill(css(0xF6D44A));
          for (const a of [80, 100, 120]) {
            const r = a * PI / 180;
            gc.addPath(stroked([P(h.x, h.y + 15 * k), P(h.x + Math.cos(r) * 7 * k, h.y + 15 * k + Math.sin(r) * 7 * k)], 2.4 * k));
          }
          for (const s of [-1, 1]) gc.addPath(ellipse(P(h.x + s * 15 * k, h.y - 3 * k), 4 * k, 6 * k, s * 0.4));
          gc.fillPath();
        }, () => {
          dots(gc, fx, fy, 3.6 * k, 1.1 * k);
          gc.fill(css(0xF0A12F));
          gc.fillEllipse(ovalRect(fx, fy - 2.4 * k, 2.4 * k, 1.4 * k));
        });
        break;
      case 'jester':
        hood(gc, g, fx, k, 0x2E2A33, 0xF2EEE8, () => {
          for (const s of [-1, 1]) {
            const tip = P(h.x + s * 18 * k, h.y + 21 * k);
            gc.fill(css(0x2E2A33));
            gc.addPath(poly([P(h.x + s * 4 * k, h.y + 15 * k), tip, P(h.x + s * 14 * k, h.y + 7 * k)]));
            gc.fillPath();
            gc.fill(css(0x1B1B1F));
            gc.fillEllipse(ovalRect(tip.x, tip.y, 1.8 * k, 1.8 * k));
          }
        }, () => {
          gc.fill(css(0xF4A7C0));
          gc.fillEllipse(ovalRect(fx, fy, 2.6 * k, 2.3 * k));
          gc.fillRect(R(fx - 1.4 * k, fy - 3.2 * k, 2.8 * k, 1.6 * k));
          gc.fill(css(0x2E2A33));
          gc.fillEllipse(ovalRect(fx - 1 * k, fy + 0.2 * k, 0.6 * k, 0.6 * k));
          gc.fillEllipse(ovalRect(fx + 1 * k, fy + 0.2 * k, 0.6 * k, 0.6 * k));
        });
        break;
      case 'vampire': {
        // slicked black hair with a widow's peak, little bat wings at the sides
        gc.fill(css(0x1E1C22));
        for (const s of [-1, 1]) {
          const b = P(h.x + s * 10 * k, h.y + 9 * k);
          gc.addPath(poly([b, P(b.x + s * 9 * k, b.y + 7 * k), P(b.x + s * 7 * k, b.y + 3 * k), P(b.x + s * 10 * k, b.y + 1 * k),
            P(b.x + s * 6 * k, b.y - 1 * k), P(b.x + s * 2 * k, b.y - 3 * k)]));
        }
        gc.fillPath();
        gc.save();
        gc.clipRect(R(h.x - 40, h.y + 3 * k, 80, 80));
        gc.addPath(ellipse(P(h.x, h.y + 2 * k), 13.4 * k, 11.4 * k));
        gc.fillPath();
        gc.restore();
        if (!back) {
          gc.addPath(poly([P(fx - 6 * k, h.y + 3.2 * k), P(fx, h.y + 0.2 * k), P(fx + 6 * k, h.y + 3.2 * k)]));
          gc.fillPath();
        }
        break;
      }
      case 'santa': {
        // red floppy hat, white fur brim, tip with a pompom flopping to the side
        const sway = Math.sin(ri.t * 1.6) * 1.2 * k;
        const hat = new Path2D();
        hat.moveTo(h.x - 12 * k, h.y + 6 * k);
        hat.quadraticCurveTo(h.x - 9 * k, h.y + 20 * k, h.x + 4 * k, h.y + 22 * k);
        hat.quadraticCurveTo(h.x + 13 * k, h.y + 22 * k, h.x + 15 * k + sway, h.y + 10 * k);
        hat.quadraticCurveTo(h.x + 12 * k, h.y + 15 * k, h.x + 9 * k, h.y + 15 * k);
        hat.quadraticCurveTo(h.x + 10 * k, h.y + 10 * k, h.x + 12 * k, h.y + 6 * k);
        hat.closePath();
        gc.fill(css(0xD32F2F)); gc.addPath(hat); gc.fillPath();
        gc.fill(css(0xFAFAF7));
        rr(gc, h.x - 13.6 * k, h.y + 3.4 * k, 27.2 * k, 4.6 * k, 2.3 * k); gc.fillPath();
        gc.fillEllipse(ovalRect(h.x + 15 * k + sway, h.y + 9.5 * k, 3.2 * k, 3.2 * k));
        break;
      }
      case 'tophat':
        gc.fill(css(0x1E1C22));
        gc.addPath(ellipse(P(h.x, h.y + 9 * k), 8.5 * k, 1.8 * k)); gc.fillPath();
        gc.fillRect(R(h.x - 5.5 * k, h.y + 9 * k, 11 * k, 10 * k));
        gc.addPath(ellipse(P(h.x, h.y + 19 * k), 5.5 * k, 1.2 * k)); gc.fillPath();
        gc.fill(css(0xD32F2F));
        gc.fillRect(R(h.x - 5.5 * k, h.y + 10.2 * k, 11 * k, 1.8 * k));
        break;
      case 'starhelm':
        gc.fill(css(0xF4F2EE));
        for (const s of [-1, 1]) {
          [7, 5.5].forEach((len, i) => {
            const base = P(h.x + s * 11.5 * k, h.y + (6 + i * 2) * k);
            const a = (45 + i * 20) * PI / 180;
            gc.addPath(stroked([base, P(base.x + s * Math.cos(a) * len * k, base.y + Math.sin(a) * len * k)], 2.2 * k));
          });
        }
        gc.fillPath();
        gc.save();
        gc.clipRect(R(h.x - 40, h.y + 3.5 * k, 80, 80));
        gc.fill(css(0x1E4FA3));
        gc.addPath(ellipse(P(h.x, h.y + 3 * k), 13 * k, 10.5 * k)); gc.fillPath();
        gc.restore();
        if (!back) { gc.fill(css(0xFFFFFF)); gc.addPath(K.star(P(fx, h.y + 8.5 * k), 2.8 * k)); gc.fillPath(); }
        break;
      case 'ironhelm':
        gc.fill(css(0xB71C1C));
        gc.addPath(ellipse(P(h.x, h.y - 0.4 * k), 13.8 * k, 11.2 * k)); gc.fillPath();
        if (!back) {
          const plate = new Path2D();
          plate.moveTo(fx - 8.5 * k, h.y + 5 * k);
          plate.lineTo(fx + 8.5 * k, h.y + 5 * k);
          plate.quadraticCurveTo(fx + 9 * k, h.y - 7 * k, fx, h.y - 9.5 * k);
          plate.quadraticCurveTo(fx - 9 * k, h.y - 7 * k, fx - 8.5 * k, h.y + 5 * k);
          gc.fill(css(0xE3B23C)); gc.addPath(plate); gc.fillPath();
          gc.fill(css(0x8DF0FF));
          for (const s of [-1, 1]) gc.addPath(poly([P(fx + s * 1.5 * k, h.y + 0.4 * k), P(fx + s * 6 * k, h.y + 1.4 * k), P(fx + s * 5.5 * k, h.y - 0.4 * k)]));
          gc.fillPath();
          gc.stroke(css(0x9C7A1E)); gc.lw(0.6 * k);
          gc.move(P(fx - 3 * k, h.y - 5 * k)); gc.line(P(fx + 3 * k, h.y - 5 * k)); gc.strokePath();
        }
        break;
      case 'banana':
        // yellow peel hood: brown stem on top, two strips of peel flopping open at the sides
        hood(gc, g, fx, k, 0xF6D84B, 0xFFF3B8, () => {
          gc.fill(css(0x6B4A2B));
          rr(gc, h.x - 1.8 * k, h.y + 15 * k, 3.6 * k, 6 * k, 1.2 * k);
          gc.fillPath();
        });
        for (const s of [-1, 1]) {
          const base = P(h.x + s * 7 * k, h.y + 13 * k), mid = P(h.x + s * 17 * k, h.y + 9 * k), tip = P(h.x + s * 18.5 * k, h.y - 1 * k);
          gc.fill(css(0xF6D84B));
          gc.addPath(stroked([base, mid, tip], 5 * k)); gc.fillPath();
          if (!back) {
            gc.fill(css(0xFFF3B8));
            gc.addPath(stroked([P(lerp(base.x, mid.x, 0.5), lerp(base.y, mid.y, 0.5)), mid, tip], 2.2 * k)); gc.fillPath();
          }
          gc.fill(css(0x6B4A2B));
          gc.fillEllipse(ovalRect(tip.x, tip.y - 1.4 * k, 1.3 * k, 1.1 * k));
        }
        break;
      case 'dino': case 'pinkdino': {
        const pink = look.hat === 'pinkdino';
        hood(gc, g, fx, k, pink ? 0xF2A9C4 : 0x79A85A, pink ? 0xFBE3EC : null, () => {
          // a row of spikes down the back of the head, all leaning the same way (up and back)
          gc.fill(css(pink ? 0xE04A6A : 0xF2C230));
          const dir = P(-0.55, 0.83), side = P(dir.y, -dir.x);
          for (let i = 0; i < 5; i++) {
            const a = (85 + i * 27) * PI / 180;
            const b = P(h.x + Math.cos(a) * 14 * k, h.y + 1.5 * k + Math.sin(a) * 13.5 * k);
            gc.addPath(poly([P(b.x - side.x * 2.6 * k, b.y - side.y * 2.6 * k), P(b.x + dir.x * 5.5 * k, b.y + dir.y * 5.5 * k),
              P(b.x + side.x * 2.6 * k, b.y + side.y * 2.6 * k)]));
          }
          gc.fillPath();
        }, () => {
          gc.stroke(css(0x1B1B1F)); gc.lw(0.7 * k);
          for (const s of [-1, 1]) { gc.move(P(fx + s * 3.6 * k - 1.2 * k, fy)); gc.quad(P(fx + s * 3.6 * k + 1.2 * k, fy), P(fx + s * 3.6 * k, fy + 1.4 * k)); }
          gc.strokePath();
          smile(gc, fx, fy - 2 * k, k);
          blush(gc, fx, fy - 1.5 * k, 6 * k, k);
        });
        break;
      }
      case 'panda':
        hood(gc, g, fx, k, 0xF4F2EE, null, () => roundEars(gc, h, k, 0x2A2A2E), () => {
          gc.fill(css(0x2A2A2E));
          for (const s of [-1, 1]) gc.addPath(ellipse(P(fx + s * 4 * k, fy), 2.2 * k, 1.6 * k, s * -0.5));
          gc.fillPath();
          gc.fill(css(0xFFFFFF));
          for (const s of [-1, 1]) gc.fillEllipse(ovalRect(fx + s * 4 * k, fy + 0.2 * k, 0.6 * k, 0.6 * k));
          gc.fill(css(0x2A2A2E));
          gc.fillEllipse(ovalRect(fx, fy - 2 * k, 0.9 * k, 0.6 * k));
        });
        break;
      case 'bunny':
        hood(gc, g, fx, k, 0xF3EDE2, null, () => {
          // long ears standing straight up, a little apart
          for (const s of [-1, 1]) {
            const c = P(h.x + s * 5.5 * k, h.y + 22 * k);
            gc.fill(css(0xF3EDE2));
            gc.addPath(ellipse(c, 3.8 * k, 10.5 * k, s * -0.12)); gc.fillPath();
            if (!back) {
              gc.fill(css(0xF6C1CF));
              gc.addPath(ellipse(P(c.x, c.y + 0.5 * k), 1.8 * k, 7.5 * k, s * -0.12)); gc.fillPath();
            }
          }
        }, () => {
          dots(gc, fx, fy, 3.6 * k, 0.9 * k);
          gc.fill(css(0xF48FB1));
          gc.fillEllipse(ovalRect(fx, fy - 1.8 * k, 0.9 * k, 0.6 * k));
          blush(gc, fx, fy - 1.6 * k, 6 * k, k);
        });
        break;
      case 'cap':
        gc.save();
        gc.clipRect(R(h.x - 40, h.y + 4 * k, 80, 80));
        gc.fill(css(0xD9302C));
        gc.addPath(ellipse(P(h.x, h.y + 3.5 * k), 13 * k, 11 * k));
        gc.fillPath();
        gc.restore();
        gc.fill(css(0xB52420));
        gc.addPath(ellipse(P(fx + 7 * k, h.y + 4.6 * k), 9 * k, 2.2 * k, 0.08));
        gc.fillPath();
        if (!back) { gc.fill(css(0xFFFFFF)); gc.fillEllipse(ovalRect(fx + 1 * k, h.y + 9.5 * k, 3.2 * k, 3 * k)); }
        break;
      case 'bee':
        hood(gc, g, fx, k, 0xF4C430, null, () => {
          gc.fill(css(0xCFE8F7, 0.8));
          for (const s of [-1, 1]) gc.addPath(ellipse(P(h.x + s * 17 * k, h.y + 10 * k), 5 * k, 3.5 * k, s * 0.4));
          gc.fillPath();
          gc.stroke(css(0x4A3423)); gc.lw(0.8 * k);
          for (const s of [-1, 1]) { gc.move(P(h.x + s * 3 * k, h.y + 15 * k)); gc.line(P(h.x + s * 6 * k, h.y + 23 * k)); }
          gc.strokePath();
          gc.fill(css(0x4A3423));
          for (const s of [-1, 1]) gc.fillEllipse(ovalRect(h.x + s * 6 * k, h.y + 23 * k, 1.6 * k, 1.6 * k));
        });
        // stripes across the hood
        gc.save();
        gc.addPath(ellipse(P(h.x, h.y + 1.5 * k), 15.5 * k, 15 * k));
        gc.addPath(ellipse(P(fx, h.y - 0.6 * k), 11.6 * k, 10.2 * k));
        gc.clip('evenodd');
        gc.fill(css(0x4A3423));
        for (const y of [8, 13]) gc.fillRect(R(h.x - 20 * k, h.y + y * k, 40 * k, 2.4 * k));
        gc.restore();
        break;
      case 'cowboy':
        gc.stroke(css(0x5A3A1C)); gc.lw(0.5);
        if (!back) {
          gc.move(P(h.x - 12 * k, h.y + 5 * k)); gc.line(P(fx, h.y - 11 * k)); gc.line(P(h.x + 12 * k, h.y + 5 * k));
          gc.strokePath();
        }
        gc.fill(css(0x8B5A2B));
        rr(gc, h.x - 7 * k, h.y + 6 * k, 14 * k, 10 * k, 4 * k); gc.fillPath();
        gc.addPath(ellipse(P(h.x, h.y + 6.5 * k), 18 * k, 3.4 * k)); gc.fillPath();
        gc.fill(css(0x5A3A1C));
        gc.fillRect(R(h.x - 7 * k, h.y + 7.5 * k, 14 * k, 1.6 * k));
        if (!back) { gc.fill(css(0xF5C542)); gc.addPath(K.star(P(fx, h.y + 12 * k), 2.4 * k)); gc.fillPath(); }
        break;
      case 'bear':
        hood(gc, g, fx, k, 0xA7703F, null, () => roundEars(gc, h, k, 0xA7703F, 0xE0B68A), () => {
          gc.fill(css(0xE8C9A0));
          gc.fillEllipse(ovalRect(fx, fy - 1.6 * k, 3 * k, 2.2 * k));
          dots(gc, fx, fy + 0.8 * k, 4 * k, 0.9 * k);
          gc.fill(css(0x3B2A1A));
          gc.fillEllipse(ovalRect(fx, fy - 1 * k, 0.9 * k, 0.6 * k));
        });
        break;
      case 'penguin':
        hood(gc, g, fx, k, 0x2D3756, null, () => {
          gc.fill(css(0x2D3756));
          gc.fillEllipse(ovalRect(h.x, h.y + 17 * k, 2.4 * k, 2 * k));
        }, () => {
          gc.fill(css(0xF4F2EE));
          gc.fillEllipse(ovalRect(fx, fy - 0.5 * k, 7.5 * k, 3.6 * k));
          dots(gc, fx, fy, 3.4 * k, 0.9 * k);
          gc.fill(css(0xF0A12F));
          gc.addPath(poly([P(fx - 1.3 * k, fy - 1.4 * k), P(fx + 1.3 * k, fy - 1.4 * k), P(fx, fy - 3 * k)])); gc.fillPath();
          blush(gc, fx, fy - 1.4 * k, 5.5 * k, k);
        });
        break;
      case 'merc':
        // full face mask over head and ears, black patches around white eye slits; two hilts behind
        gc.stroke(css(0x2A2A2E)); gc.lw(1.8 * k);
        for (const s of [-1, 1]) { gc.move(P(h.x + s * 9 * k, h.y + 4 * k)); gc.line(P(h.x + s * 16 * k, h.y + 19 * k)); }
        gc.strokePath();
        gc.fill(css(0xC62828));
        gc.addPath(ellipse(P(h.x, h.y - 0.5 * k), 13.6 * k, 10.9 * k)); gc.fillPath();
        // the cat's own ear shapes, slightly enlarged, so no fur peeks out at the edges
        for (const e of K.earPaths(h, g.headR * 1.04, g.earsFlat)) { gc.addPath(e); gc.fillPath(); }
        if (!back) {
          for (const s of [-1, 1]) {
            const e = P(fx + s * 5 * k, h.y + 0.6 * k);
            const patch = new Path2D();
            patch.moveTo(e.x - s * 3.2 * k, e.y - 2.4 * k);
            patch.quadraticCurveTo(e.x + s * 5.2 * k, e.y - 3.4 * k, e.x + s * 4.6 * k, e.y + 3.4 * k);
            patch.quadraticCurveTo(e.x - s * 4.6 * k, e.y + 4 * k, e.x - s * 3.2 * k, e.y - 2.4 * k);
            gc.fill(css(0x111111)); gc.addPath(patch); gc.fillPath();
            gc.fill(css(0xFAFAF7));
            gc.addPath(ellipse(P(e.x + s * 0.4 * k, e.y + 0.4 * k), 2.1 * k, 1.1 * k, s * 0.45)); gc.fillPath();
          }
        }
        break;
      case 'witch': {
        gc.fill(css(0x3A3440));
        gc.addPath(ellipse(P(h.x, h.y + 6.5 * k), 17 * k, 3.4 * k));
        gc.fillPath();
        const cone = new Path2D();
        cone.moveTo(h.x - 9 * k, h.y + 6.5 * k);
        cone.quadraticCurveTo(h.x - 1 * k, h.y + 24 * k, h.x + 14 * k, h.y + 26 * k);
        cone.quadraticCurveTo(h.x + 7 * k, h.y + 16 * k, h.x + 9 * k, h.y + 6.5 * k);
        cone.closePath();
        gc.addPath(cone); gc.fillPath();
        gc.fill(css(0x7E57C2));
        gc.fillRect(R(h.x - 8.6 * k, h.y + 7.5 * k, 17.4 * k, 2.4 * k));
        if (!back) { gc.fill(css(0xF5C542)); gc.addPath(K.star(P(h.x + 5 * k, h.y + 8.7 * k), 2 * k)); gc.fillPath(); }
        break;
      }
      case 'monster':
        hood(gc, g, fx, k, 0x9B7FD1, null, () => {
          for (const s of [-1, 1]) {
            gc.stroke(css(0x7E62B8)); gc.lw(1.4 * k);
            gc.move(P(h.x + s * 5 * k, h.y + 14 * k)); gc.line(P(h.x + s * 8 * k, h.y + 22 * k)); gc.strokePath();
            gc.fill(css(0xFFFFFF)); gc.fillEllipse(ovalRect(h.x + s * 8 * k, h.y + 23 * k, 2.6 * k, 2.6 * k));
            gc.fill(css(0x1B1B1F)); gc.fillEllipse(ovalRect(h.x + s * 8 * k + 0.4 * k, h.y + 23 * k, 1.2 * k, 1.2 * k));
          }
        }, () => {
          teeth(gc, fx, h, k, 11.6, 10.2, 8.8, 7.6);
          smile(gc, fx, fy, k);
          blush(gc, fx, fy + 0.4 * k, 5 * k, k);
        });
        break;
      case 'ghost': {
        gc.fill(css(0xF6F4EE));
        const p = new Path2D();
        p.moveTo(h.x - 15 * k, h.y - 12 * k);
        p.lineTo(h.x - 15 * k, h.y + 4 * k);
        p.quadraticCurveTo(h.x, h.y + 27 * k, h.x + 15 * k, h.y + 4 * k);
        p.lineTo(h.x + 15 * k, h.y - 12 * k);
        p.quadraticCurveTo(h.x + 12 * k, h.y - 9 * k, h.x + 8 * k, h.y - 10 * k);
        p.lineTo(h.x + 10 * k, h.y - 1 * k);
        p.lineTo(h.x - 10 * k, h.y - 1 * k);
        p.lineTo(h.x - 8 * k, h.y - 10 * k);
        p.quadraticCurveTo(h.x - 12 * k, h.y - 9 * k, h.x - 15 * k, h.y - 12 * k);
        p.closePath();
        const path = new Path2D();
        path.addPath(p);
        if (!back) path.addPath(ellipse(P(fx, h.y - 0.6 * k), 11.2 * k, 9.8 * k));
        gc.addPath(path); gc.fillPath('evenodd');
        if (!back) {
          gc.fill(css(0x1B1B1F));
          for (const s of [-1, 1]) gc.fillEllipse(ovalRect(fx + s * 3.6 * k, fy, 1.4 * k, 1.9 * k));
        }
        break;
      }
      case 'unicorn':
        hood(gc, g, fx, k, 0xF7F3EE, null, () => {
          pointEars(gc, h, k, 0xF7F3EE, 0xF6C1CF);
          [0xF48FB1, 0x81D4FA, 0xB39DDB, 0xFFE082].forEach((col, i) => {
            gc.fill(css(col));
            gc.fillEllipse(ovalRect(h.x + (9 + i * 1.5) * k, h.y + (16 - i * 2.4) * k, 2.4 * k, 2.4 * k));
          });
        }, () => {
          dots(gc, fx, fy - 0.5 * k, 3.6 * k, 0.9 * k);
          smile(gc, fx, fy - 2.5 * k, k);
          blush(gc, fx, fy - 2 * k, 5.8 * k, k);
        });
        gc.fill(css(0xF2C230));
        gc.addPath(poly([P(h.x - 2.2 * k, h.y + 15.5 * k), P(h.x + 0.5 * k, h.y + 26 * k), P(h.x + 2.2 * k, h.y + 15.5 * k)]));
        gc.fillPath();
        break;
      default: break;
    }
  }

  K.drawHood = drawHood;
})(globalThis.K = globalThis.K || {});

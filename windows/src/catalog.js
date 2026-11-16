// Everything a cat can look like: coat colours worked out once per cat, the costume table and the lists of
// hats and costumes for the menu. Drawing lives in pixel.js.
(function (K) {
  'use strict';

  const rgbOf = (hex) => [(hex >> 16) & 255, (hex >> 8) & 255, hex & 255];
  const css = (hex, a) => { const c = rgbOf(hex); return `rgba(${c[0]},${c[1]},${c[2]},${a === undefined ? 1 : a})`; };
  // a rectangle with the same handy fields as CGRect (the world uses it for hit boxes)
  const R = (x, y, w, h) => ({ x, y, w, h, width: w, height: h, minX: x, minY: y, maxX: x + w, maxY: y + h, midX: x + w / 2, midY: y + h / 2 });
  const P = (x, y) => ({ x, y });
  const darker = (hex, f) => { const c = rgbOf(hex); return `rgb(${Math.round(c[0] * f)},${Math.round(c[1] * f)},${Math.round(c[2] * f)})`; };

  const C = (name, body, o) => Object.assign({ name, body, tail: false }, o || {});
  K.costumes = {
    c_chick: C('Chick', 0xF6D44A, { paws: 0xF0A12F }),
    c_shark: C('Shark', 0x5D7C9C, { belly: 0xF2EEE6, paws: 0xF2EEE6, tail: true }),
    c_vampire: C('Vampire', 0x2A2730, { paws: 0x1C1A20 }),
    c_dino: C('Dinosaur', 0x79A85A, { belly: 0xF1E3A0, paws: 0xF1E3A0, tail: true }),
    c_bunny: C('Bunny', 0xF7F4F0, { paws: 0xFFFFFF, tail: true }),
    c_panda: C('Panda', 0xF4F2EE, { legs: 0x2A2A2E }),
    c_plumber: C('Overalls', 0xD9302C, { paws: 0xF4F2EE, legs: 0x2F5DAE }),
    c_kitty: C('Bow jumpsuit', 0xF7F5F2, { paws: 0xF7F5F2, legs: 0xD7262F }),
    c_bee: C('Bee', 0xF4C430, { stripes: 0x4A3423 }),
    c_wizard: C('Wizard', 0x2C2F55, { legs: 0x2C2F55 }),
    c_frog: C('Froggy', 0x79A85A, { belly: 0xF1EBC4, paws: 0x79A85A }),
    c_cowboy: C('Cowboy', 0x8B5A2B, { belly: 0xF1E7D2, legs: 0xF4F2EE }),
    c_penguin: C('Penguin', 0x2D3756, { belly: 0xF4F2EE, paws: 0xF4F2EE }),
    c_pinkdino: C('Pink dino', 0xF2A9C4, { belly: 0xFBE3EC, paws: 0xFBE3EC, tail: true }),
    c_bear: C('Teddy bear', 0xA7703F, { belly: 0xE8C9A0, paws: 0x7B4F2A }),
    c_ghost: C('Ghost', 0xF6F4EE, { tail: true }),
    c_banana: C('Banana', 0xF6D84B, { paws: 0x6B4A2B }),
    c_merc: C('Mercenary', 0xC62828, { legs: 0x2A2A2E }),
    c_spider: C('Spider', 0xD7262F, { paws: 0xD7262F, legs: 0x1E4FA3 }),
    c_royal: C('Royal robe', 0xB71C1C, { paws: 0xF4F2EE }),
    c_party: C('Party', 0xF48FB1, { paws: 0xFFFFFF, spots: [0xFFEB3B, 0x4FC3F7, 0x81C784] }),
    c_trickster: C('Trickster', 0x2E7D32, { belly: 0xE3B23C, legs: 0x1B1B1F }),
    c_jester: C('Jester', 0x2E2A33, { belly: 0xF2EEE8, paws: 0xF4A7C0 }),
    c_monster: C('Monster', 0x9B7FD1, { belly: 0xD9CCF2, paws: 0x7E62B8, tail: true }),
    c_unicorn: C('Unicorn', 0xF7F3EE, { paws: 0xF2C230, tail: true }),
  };
  K.costumeOrder = ['c_chick', 'c_shark', 'c_vampire', 'c_dino', 'c_bunny', 'c_panda', 'c_plumber', 'c_kitty',
    'c_bee', 'c_wizard', 'c_frog', 'c_cowboy', 'c_penguin', 'c_pinkdino', 'c_bear', 'c_ghost', 'c_banana', 'c_merc',
    'c_spider', 'c_royal', 'c_party', 'c_trickster', 'c_jester', 'c_monster', 'c_unicorn'];

  K.hoodHats = [
    ['chick', 'Chick'], ['jester', 'Black jester'], ['banana', 'Banana'], ['dino', 'Dinosaur'],
    ['panda', 'Panda'], ['bunny', 'Bunny'], ['cap', 'Red cap'], ['bee', 'Bee'], ['cowboy', 'Cowboy'],
    ['bear', 'Teddy bear'], ['penguin', 'Penguin'], ['merc', 'Mercenary mask'], ['witch', 'Witch'],
    ['monster', 'Monster'], ['ghost', 'Ghost'], ['unicorn', 'Unicorn'], ['pinkdino', 'Pink dino'],
    ['vampire', 'Vampire'], ['santa', 'Santa'], ['tophat', 'Top hat'], ['starhelm', 'Star helmet'],
    ['ironhelm', 'Iron helmet'],
  ];

  K.hatOptions = [
    ['none', 'No hat'], ['shark', 'Shark'], ['frog', 'Frog'], ['crown', 'Crown'], ['party', 'Party hat'],
    ['bow', 'Bow'], ['spider', 'Spider mask'], ['horns', 'Horned helm'], ['winged', 'Winged helm'],
  ].concat(K.hoodHats).map(([id, name]) => ({ id, name }));
  K.outfitOptions = [
    ['none', 'No costume'], ['cape', 'Hero cape'], ['bowtie', 'Bow tie'], ['wings', 'Fairy wings'], ['reactor', 'Glowing reactor'],
  ].concat(K.costumeOrder.map((id) => [id, K.costumes[id].name])).map(([id, name]) => ({ id, name }));
  K.hatIds = new Set(K.hatOptions.map((o) => o.id));
  K.outfitIds = new Set(K.outfitOptions.map((o) => o.id));

  /** The colours of one cat, worked out once from its config. */
  function makeLook(c) {
    const p = K.preset(c.coat);
    const [e1, e2] = K.eyeRGB(c.eyes);
    const hat = c.hat === 'pig' ? 'pinkdino' : (c.hat || 'none');
    const outfit = c.outfit || 'none';
    return {
      baseHex: p.base, accentHex: p.accent, pattern: p.pattern,
      eyeL: css(e1), eyeR: css(e2), seed: c.seed >>> 0,
      hat: K.hatIds.has(hat) ? hat : 'none',
      outfit: K.outfitIds.has(outfit) ? outfit : 'none',
    };
  }

  Object.assign(K, { rgbOf, css, darker, R, P, makeLook });
})(globalThis.K = globalThis.K || {});

// Coats, eye colors and the cat config. Port of Model.swift.
(function (K) {
  'use strict';

  K.coatPresets = [
    { id: 'grayWhite',   name: 'Gray and white',   base: 0x8E949C, accent: 0x5F656D, pattern: 'bicolor',      eyes: 'green' },
    { id: 'ginger',      name: 'Ginger',           base: 0xEC9440, accent: 0xC4661C, pattern: 'tabby',        eyes: 'amber' },
    { id: 'black',       name: 'Black',            base: 0x2B2A2F, accent: 0x1A1A1D, pattern: 'solid',        eyes: 'yellow' },
    { id: 'white',       name: 'White',            base: 0xF6F5F1, accent: 0xE4E2DC, pattern: 'solid',        eyes: 'blue' },
    { id: 'blue',        name: 'Blue',             base: 0x8693A6, accent: 0x6D7A8C, pattern: 'solid',        eyes: 'copper' },
    { id: 'gingerWhite', name: 'Ginger and white', base: 0xEC9440, accent: 0xC4661C, pattern: 'tabbyBicolor', eyes: 'green' },
    { id: 'tuxedo',      name: 'Tuxedo',           base: 0x2B2A2F, accent: 0x1A1A1D, pattern: 'bicolor',      eyes: 'green' },
    { id: 'calico',      name: 'Calico',           base: 0xF6F3EC, accent: 0xE4893A, pattern: 'calico',       eyes: 'amber' },
    { id: 'tortie',      name: 'Tortoiseshell',    base: 0x3B2F2A, accent: 0xC9732E, pattern: 'tortie',       eyes: 'amber' },
    { id: 'grayTabby',   name: 'Gray tabby',       base: 0xA2A29C, accent: 0x55554F, pattern: 'tabby',        eyes: 'green' },
    { id: 'brownTabby',  name: 'Brown tabby',      base: 0xA97C52, accent: 0x4E3524, pattern: 'tabby',        eyes: 'yellow' },
    { id: 'cream',       name: 'Cream',            base: 0xF2DCB5, accent: 0xDDB47E, pattern: 'tabby',        eyes: 'copper' },
    { id: 'siamese',     name: 'Siamese',          base: 0xF1E8D8, accent: 0x5A4636, pattern: 'colorpoint',   eyes: 'blue' },
    { id: 'chocolate',   name: 'Chocolate',        base: 0x6E4632, accent: 0x52321F, pattern: 'solid',        eyes: 'yellow' },
    { id: 'smoky',       name: 'Smoky',            base: 0x5F6168, accent: 0x45474D, pattern: 'solid',        eyes: 'yellow' },
    { id: 'silver',      name: 'Silver',           base: 0xCDD1D4, accent: 0x6B7176, pattern: 'tabby',        eyes: 'green' },
    { id: 'peach',       name: 'Peach',            base: 0xF5C08E, accent: 0xE09A5B, pattern: 'tabbyBicolor', eyes: 'amber' },
    { id: 'grayBlack',   name: 'Black and white',  base: 0xF4F2EE, accent: 0x2B2A2F, pattern: 'calico',       eyes: 'yellow' },
  ];

  K.preset = (id) => K.coatPresets.find((p) => p.id === id) || K.coatPresets[0];

  K.eyeColors = ['green', 'yellow', 'amber', 'blue', 'copper', 'odd'];
  K.eyeName = {
    green: 'Green eyes', yellow: 'Yellow eyes', amber: 'Amber eyes', blue: 'Blue eyes', copper: 'Copper eyes', odd: 'Odd eyes',
  };
  const EYE_RGB = {
    green: [0x7BC24A, 0x7BC24A], yellow: [0xEACB45, 0xEACB45], amber: [0xE39A2C, 0xE39A2C],
    blue: [0x62AEEA, 0x62AEEA], copper: [0xC8732E, 0xC8732E], odd: [0x62AEEA, 0xEACB45],
  };
  K.eyeRGB = (e) => EYE_RGB[e] || EYE_RGB.green;

  // new cats get a random coat; the config is plain JSON so it can be saved and sent between windows
  K.newCat = function (name, coat, eyes, size) {
    const id = (globalThis.crypto && crypto.randomUUID) ? crypto.randomUUID()
      : 'c' + Math.random().toString(36).slice(2) + Date.now().toString(36);
    return {
      id, name, coat, eyes, size: size || 1.2, visible: true,
      seed: 1 + Math.floor(Math.random() * 4294967294), hat: 'none', outfit: 'none',
    };
  };

  K.randomCat = function (existing, names) {
    const p = K.coatPresets[Math.floor(Math.random() * K.coatPresets.length)];
    const used = new Set(existing.map((c) => c.name));
    const free = names.find((n) => !used.has(n));
    const name = free || (K.tr('Cat') + ' ' + (existing.length + 1));
    return K.newCat(name, p.id, p.eyes, 1.0 + Math.random() * 0.35);
  };
})(globalThis.K = globalThis.K || {});

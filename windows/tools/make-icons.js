// Renders assets/icon.png, assets/tray.png and assets/icon.ico. Usage: electron tools/make-icons.js
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');
app.disableHardwareAcceleration();
app.whenReady().then(async () => {
  const win = new BrowserWindow({ show: false, width: 256, height: 256, transparent: true, frame: false, webPreferences: { offscreen: false } });
  await win.loadFile(path.join(__dirname, 'icon.html'));
  await new Promise((r) => setTimeout(r, 400));
  const img = await win.webContents.capturePage({ x: 0, y: 0, width: 256, height: 256 });
  const out = path.join(__dirname, '..', 'assets');
  fs.mkdirSync(out, { recursive: true });
  const big = img.resize({ width: 256, height: 256, quality: 'best' });   // the capture is 2x on a retina screen
  const png256 = big.toPNG();
  fs.writeFileSync(path.join(out, 'icon.png'), png256);
  fs.writeFileSync(path.join(out, 'tray.png'), big.resize({ width: 32, height: 32, quality: 'best' }).toPNG());
  // an .ico that holds one PNG image (supported since Windows Vista)
  const head = Buffer.alloc(22);
  head.writeUInt16LE(0, 0); head.writeUInt16LE(1, 2); head.writeUInt16LE(1, 4);                 // ICONDIR
  head.writeUInt8(0, 6); head.writeUInt8(0, 7); head.writeUInt8(0, 8); head.writeUInt8(0, 9);    // 256x256, no palette
  head.writeUInt16LE(1, 10); head.writeUInt16LE(32, 12);                                         // planes, bits per pixel
  head.writeUInt32LE(png256.length, 14); head.writeUInt32LE(22, 18);                             // size, offset
  fs.writeFileSync(path.join(out, 'icon.ico'), Buffer.concat([head, png256]));
  console.log('icons written to', out);
  app.quit();
});

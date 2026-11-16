// Renders tools/pixel-test.html in a hidden window and saves a PNG. Usage: electron tools/shot.js out.png [mode]
const { app, BrowserWindow } = require('electron');
const fs = require('fs');
const path = require('path');

app.disableHardwareAcceleration();
app.whenReady().then(async () => {
  const out = process.argv[2] || 'sheet.png';
  const mode = process.argv[3] || 'coats';
  const win = new BrowserWindow({ show: false, width: 1400, height: 1000, webPreferences: { offscreen: false } });
  win.webContents.on('console-message', (_e, lvl, msg, line, src) => console.log('PAGE', lvl, msg, src.split('/').pop() + ':' + line));
  await win.loadFile(path.join(__dirname, 'pixel-test.html'), { query: { mode } });
  await new Promise((r) => setTimeout(r, 400));
  const size = await win.webContents.executeJavaScript('({w: document.getElementById("c").width, h: document.getElementById("c").height})');
  win.setContentSize(size.w, size.h);
  await new Promise((r) => setTimeout(r, 300));
  const img = await win.webContents.capturePage({ x: 0, y: 0, width: size.w, height: size.h });
  fs.writeFileSync(out, img.toPNG());
  console.log('saved', out, size.w + 'x' + size.h);
  app.quit();
});

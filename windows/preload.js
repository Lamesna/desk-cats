// Safe bridge between the web pages (overlay and menu) and the main process.
const { contextBridge, ipcRenderer } = require('electron');

const on = (channel) => (cb) => ipcRenderer.on(channel, (_event, data) => cb(data));

contextBridge.exposeInMainWorld('kotiki', {
  send: (channel, data) => ipcRenderer.send(channel, data),
  ready: () => ipcRenderer.send('ready'),
  onState: on('state'),
  onWindows: on('windows'),
  onCursor: on('cursor'),
  onStats: on('stats'),
  onBowlAction: on('bowlAction'),
});

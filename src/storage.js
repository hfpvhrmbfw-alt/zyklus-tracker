/* Speicher: IndexedDB mit localStorage-Fallback. Kennt nur Einträge und Metadaten, keine Logik. */

// ---------- Speicher ----------
export const Store = {
  db: null, ls: false, LSKEY: 'zyklus-tracker-v1',
  async open() {
    try {
      this.db = await new Promise((res, rej) => {
        const r = indexedDB.open('zyklus-tracker', 1);
        r.onupgradeneeded = () => {
          r.result.createObjectStore('days', { keyPath: 'date' });
          r.result.createObjectStore('meta', { keyPath: 'key' });
        };
        r.onsuccess = () => res(r.result);
        r.onerror = () => rej(r.error);
      });
    } catch (e) { this.ls = true; }
  },
  _req(r) { return new Promise((res, rej) => { r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); }); },
  _os(name, mode) { return this.db.transaction(name, mode).objectStore(name); },
  _lsGet() { try { return JSON.parse(localStorage.getItem(this.LSKEY)) || { days: {}, meta: {} }; } catch { return { days: {}, meta: {} }; } },
  _lsSet(v) { localStorage.setItem(this.LSKEY, JSON.stringify(v)); },
  async allDays() {
    if (this.ls) return Object.values(this._lsGet().days);
    return this._req(this._os('days', 'readonly').getAll());
  },
  async putDay(e) {
    if (this.ls) { const v = this._lsGet(); v.days[e.date] = e; return this._lsSet(v); }
    return this._req(this._os('days', 'readwrite').put(e));
  },
  async putDays(list) {
    if (this.ls) { const v = this._lsGet(); list.forEach(e => { v.days[e.date] = e; }); return this._lsSet(v); }
    const tx = this.db.transaction('days', 'readwrite');
    list.forEach(e => tx.objectStore('days').put(e));
    return new Promise((res, rej) => { tx.oncomplete = res; tx.onerror = () => rej(tx.error); });
  },
  async delDay(date) {
    if (this.ls) { const v = this._lsGet(); delete v.days[date]; return this._lsSet(v); }
    return this._req(this._os('days', 'readwrite').delete(date));
  },
  async clearDays() {
    if (this.ls) { const v = this._lsGet(); v.days = {}; return this._lsSet(v); }
    return this._req(this._os('days', 'readwrite').clear());
  },
  async getMeta(key) {
    if (this.ls) return this._lsGet().meta[key];
    const r = await this._req(this._os('meta', 'readonly').get(key));
    return r ? r.value : undefined;
  },
  async setMeta(key, value) {
    if (this.ls) { const v = this._lsGet(); v.meta[key] = value; return this._lsSet(v); }
    return this._req(this._os('meta', 'readwrite').put({ key, value }));
  },
};

// 시험용 메모리 Firestore (쓰는 기능만: doc get/set/delete · runTransaction · collection where/orderBy/limit)
const clone = (x) => (x === undefined ? undefined : structuredClone(x));

class Snap {
  constructor(id, data) {
    this.id = id;
    this.exists = data !== undefined;
    this._d = data;
  }
  data() {
    return clone(this._d);
  }
}

class MemDb {
  constructor() {
    this.docs = new Map();
  }
  doc(path) {
    const db = this;
    return {
      path,
      id: path.split('/').pop(),
      async get() {
        return new Snap(this.id, db.docs.get(path));
      },
      async set(data, opt) {
        const cur = db.docs.get(path);
        db.docs.set(path, opt && opt.merge && cur ? { ...cur, ...clone(data) } : clone(data));
      },
      async delete() {
        db.docs.delete(path);
      },
    };
  }
  collection(path) {
    const db = this;
    const q = { filters: [], order: null, lim: 0 };
    const api = {
      where(f, op, v) {
        q.filters.push([f, op, v]);
        return api;
      },
      orderBy(f, dir = 'asc') {
        q.order = [f, dir];
        return api;
      },
      limit(n) {
        q.lim = n;
        return api;
      },
      doc(id) {
        return db.doc(`${path}/${id}`);
      },
      async add(data) {
        const id = Math.random().toString(36).slice(2, 12);
        await db.doc(`${path}/${id}`).set(data);
        return db.doc(`${path}/${id}`);
      },
      async get() {
        const depth = path.split('/').length + 1;
        let rows = [...db.docs.entries()]
          .filter(([k]) => k.startsWith(path + '/') && k.split('/').length === depth)
          .map(([k, v]) => ({ id: k.split('/').pop(), v }));
        for (const [f, op, val] of q.filters) {
          rows = rows.filter((r) => {
            const x = r.v[f];
            const a = x instanceof Date ? x.getTime() : x;
            const b = val instanceof Date ? val.getTime() : val;
            return op === '==' ? a === b : op === '<=' ? a <= b : op === '>=' ? a >= b : op === '<' ? a < b : a > b;
          });
        }
        if (q.order) {
          const [f, dir] = q.order;
          rows.sort((a, b) => ((a.v[f] > b.v[f]) - (a.v[f] < b.v[f])) * (dir === 'desc' ? -1 : 1));
        }
        if (q.lim) rows = rows.slice(0, q.lim);
        const docs = rows.map((r) => Object.assign(new Snap(r.id, r.v), { ref: db.doc(`${path}/${r.id}`) }));
        return { docs, empty: docs.length === 0, size: docs.length };
      },
    };
    return api;
  }
  async runTransaction(fn) {
    const writes = [];
    const t = {
      get: (ref) => ref.get(),
      set: (ref, data, opt) => writes.push(() => ref.set(data, opt)),
      delete: (ref) => writes.push(() => ref.delete()),
    };
    const r = await fn(t);
    for (const w of writes) await w();
    return r;
  }
}

module.exports = { MemDb };

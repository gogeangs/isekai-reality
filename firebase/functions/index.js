// 아르카 서버 (묶음 56): 파티 · 함께 있어요 · 계정 삭제 · 문의
const { onCall } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');

setGlobalOptions({ region: 'asia-northeast3', maxInstances: 10 });

exports.ping = onCall(() => ({ ok: true, at: Date.now() }));

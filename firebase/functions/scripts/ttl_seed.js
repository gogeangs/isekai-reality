// 묶음 72: 콘솔 「TTL 정책 만들기」는 문서가 이미 있는 컬렉션 그룹만 고를 수 있어,
// 대화 줄(msgs) · 대화 신고(chatReport)에 지난 날짜 expireAt 을 단 자리 문서를 하나씩 둔다.
// TTL 이 켜지면 자리 문서는 저절로 지워진다. (대화방 목록 · 신고 목록엔 나오지 않는 이름 · 상태)
async function main() {
  const admin = require('firebase-admin');
  if (!admin.apps.length) admin.initializeApp({ projectId: process.env.PROJECT_ID || 'arca-d0cab' });
  const db = admin.firestore();
  const past = new Date(Date.UTC(2026, 0, 1));
  await db.doc('chatRooms/_ttl/msgs/_seed').set({ room: '_ttl', kind: 'sys', text: '', at: 0, expireAt: past });
  await db.doc('chatReport/_seed').set({ status: 'seed', at: 0, expireAt: past });
  console.log('TTL 자리 문서 준비 끝');
}

main().catch((e) => {
  console.error('TTL 자리 문서 실패', e && e.code);
  process.exit(1);
});

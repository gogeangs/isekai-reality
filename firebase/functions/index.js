// 아르카 서버 (묶음 56): 파티 · 함께 있어요 · 계정 삭제 · 문의 · 운영자 페이지
// 함수 하나(api)로 받고 길로 나눈다. gcloud 로 배포 (firebase-tools 는 확장 권한이 필요해 안 씀)
const { handle } = require('./src/router');

exports.api = (req, res) => handle(req, res);

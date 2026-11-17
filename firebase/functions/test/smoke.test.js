const test = require('node:test');
const assert = require('node:assert');
test('함수 파일을 읽을 수 있음', () => {
  const f = require('../index.js');
  assert.equal(typeof f.api, 'function');
});

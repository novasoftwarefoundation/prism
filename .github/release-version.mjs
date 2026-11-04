import assert from 'node:assert/strict';

export function releaseVersion(tag) {
  const number = '(?:0|[1-9][0-9]*)';
  assert(new RegExp(`^v${number}\\.${number}\\.${number}(?:-rc\\.${number})?$`).test(tag),
    'Expected vX.Y.Z or vX.Y.Z-rc.N');
  return { version: tag.slice(1), distTag: tag.includes('-') ? 'next' : 'latest' };
}

export function checkVersions(version, design, web, react) {
  assert.equal(design.match(/version:\s*"([^"]+)"/)?.[1], version, 'Design version differs from tag');
  assert.equal(web.version, version, 'Web version differs from tag');
  assert.equal(react.version, version, 'React version differs from tag');
  assert.equal(react.peerDependencies?.[web.name], version, 'React peer version differs from tag');
}

export function checkFiles(expected, actual) {
  assert.deepEqual(actual.toSorted(), expected.trim().split('\n').toSorted(), 'Package file list differs');
}

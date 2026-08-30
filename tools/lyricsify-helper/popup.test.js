const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const audio = {src: 'https://media.example/song.m4a', title: 'Player song', getAttribute: () => ''};
const direct = {
  href: 'https://cdn.example/track.mp3?download=1',
  download: '',
  innerText: '320 Kbps',
  title: ''
};
const indirect = {
  href: 'https://example.test/download?id=7',
  download: '',
  innerText: 'Download page',
  title: ''
};
const metadata = new Map([
  ['og:title', 'Authorized Track'],
  ['author', 'Licensed Artist'],
  ['music:album', 'Licensed Album'],
  ['og:image', 'https://images.example/cover.jpg']
]);

const context = {
  URL,
  console,
  confirm: () => false,
  chrome: {},
  location: {href: 'https://example.test/album', hostname: 'example.test'},
  document: {
    addEventListener: () => {},
    getElementById: () => null,
    title: 'Fallback title',
    querySelectorAll: selector => selector === 'audio[src], audio source[src]' ? [audio] : selector === 'a[href]' ? [direct, indirect] : [],
    querySelector: selector => {
      const match = selector.match(/meta\[(?:property|name)="([^"]+)"\]/);
      return match && metadata.has(match[1]) ? {content: metadata.get(match[1])} : null;
    }
  }
};
vm.createContext(context);
vm.runInContext(fs.readFileSync(__dirname + '/popup.js', 'utf8'), context);

const result = vm.runInContext('extractAuthorizedAudioCandidates()', context);
assert.equal(result.candidates.length, 2);
assert.deepEqual(Array.from(result.candidates, item => item.url), [
  'https://media.example/song.m4a',
  'https://cdn.example/track.mp3?download=1'
]);
assert.equal(result.metadata.title, 'Authorized Track');
assert.equal(result.metadata.artist, 'Licensed Artist');
assert.equal(result.metadata.album, 'Licensed Album');
assert.equal(result.metadata.artwork, 'https://images.example/cover.jpg');
assert.equal(vm.runInContext("hasAudioExtension('https://example.test/a.flac')", context), true);
assert.equal(vm.runInContext("hasAudioExtension('https://example.test/download')", context), false);
assert.equal(vm.runInContext("safeAudioFileName('my:song', 'audio/mpeg')", context), 'my_song.mp3');

console.log('Authorized audio helper tests passed.');

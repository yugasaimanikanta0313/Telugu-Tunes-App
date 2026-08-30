const el = (id) => document.getElementById(id);
let token = '';
let member = null;

document.addEventListener('DOMContentLoaded', async () => {
  const saved = await chrome.storage.local.get(['backend', 'token', 'member', 'email']);
  if (saved.backend) el('backend').value = saved.backend;
  if (saved.email) el('email').value = saved.email;
  token = saved.token || '';
  member = saved.member || null;
  renderAccount();
  el('login').addEventListener('click', login);
  el('logout').addEventListener('click', logout);
  el('extract').addEventListener('click', extract);
  el('search').addEventListener('click', searchTracks);
  el('save').addEventListener('click', saveLyrics);
  el('detectAudio').addEventListener('click', detectAudio);
  el('audioLinks').addEventListener('change', chooseDetectedAudio);
  el('rightsConfirmed').addEventListener('change', updateImportButton);
  el('importAudio').addEventListener('click', importAudio);
});

function api(path) {
  return el('backend').value.trim().replace(/\/$/, '') + path;
}

async function login() {
  setStatus('Signing in…');
  try {
    const response = await fetch(api('/auth/login'), {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({email: el('email').value.trim(), password: el('password').value})
    });
    const data = await json(response);
    token = data.token;
    member = {name: data.displayName || data.memberName || el('email').value.trim(), admin: data.admin === true};
    await chrome.storage.local.set({backend: el('backend').value.trim(), token, member, email: el('email').value.trim()});
    el('password').value = '';
    renderAccount();
    setStatus(member.admin ? 'Administrator account connected.' : 'Signed in, but this account is not an administrator.', !member.admin);
  } catch (error) { setStatus(error.message, true); }
}

async function logout() {
  token = ''; member = null;
  await chrome.storage.local.remove(['token', 'member']);
  renderAccount();
  setStatus('Signed out.');
}

function renderAccount() {
  el('signedOut').hidden = Boolean(token);
  el('signedIn').hidden = !token;
  el('account').textContent = member ? `${member.name}${member.admin ? ' • admin' : ''}` : '';
  updateImportButton();
}

function updateImportButton() {
  el('importAudio').disabled = !token || member?.admin !== true || !el('audioLinks').value || !el('rightsConfirmed').checked;
}

async function detectAudio() {
  setStatus('Scanning the open page for direct audio links…');
  try {
    const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
    if (!tab?.id || !/^https?:/i.test(tab.url || '')) throw new Error('Open an authorized HTTP or HTTPS source page first.');
    const [{result}] = await chrome.scripting.executeScript({target: {tabId: tab.id}, func: extractAuthorizedAudioCandidates});
    const candidates = result?.candidates || [];
    el('audioLinks').replaceChildren(new Option('Choose an authorized audio file', ''));
    for (const candidate of candidates) {
      const option = new Option(candidate.label, candidate.url);
      option.dataset.fileName = candidate.fileName;
      el('audioLinks').append(option);
    }
    const metadata = result?.metadata || {};
    el('audioTitle').value = metadata.title || '';
    el('audioArtist').value = metadata.artist || '';
    el('audioAlbum').value = metadata.album || '';
    el('audioArtwork').value = metadata.artwork || '';
    el('rightsConfirmed').checked = false;
    updateImportButton();
    setStatus(candidates.length
      ? `Found ${candidates.length} direct audio candidate(s). Choose one and review every field.`
      : 'No direct audio link was detected. Protected players and indirect download pages are not supported.', !candidates.length);
  } catch (error) { setStatus(error.message, true); }
}

function chooseDetectedAudio() {
  const option = el('audioLinks').selectedOptions[0];
  if (!el('audioTitle').value && option?.dataset.fileName) {
    el('audioTitle').value = option.dataset.fileName.replace(/\.[^.]+$/, '').replace(/[_-]+/g, ' ').trim();
  }
  el('rightsConfirmed').checked = false;
  updateImportButton();
}

async function importAudio() {
  if (!token || member?.admin !== true) return setStatus('Sign in with an administrator account first.', true);
  const sourceUrl = el('audioLinks').value;
  if (!sourceUrl) return setStatus('Choose a direct audio source.', true);
  if (!el('rightsConfirmed').checked) return setStatus('Confirm your ownership or import permission first.', true);
  const title = el('audioTitle').value.trim();
  if (!title) return setStatus('Review and enter the song title.', true);
  const artist = el('audioArtist').value.trim();
  if (!confirm(`Import “${title}${artist ? ` — ${artist}` : ''}”?\n\nYou are confirming that you have permission to copy this audio.`)) return;

  const originPattern = new URL(sourceUrl).origin + '/*';
  const granted = await chrome.permissions.request({origins: [originPattern]});
  if (!granted) return setStatus('Permission to read the selected audio host was not granted.', true);

  el('importProgress').hidden = false;
  el('importProgress').removeAttribute('value');
  el('importAudio').disabled = true;
  setStatus('Downloading the selected authorized audio…');
  try {
    const response = await fetch(sourceUrl, {credentials: 'omit', redirect: 'follow'});
    if (!response.ok) throw new Error(`Audio download failed (${response.status}).`);
    const contentType = (response.headers.get('content-type') || '').split(';')[0].toLowerCase();
    const length = Number(response.headers.get('content-length') || 0);
    if (length > 50 * 1024 * 1024) throw new Error('The audio exceeds the 50 MB upload limit.');
    if (contentType.startsWith('text/') || contentType.includes('html') || contentType.includes('json')) {
      throw new Error('The selected link returned a web page instead of an audio file, so it was rejected.');
    }
    if (!contentType.startsWith('audio/') && !hasAudioExtension(response.url || sourceUrl)) {
      throw new Error('The selected link returned a web page or non-audio file, so it was rejected.');
    }
    const blob = await response.blob();
    if (!blob.size) throw new Error('The selected audio file is empty.');
    if (blob.size > 50 * 1024 * 1024) throw new Error('The audio exceeds the 50 MB upload limit.');
    if (blob.type && (blob.type.startsWith('text/') || blob.type.includes('html') || blob.type.includes('json'))) {
      throw new Error('The downloaded content is a web document, not audio.');
    }
    if (blob.type && !blob.type.startsWith('audio/') && !hasAudioExtension(response.url || sourceUrl)) {
      throw new Error('The downloaded content is not a supported audio file.');
    }

    const selected = el('audioLinks').selectedOptions[0];
    const pathName = new URL(response.url || sourceUrl).pathname.split('/').pop();
    const fileName = safeAudioFileName(selected?.dataset.fileName || pathName || `${title}.mp3`, contentType);
    const form = new FormData();
    form.append('file', blob, fileName);
    appendField(form, 'title', title);
    appendField(form, 'artist', el('audioArtist').value);
    appendField(form, 'album', el('audioAlbum').value);
    appendField(form, 'singers', el('audioSingers').value);
    appendField(form, 'musicDirector', el('audioDirector').value);
    appendField(form, 'genre', el('audioGenre').value);
    appendField(form, 'artworkUrl', el('audioArtwork').value);
    appendField(form, 'sourceUrl', sourceUrl);
    setStatus(`Uploading reviewed audio (${formatBytes(blob.size)})…`);
    const upload = await fetch(api('/imports/audio'), {method: 'POST', headers: {'Authorization': `Bearer ${token}`}, body: form});
    const data = await json(upload);
    el('importProgress').value = 100;
    setStatus(data.message || `Imported “${title}” successfully.`);
    el('rightsConfirmed').checked = false;
  } catch (error) {
    el('importProgress').hidden = true;
    setStatus(error.message, true);
  } finally { updateImportButton(); }
}

function appendField(form, name, input) {
  const value = typeof input === 'string' ? input.trim() : '';
  if (value) form.append(name, value);
}

function hasAudioExtension(value) {
  try { return /\.(?:mp3|m4a|aac|ogg|oga|wav|flac|opus)$/i.test(new URL(value).pathname); }
  catch (_) { return false; }
}

function safeAudioFileName(value, contentType) {
  let name = decodeURIComponent(value).replace(/[\\/:*?"<>|]/g, '_').trim();
  if (!/\.(?:mp3|m4a|aac|ogg|oga|wav|flac|opus)$/i.test(name)) {
    const extensions = {'audio/mpeg': '.mp3', 'audio/mp4': '.m4a', 'audio/aac': '.aac', 'audio/ogg': '.ogg', 'audio/wav': '.wav', 'audio/flac': '.flac'};
    name += extensions[contentType] || '.mp3';
  }
  return name || 'authorized-audio.mp3';
}

function formatBytes(bytes) {
  return bytes < 1024 * 1024 ? `${(bytes / 1024).toFixed(1)} KB` : `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}

async function extract() {
  setStatus('Reading the open Lyricsify page…');
  try {
    const [tab] = await chrome.tabs.query({active: true, currentWindow: true});
    const [{result}] = await chrome.scripting.executeScript({target: {tabId: tab.id}, func: extractFromLyricsify});
    if (!result || result.error) throw new Error(result?.error || 'No LRC was found on this page.');
    el('lrc').value = result.lrc;
    if (!el('query').value) el('query').value = result.title;
    setStatus(`Extracted ${result.lines} timestamped lines. Review them before saving.`);
    await searchTracks();
  } catch (error) { setStatus(error.message, true); }
}

async function searchTracks() {
  const query = el('query').value.trim();
  if (!query) return setStatus('Enter any song detail to search.', true);
  setStatus('Searching Telugu Tunes…');
  try {
    const words = query.toLowerCase().split(/[^\p{L}\p{N}]+/u)
      .filter(word => word.length >= 2);
    const searches = [...new Set([query, ...words])].slice(0, 8);
    const batches = await Promise.all(searches.map(async term => {
      const response = await fetch(api('/tracks/search?q=' + encodeURIComponent(term)));
      return json(response);
    }));
    const tracksById = new Map();
    for (const batch of batches) {
      for (const track of batch) tracksById.set(track.id, track);
    }
    const tracks = [...tracksById.values()];
    el('tracks').replaceChildren(new Option('Choose the exact destination song', ''));
    for (const track of tracks) {
      const details = [...new Set([
        track.title,
        track.artist,
        track.singers,
        track.album,
        track.musicDirector,
        track.genre,
        track.duration
      ].filter(Boolean))].join(' • ');
      el('tracks').append(new Option(details, track.id));
    }
    setStatus(tracks.length ? `Found ${tracks.length} candidate song(s). Select the exact one.` : 'No Telugu Tunes songs matched.', !tracks.length);
  } catch (error) { setStatus(error.message, true); }
}

async function saveLyrics() {
  const lrc = el('lrc').value.trim();
  const trackId = el('tracks').value;
  if (!token) return setStatus('Sign in with an administrator account first.', true);
  if (!trackId) return setStatus('Select the exact Telugu Tunes destination song.', true);
  if (!validLrc(lrc)) return setStatus('The text must contain at least two timestamped LRC lines.', true);
  if (!confirm(`Save these lyrics to “${el('tracks').selectedOptions[0].text}”?`)) return;
  setStatus('Saving reviewed lyrics…');
  try {
    const response = await fetch(api(`/tracks/${encodeURIComponent(trackId)}/lyrics`), {
      method: 'PUT',
      headers: {'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json'},
      body: JSON.stringify({language: 'te', plainLyrics: plain(lrc), syncedLyrics: lrc})
    });
    const data = await json(response);
    setStatus(`Saved successfully as ${data.source || 'manual'} lyrics.`);
  } catch (error) { setStatus(error.message, true); }
}

async function json(response) {
  const body = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(body.message || `Request failed (${response.status})`);
  return body;
}

function validLrc(value) {
  return (value.match(/^\s*\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\].+$/gm) || []).length >= 2;
}

function plain(value) {
  return value.split(/\r?\n/).map(line => line.replace(/^(?:\s*\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\])+\s*/, ''))
    .filter(line => line.trim() && !/^\[[a-z]+:.*\]$/i.test(line.trim())).join('\n');
}

function setStatus(message, error = false) {
  el('status').textContent = message;
  el('status').classList.toggle('error', error);
}

async function extractFromLyricsify() {
  if (!/(^|\.)lyricsify\.com$/i.test(location.hostname)) return {error: 'Open a Lyricsify song page first.'};
  const timestampPattern = /^\s*\[\d{1,3}:\d{2}(?:[.:]\d{1,3})?\].*$/gm;
  const valid = value => (value.match(timestampPattern) || []).length >= 2;
  const selectors = [
    '#lyrics_display',
    '[id^="lyrics_"]',
    '#entry',
    '.lyrics',
    '.lyrics-content',
    '[class*="lyrics"]',
    'pre.lrc',
    'pre',
    'textarea[name="lrc"]',
    'textarea.lrc',
    '[data-lrc]'
  ];
  for (const selector of selectors) {
    for (const node of document.querySelectorAll(selector)) {
      const value = (node.dataset?.lrc || node.value || node.innerText || node.textContent || '').trim();
      if (valid(value)) return {lrc: value, title: document.title.replace(/\s*[-|].*$/, '').trim(), lines: value.match(/^\s*\[/gm).length};
    }
  }
  // Lyricsify occasionally changes its container names. Select the smallest
  // visible block containing timestamped lines as a resilient fallback.
  const candidates = [...document.querySelectorAll('main, article, section, div')]
    .map(node => (node.innerText || node.textContent || '').trim())
    .filter(valid)
    .sort((left, right) => left.length - right.length);
  if (candidates.length > 0) {
    const value = candidates[0];
    return {lrc: value, title: document.title.replace(/\s*[-|].*$/, '').trim(), lines: (value.match(timestampPattern) || []).length};
  }
  for (const link of document.querySelectorAll('a[href$=".lrc"], a[download], a.raw-lrc, a.download-lrc')) {
    try {
      const response = await fetch(link.href, {credentials: 'include'});
      const value = (await response.text()).trim();
      if (valid(value)) return {lrc: value, title: document.title.replace(/\s*[-|].*$/, '').trim(), lines: value.match(/^\s*\[/gm).length};
    } catch (_) {}
  }
  return {error: 'No valid timestamped LRC was visible or downloadable on this page.'};
}

function extractAuthorizedAudioCandidates() {
  const audioPattern = /\.(?:mp3|m4a|aac|ogg|oga|wav|flac|opus)(?:$|[?#])/i;
  const candidates = new Map();
  const add = (rawUrl, label, downloadName = '') => {
    if (!rawUrl || /^(?:blob|data|javascript):/i.test(rawUrl)) return;
    try {
      const url = new URL(rawUrl, location.href);
      if (!/^https?:$/.test(url.protocol)) return;
      if (!audioPattern.test(url.pathname) && !downloadName) return;
      const fileName = downloadName || decodeURIComponent(url.pathname.split('/').pop() || 'audio');
      candidates.set(url.href, {
        url: url.href,
        fileName,
        label: (label || fileName || url.href).trim().slice(0, 180)
      });
    } catch (_) {}
  };
  for (const node of document.querySelectorAll('audio[src], audio source[src]')) {
    add(node.src, node.title || node.getAttribute('aria-label') || 'Audio player source');
  }
  for (const link of document.querySelectorAll('a[href]')) {
    const downloadName = typeof link.download === 'string' ? link.download.trim() : '';
    if (audioPattern.test(link.href) || downloadName) {
      add(link.href, link.innerText || link.title || downloadName, downloadName);
    }
  }
  const meta = name => document.querySelector(`meta[property="${name}"], meta[name="${name}"]`)?.content?.trim() || '';
  return {
    candidates: [...candidates.values()].slice(0, 50),
    metadata: {
      title: meta('og:title') || document.title.replace(/\s*[-|].*$/, '').trim(),
      artist: meta('music:musician') || meta('author'),
      album: meta('music:album'),
      artwork: meta('og:image')
    }
  };
}

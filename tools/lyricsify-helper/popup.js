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

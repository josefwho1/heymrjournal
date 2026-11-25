// Existing app users (invite links, email sign-in links, or a journal already in this browser) go straight to the app.
(function () {
  var q = location.search, h = location.hash;
  if (/[?&]home\b/.test(q)) return;
  var go = /[?&]invite=/.test(q) || /access_token=|error_description=|type=(recovery|magiclink|signup)/.test(h);
  try { if (!go) for (var i = 0; i < localStorage.length; i++) { var k = localStorage.key(i); if (/^sb-.*-auth-token$/.test(k) || k === 'hmj-draft') { go = true; break; } } } catch (e) {}
  if (go) location.replace('/app' + q + h);
})();

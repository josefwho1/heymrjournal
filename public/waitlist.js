// Waitlist: adds an email to the waitlist table (insert-only; nobody can read the list from the site).
(function () {
  var URL_ = 'https://ltvlhtgqyiscftzcfrvq.supabase.co/rest/v1/waitlist', KEY = 'sb_publishable_PM3Nyt5uA7riCy0xMvMD2A_0iadVeYB';
  var p = new URLSearchParams(location.search), source = (p.get('ref') || p.get('utm_source') || document.referrer.replace(/^https?:\/\/([^/]+).*$/, '$1') || 'direct').slice(0, 60);
  document.querySelectorAll('form.wl').forEach(function (f) {
    var input = f.querySelector('input'), btn = f.querySelector('button'), msg = f.querySelector('.wlmsg');
    f.addEventListener('submit', function (e) {
      e.preventDefault(); var email = input.value.trim().toLowerCase();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { msg.textContent = 'That email doesn’t look right.'; input.focus(); return; }
      btn.disabled = true; msg.textContent = 'Adding you…';
      fetch(URL_, { method: 'POST', headers: { apikey: KEY, authorization: 'Bearer ' + KEY, 'content-type': 'application/json', prefer: 'return=minimal' }, body: JSON.stringify({ email: email, source: source }) })
        .then(function (r) {
          if (r.ok || r.status === 409) { msg.textContent = r.status === 409 ? 'You’re already on the list. We’ll be in touch.' : 'You’re on the list. Clive will be in touch.'; input.value = ''; }
          else throw new Error(r.status);
        })
        .catch(function () { msg.textContent = 'Something went wrong. Try again, or email hello@heymrjournal.com.'; btn.disabled = false; });
    });
  });
})();

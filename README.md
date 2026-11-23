# Mr Journal (pilot)

heymrjournal.com: a 30-day journal with Mr Journal, a mirror that reflects back what you write.

## How privacy works
- **Entries are encrypted in the browser** (AES-256-GCM) before they are saved. Supabase only stores ciphertext.
- **The journal key** is random and created on the user's device. It is stored only *wrapped*: once with a key derived from their password (PBKDF2, 600k rounds) and once with their recovery code.
- **The real password never leaves the browser.** The login server receives a separate value derived from it, so nobody holding the database or the login system can derive the encryption key.
- **Reflections**: the browser sends the entry over HTTPS to `/api/reflect` (a Netlify function). That function checks the user is signed in, adds Mr Journal's persona, calls the Claude API and returns the answer. It stores and logs nothing about the content. Anthropic's commercial terms don't allow training on API data.
- **What the owner can see**: email addresses, the three setup answers, thumbs up/down on questions, and per-question word counts and writing time (tables `profiles`, `votes`, `stats`). Never the words.
- **Trade-off**: lose both password and recovery code, and the journal is unrecoverable. That's by design.

## Setup
1. **Supabase → SQL Editor**: run `supabase/schema.sql`, then `supabase/invites.sql`.
2. **Supabase → Authentication → Sign In / Providers → Email**: turn **Confirm email** off for the pilot (or keep it on and add `{{ .Token }}` to the "Confirm signup" template).
3. **Supabase → Authentication → Emails → Magic Link** template: make sure it contains `{{ .Token }}` (the 6-digit code), e.g. `Your Mr Journal code is {{ .Token }}`.
4. **Supabase → Authentication → URL Configuration**: Site URL `https://heymrjournal.com`.
5. **Netlify**: import this repo. Environment variables:
   - `ANTHROPIC_API_KEY` (required, secret)
   - `ALLOWED_EMAILS`: optional: emails that get reflections without an invite code (e.g. yours)
   - `OWNER_EMAIL`: your email, so Mr Journal uses your personal threads on your account only (optional)
   - `MODEL`: defaults to `claude-sonnet-5-5`
6. **Domain**: add heymrjournal.com in Netlify, then set Namecheap nameservers to the ones Netlify gives you.
7. Before inviting a group: set up custom SMTP in Supabase (e.g. Resend) so login codes aren't rate-limited.

## Data for you
Supabase → Table Editor → `question_report`: answers, average and max words per question.

## Invites
Testers join with an invite code on the sign-up screen, or via a link that fills it in: `https://heymrjournal.com/?invite=MOUSTACHE`.
- New code: Table Editor → `invite_codes` → Insert row (code in CAPITALS, `max_uses`, a note).
- Switch one off: untick `active`.
- Who joined: Table Editor → `member_report`.
Reflections only work for members, so the Claude API can't be used by strangers.

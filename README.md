# Prael landing page

Static site: everything is in `index.html` (fonts and artwork embedded; three.js, GSAP and Lenis load from public CDNs).

## 1. Set up the waitlist (Supabase, about 5 minutes)
1. Create a project at https://supabase.com (free tier is fine).
2. Open **SQL Editor → New query**, paste `supabase/migrations/20260926000000_waitlist.sql`, click **Run**.
   Then do the same with `supabase/migrations/20260927000000_apply_for_access.sql` (names, queue position, referral codes).
   This creates `public.waitlist` with Row Level Security: the public key can only *add* emails, never read them.
3. Open **Project Settings → API** and copy the **Project URL** and the **anon public** key.
4. In `index.html`, search for `YOUR-PROJECT-REF` and replace the two placeholder values:
   ```js
   url: 'https://abcdxyz.supabase.co',
   anonKey: 'eyJhbGciOi...'
   ```
   The anon key is meant to be public. Never paste the `service_role` key into the site.
5. Sign-ups appear in **Table Editor → waitlist**. Export any time as CSV from there.

What the Apply For Access screens do:
- first name, last name and email, with inline errors (e.g. "Invalid email")
- on success: "You're #N On The Queue" and a personal referral code; tapping it copies a link with `?ref=CODE`
- anyone arriving through that link is recorded as referred by that code (see the `waitlist_referrals` view)
- until the keys are added, the screens still work but nothing is saved (preview mode)

Older notes:
- validates the address, lowercases it, and blocks obvious bots with a hidden honeypot field
- shows "Joining…", then "You're on the list" (or "already on the list" for repeats)
- shows a friendly error if the network or Supabase is unavailable

## 2. Deploy to Vercel
- Drag and drop: go to https://vercel.com/new, choose "Deploy" from a folder, and drop this folder.
- CLI: `npm i -g vercel`, then run `vercel` inside this folder (and `vercel --prod` for production).
- GitHub: push this folder to a repo and import it at https://vercel.com/new. No build command; output directory is the repo root.

Note: the claude.ai preview link can't send data to Supabase (its security policy blocks outside requests),
so test the form on your Vercel URL.

# Turning on the shared league (5 minutes, free)

The site works standalone out of the box: predictions are wallet-signed and
stored on each player's own device (they survive reloads), scoring is live
from the Squeekchain API, and the leaderboard shows demo rivals.

To make it a **real shared league** — every player's signed predictions
visible to everyone, one real leaderboard — connect a free Supabase project.
No server to run; the page talks to Supabase's REST API directly.

## Steps

1. Go to [supabase.com](https://supabase.com) and sign in with GitHub.
2. **New project** — any name (e.g. `wheel-predict-league`), free tier,
   pick the nearest region, set any database password.
3. When the project is ready, open **SQL Editor → New query**, paste the
   whole of [`supabase/schema.sql`](supabase/schema.sql) and **Run**.
4. Open **Project Settings → API** and copy two values:
   - **Project URL** (looks like `https://abcdefgh.supabase.co`)
   - **anon / public key** (a long `eyJ…` token — this key is *designed* to
     be public; row-level security in the schema is what protects the table)
5. In `index.html`, find the `LEAGUE` config near the top of the script and
   fill in the two values:
   ```js
   var LEAGUE = { url: 'https://abcdefgh.supabase.co', anonKey: 'eyJ…' };
   ```
6. Commit + push. GitHub Pages redeploys automatically.

## How you know it's on

- The leaderboard note changes to “Shared league connected…”.
- Lock a prediction in one browser, open the site in another — it appears
  in **Locked predictions** and on the leaderboard.
- Predictions received after their round settled never score, and rows
  whose signature doesn't recover to the claimed wallet are shown as
  unverified.

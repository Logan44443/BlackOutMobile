# Blackout Card - Supabase Database Schema (Supabase Auth)

**DATABASE CHANGE (IMPORTANT):** This project uses **Supabase Auth** for passwords (`auth.users`). Your app-visible user data lives in `public.profiles`.

## 🚀 Quick Start - Copy & Paste All SQL

```sql
-- ============================================
-- BLACKOUT CARD - COMPLETE DATABASE SCHEMA
-- Uses Supabase Auth (auth.users) + public.profiles
-- ============================================

-- 0) Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1) PROFILES (links to auth.users)
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  username TEXT NOT NULL UNIQUE,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_profiles_username ON public.profiles(username);

-- Auto-create profile row when a user signs up (expects name/username in raw_user_meta_data)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, name, username, avatar_url)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'name', ''),
    LOWER(COALESCE(NEW.raw_user_meta_data->>'username', '')),
    NEW.raw_user_meta_data->>'avatar_url'
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
AFTER INSERT ON auth.users
FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();

-- 2) CORE TABLES
CREATE TABLE IF NOT EXISTS public.groups (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  created_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  is_private BOOLEAN NOT NULL DEFAULT TRUE,
  cards_per_period INTEGER NOT NULL DEFAULT 1,
  period_type TEXT NOT NULL DEFAULT 'Month' CHECK (period_type IN ('Semester', 'Month', 'Custom')),
  period_start DATE,
  period_end DATE,
  next_reset_at TIMESTAMPTZ,
  vote_threshold TEXT NOT NULL DEFAULT 'Majority' CHECK (vote_threshold IN ('Majority')),
  vote_duration_hours INTEGER NOT NULL DEFAULT 12,
  group_photo_url TEXT,
  group_cover_photo_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.memberships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role TEXT NOT NULL DEFAULT 'Member' CHECK (role IN ('Admin', 'Member')),
  cards_remaining INTEGER NOT NULL DEFAULT 1,
  last_reset_at TIMESTAMPTZ,
  last_petition_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(group_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.nights (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  pulled_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  pulled_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status TEXT NOT NULL DEFAULT 'Active' CHECK (status IN ('Active', 'Closed')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enforce only one active night per group
CREATE UNIQUE INDEX IF NOT EXISTS uniq_active_night_per_group ON public.nights(group_id)
WHERE status = 'Active';

CREATE TABLE IF NOT EXISTS public.media (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  night_id UUID NOT NULL REFERENCES public.nights(id) ON DELETE CASCADE,
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  uploader_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  media_type TEXT NOT NULL CHECK (media_type IN ('Image', 'Video')),
  url TEXT,
  caption TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.vote_cases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  night_id UUID REFERENCES public.nights(id) ON DELETE SET NULL,
  case_type TEXT NOT NULL CHECK (case_type IN ('Failure', 'Petition')),
  target_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  initiated_by_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  opens_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closes_at TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'Open' CHECK (status IN ('Open', 'Resolved')),
  result TEXT CHECK (result IN ('Pass', 'Fail')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vote_case_id UUID NOT NULL REFERENCES public.vote_cases(id) ON DELETE CASCADE,
  voter_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  value TEXT NOT NULL CHECK (value IN ('Yes', 'No')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(vote_case_id, voter_user_id)
);

CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id UUID NOT NULL REFERENCES public.groups(id) ON DELETE CASCADE,
  recipient_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  notification_type TEXT NOT NULL CHECK (notification_type IN (
    'cardPulled', 'voteStarted', 'voteResolved',
    'petitionStarted', 'petitionResolved', 'periodReset'
  )),
  is_read BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Device tokens for push notifications (Lyft-style repeated push until user opens app)
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens(user_id);

-- Friends (future use)
CREATE TABLE IF NOT EXISTS public.friendships (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  addressee_user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(requester_user_id, addressee_user_id),
  CHECK (requester_user_id <> addressee_user_id)
);

-- 3) INDEXES
CREATE INDEX IF NOT EXISTS idx_groups_created_by ON public.groups(created_by_user_id);
CREATE INDEX IF NOT EXISTS idx_memberships_group ON public.memberships(group_id);
CREATE INDEX IF NOT EXISTS idx_memberships_user ON public.memberships(user_id);
CREATE INDEX IF NOT EXISTS idx_memberships_group_user ON public.memberships(group_id, user_id);
CREATE INDEX IF NOT EXISTS idx_nights_group ON public.nights(group_id);
CREATE INDEX IF NOT EXISTS idx_nights_group_status ON public.nights(group_id, status);
CREATE INDEX IF NOT EXISTS idx_media_night ON public.media(night_id);
CREATE INDEX IF NOT EXISTS idx_media_group ON public.media(group_id);
CREATE INDEX IF NOT EXISTS idx_vote_cases_group ON public.vote_cases(group_id);
CREATE INDEX IF NOT EXISTS idx_vote_cases_status ON public.vote_cases(status);
CREATE INDEX IF NOT EXISTS idx_votes_case ON public.votes(vote_case_id);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON public.notifications(recipient_user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_recipient_read ON public.notifications(recipient_user_id, is_read);

-- 4) RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.nights ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.vote_cases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.votes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- Profiles
DROP POLICY IF EXISTS "Read own profile" ON public.profiles;
CREATE POLICY "Read own profile" ON public.profiles
  FOR SELECT USING (auth.uid() = id);

DROP POLICY IF EXISTS "Search profiles" ON public.profiles;
CREATE POLICY "Search profiles" ON public.profiles
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS "Update own profile" ON public.profiles;
CREATE POLICY "Update own profile" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Allow users to insert their own profile (fallback if trigger didn't fire)
DROP POLICY IF EXISTS "Insert own profile" ON public.profiles;
CREATE POLICY "Insert own profile" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Groups
DROP POLICY IF EXISTS "Members can read their groups" ON public.groups;
CREATE POLICY "Members can read their groups" ON public.groups
  FOR SELECT USING (
    created_by_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.memberships
      WHERE public.memberships.group_id = public.groups.id
        AND public.memberships.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Authenticated can create groups" ON public.groups;
CREATE POLICY "Authenticated can create groups" ON public.groups
  FOR INSERT WITH CHECK (auth.role() = 'authenticated' AND created_by_user_id = auth.uid());

DROP POLICY IF EXISTS "Admins can update their groups" ON public.groups;
CREATE POLICY "Admins can update their groups" ON public.groups
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.memberships
      WHERE public.memberships.group_id = public.groups.id
        AND public.memberships.user_id = auth.uid()
        AND public.memberships.role = 'Admin'
    )
  );

-- Helper functions (SECURITY DEFINER bypasses RLS to avoid infinite recursion
-- when memberships policies need to query memberships itself)
CREATE OR REPLACE FUNCTION public.user_group_ids(uid UUID)
RETURNS SETOF UUID AS $$
  SELECT group_id FROM public.memberships WHERE user_id = uid;
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_group_admin(uid UUID, gid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.memberships
    WHERE user_id = uid AND group_id = gid AND role = 'Admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.is_group_member(uid UUID, gid UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.memberships
    WHERE user_id = uid AND group_id = gid
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Memberships
DROP POLICY IF EXISTS "Members can read group memberships" ON public.memberships;
CREATE POLICY "Members can read group memberships" ON public.memberships
  FOR SELECT USING (
    group_id IN (SELECT public.user_group_ids(auth.uid()))
  );

DROP POLICY IF EXISTS "Admins can add members" ON public.memberships;
CREATE POLICY "Admins can add members" ON public.memberships
  FOR INSERT WITH CHECK (
    public.is_group_admin(auth.uid(), group_id)
  );

-- Allows joining via invite link `blackout://invite/<groupId>` (user inserts their own membership)
DROP POLICY IF EXISTS "Users can self-join by invite" ON public.memberships;
CREATE POLICY "Users can self-join by invite" ON public.memberships
  FOR INSERT WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "User can update own membership row" ON public.memberships;
CREATE POLICY "User can update own membership row" ON public.memberships
  FOR UPDATE USING (user_id = auth.uid());

-- Nights
DROP POLICY IF EXISTS "Members can read group nights" ON public.nights;
CREATE POLICY "Members can read group nights" ON public.nights
  FOR SELECT USING (public.is_group_member(auth.uid(), group_id));

DROP POLICY IF EXISTS "Members can create nights" ON public.nights;
CREATE POLICY "Members can create nights" ON public.nights
  FOR INSERT WITH CHECK (public.is_group_member(auth.uid(), group_id));

-- Media
DROP POLICY IF EXISTS "Members can read group media" ON public.media;
CREATE POLICY "Members can read group media" ON public.media
  FOR SELECT USING (public.is_group_member(auth.uid(), group_id));

DROP POLICY IF EXISTS "Members can add media" ON public.media;
CREATE POLICY "Members can add media" ON public.media
  FOR INSERT WITH CHECK (public.is_group_member(auth.uid(), group_id));

-- Vote cases / votes
DROP POLICY IF EXISTS "Members can read group vote cases" ON public.vote_cases;
CREATE POLICY "Members can read group vote cases" ON public.vote_cases
  FOR SELECT USING (public.is_group_member(auth.uid(), group_id));

DROP POLICY IF EXISTS "Members can create vote cases" ON public.vote_cases;
CREATE POLICY "Members can create vote cases" ON public.vote_cases
  FOR INSERT WITH CHECK (public.is_group_member(auth.uid(), group_id));

DROP POLICY IF EXISTS "Members can read group votes" ON public.votes;
CREATE POLICY "Members can read group votes" ON public.votes
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.vote_cases vc
      WHERE vc.id = public.votes.vote_case_id
        AND public.is_group_member(auth.uid(), vc.group_id)
    )
  );

DROP POLICY IF EXISTS "Members can cast vote" ON public.votes;
CREATE POLICY "Members can cast vote" ON public.votes
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.vote_cases vc
      WHERE vc.id = public.votes.vote_case_id
        AND public.is_group_member(auth.uid(), vc.group_id)
    )
  );

-- Nights: members can update (close) nights in their group
DROP POLICY IF EXISTS "Members can update nights" ON public.nights;
CREATE POLICY "Members can update nights" ON public.nights
  FOR UPDATE USING (public.is_group_member(auth.uid(), group_id));

-- Memberships: users can delete their own row (leave group)
DROP POLICY IF EXISTS "User can delete own membership" ON public.memberships;
CREATE POLICY "User can delete own membership" ON public.memberships
  FOR DELETE USING (user_id = auth.uid());

-- Memberships: admins can update any membership in their group (for resetPeriod)
DROP POLICY IF EXISTS "Admins can update group memberships" ON public.memberships;
CREATE POLICY "Admins can update group memberships" ON public.memberships
  FOR UPDATE USING (
    public.is_group_admin(auth.uid(), group_id)
  );

-- Notifications
DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Users can read own notifications" ON public.notifications
  FOR SELECT USING (auth.uid() = recipient_user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications" ON public.notifications
  FOR UPDATE USING (auth.uid() = recipient_user_id);

-- Notifications: members can insert notifications for their groups
DROP POLICY IF EXISTS "Members can insert notifications" ON public.notifications;
CREATE POLICY "Members can insert notifications" ON public.notifications
  FOR INSERT WITH CHECK (public.is_group_member(auth.uid(), group_id));

-- Device tokens: users manage their own tokens (insert/update/delete). Edge Function uses service_role to read all.
DROP POLICY IF EXISTS "Users can manage own device tokens" ON public.device_tokens;
CREATE POLICY "Users can manage own device tokens" ON public.device_tokens
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 5) FUNCTIONS / TRIGGERS
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS update_profiles_updated_at ON public.profiles;
CREATE TRIGGER update_profiles_updated_at BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_groups_updated_at ON public.groups;
CREATE TRIGGER update_groups_updated_at BEFORE UPDATE ON public.groups
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_memberships_updated_at ON public.memberships;
CREATE TRIGGER update_memberships_updated_at BEFORE UPDATE ON public.memberships
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_nights_updated_at ON public.nights;
CREATE TRIGGER update_nights_updated_at BEFORE UPDATE ON public.nights
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

DROP TRIGGER IF EXISTS update_vote_cases_updated_at ON public.vote_cases;
CREATE TRIGGER update_vote_cases_updated_at BEFORE UPDATE ON public.vote_cases
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

-- Vote resolver (call from cron or from the app)
CREATE OR REPLACE FUNCTION public.resolve_expired_vote_cases()
RETURNS void AS $$
BEGIN
  UPDATE public.vote_cases
  SET
    status = 'Resolved',
    result = CASE
      WHEN yes_count > no_count AND (yes_count + no_count) > 0 THEN 'Pass'
      ELSE 'Fail'
    END,
    updated_at = NOW()
  FROM (
    SELECT
      vc.id,
      COUNT(*) FILTER (WHERE v.value = 'Yes') AS yes_count,
      COUNT(*) FILTER (WHERE v.value = 'No') AS no_count
    FROM public.vote_cases vc
    LEFT JOIN public.votes v ON v.vote_case_id = vc.id
    WHERE vc.status = 'Open'
      AND vc.closes_at <= NOW()
    GROUP BY vc.id
  ) counts
  WHERE public.vote_cases.id = counts.id
    AND public.vote_cases.status = 'Open';

  UPDATE public.memberships
  SET cards_remaining = 0
  FROM public.vote_cases vc
  WHERE public.memberships.user_id = vc.target_user_id
    AND public.memberships.group_id = vc.group_id
    AND vc.status = 'Resolved'
    AND vc.result = 'Pass'
    AND vc.case_type = 'Failure';

  UPDATE public.memberships
  SET cards_remaining = 1
  FROM public.vote_cases vc
  WHERE public.memberships.user_id = vc.target_user_id
    AND public.memberships.group_id = vc.group_id
    AND vc.status = 'Resolved'
    AND vc.result = 'Pass'
    AND vc.case_type = 'Petition';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- END OF SCHEMA
-- ============================================
```

## One-time: Backfill missing profiles

If users signed up **before** the `on_auth_user_created` trigger was added (or the trigger failed), they exist in `auth.users` but have no row in `public.profiles`. That causes **"groups violates foreign key constraint groups_created_by_user_id_fkey"** when creating a group.

Run this **once** in the SQL Editor to create profiles for any such users:

```sql
-- Backfill profiles for auth.users that don't have one (run once)
INSERT INTO public.profiles (id, name, username, avatar_url)
SELECT
  u.id,
  COALESCE(NULLIF(TRIM(u.raw_user_meta_data->>'name'), ''), 'User'),
  -- Guarantee unique username: use meta if non-empty, else user_<first8chars of uuid>
  COALESCE(
    NULLIF(LOWER(TRIM(u.raw_user_meta_data->>'username')), ''),
    'user_' || REPLACE(LEFT(u.id::text, 8), '-', '')
  ),
  u.raw_user_meta_data->>'avatar_url'
FROM auth.users u
LEFT JOIN public.profiles p ON p.id = u.id
WHERE p.id IS NULL
ON CONFLICT (id) DO NOTHING;
```

If you get **unique constraint violation on username** (e.g. two backfilled users both got the same fallback), run:  
`UPDATE public.profiles SET username = 'user_' || REPLACE(LEFT(id::text, 8), '-', '') || '_' || (ROW_NUMBER() OVER (ORDER BY id)::text) WHERE username LIKE 'user_%' AND LENGTH(username) <= 12;`  
or fix the duplicate in Table Editor.

## Push notifications (Lyft-style: repeat until user opens app)

Run this in the **SQL Editor** to create the `device_tokens` table (required for push):

```sql
CREATE TABLE IF NOT EXISTS public.device_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  token TEXT NOT NULL,
  platform TEXT NOT NULL DEFAULT 'ios' CHECK (platform IN ('ios', 'android')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, token)
);
CREATE INDEX IF NOT EXISTS idx_device_tokens_user ON public.device_tokens(user_id);
ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can manage own device tokens" ON public.device_tokens;
CREATE POLICY "Users can manage own device tokens" ON public.device_tokens
  FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
```

**Lyft-style repeating push:**  
1. **Deploy the Edge Function** `send-card-pull-push` (in `supabase/functions/send-card-pull-push/`).  
2. **Set secret** `PUSH_WEBHOOK_URL` to your APNs webhook URL. That endpoint receives `POST` with body `{ tokens: string[], title, body }` and must send each token to Apple APNs (use a small Node/Cloudflare Worker with your .p8 key).  
3. **Immediate send:** When a user pulls a card, the app calls the function with `{ groupId, pullerName }`; the function sends one push to all group members.  
4. **Repeating send:** Call the function every 15–30 seconds with `?repeat=1` (e.g. cron-job.org or Supabase cron) so users with unread `cardPulled` notifications get another push until they open the app and mark it read.

**iOS:** Enable Push Notifications in Xcode (Signing & Capabilities). The app registers the device token and saves it to `device_tokens` when signed in.

## Group invites (invite instead of direct add)

To support **inviting** users to a group (they see the invite in Notifications and can Accept or Decline), run this in the **SQL Editor**:

```sql
-- Add inviter column to notifications
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS inviter_user_id UUID REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Allow 'groupInvite' notification type (drop existing check and re-add)
-- If DROP fails, find the check name: SELECT conname FROM pg_constraint WHERE conrelid = 'public.notifications'::regclass AND contype = 'c';
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_notification_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_notification_type_check CHECK (notification_type IN (
    'cardPulled', 'voteStarted', 'voteResolved',
    'petitionStarted', 'petitionResolved', 'periodReset', 'groupInvite'
  ));
```

- **Send invite:** app inserts a notification with `notification_type = 'groupInvite'`, `inviter_user_id = auth.uid()`, `recipient_user_id = invitee`.
- **Accept:** app adds the user to `memberships` and marks the notification read.
- **Decline:** app marks the notification read.

**Allow invitees to read the group (so Accept can fetch `cards_per_period`).** Run after adding `groupInvite`:

```sql
DROP POLICY IF EXISTS "Members can read their groups" ON public.groups;
CREATE POLICY "Members can read their groups" ON public.groups
  FOR SELECT USING (
    created_by_user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.memberships
      WHERE public.memberships.group_id = public.groups.id
        AND public.memberships.user_id = auth.uid()
    )
    OR EXISTS (
      SELECT 1 FROM public.notifications n
      WHERE n.group_id = public.groups.id
        AND n.recipient_user_id = auth.uid()
        AND n.notification_type = 'groupInvite'
        AND n.is_read = FALSE
    )
  );
```

## Fix FKs that reference public.users (legacy)

If your DB was created with FKs pointing at **public.users** instead of **public.profiles**, you’ll see errors like:
- `groups_created_by_user_id_fkey`
- `memberships_user_id_fkey`
- **`nights_pulled_by_user_id_fkey`** (pull card fails)
- **`notifications_recipient_user_id_fkey`** (pull card → "Unable to pull card" when creating notifications)
- and similar on `media`, `vote_cases`, `votes`, `friendships`

**Quick fix for pull-card notification error only** (SQL Editor):

```sql
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_recipient_user_id_fkey;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_recipient_user_id_fkey
  FOREIGN KEY (recipient_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
```

Full fix — run the following in the **SQL Editor** to point all user FKs at **public.profiles** (run only the parts for constraints that exist):

```sql
-- Nights (pull card)
ALTER TABLE public.nights DROP CONSTRAINT IF EXISTS nights_pulled_by_user_id_fkey;
ALTER TABLE public.nights ADD CONSTRAINT nights_pulled_by_user_id_fkey
  FOREIGN KEY (pulled_by_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Media
ALTER TABLE public.media DROP CONSTRAINT IF EXISTS media_uploader_user_id_fkey;
ALTER TABLE public.media ADD CONSTRAINT media_uploader_user_id_fkey
  FOREIGN KEY (uploader_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Vote cases
ALTER TABLE public.vote_cases DROP CONSTRAINT IF EXISTS vote_cases_target_user_id_fkey;
ALTER TABLE public.vote_cases ADD CONSTRAINT vote_cases_target_user_id_fkey
  FOREIGN KEY (target_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.vote_cases DROP CONSTRAINT IF EXISTS vote_cases_initiated_by_user_id_fkey;
ALTER TABLE public.vote_cases ADD CONSTRAINT vote_cases_initiated_by_user_id_fkey
  FOREIGN KEY (initiated_by_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Votes
ALTER TABLE public.votes DROP CONSTRAINT IF EXISTS votes_voter_user_id_fkey;
ALTER TABLE public.votes ADD CONSTRAINT votes_voter_user_id_fkey
  FOREIGN KEY (voter_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Notifications
ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_recipient_user_id_fkey;
ALTER TABLE public.notifications ADD CONSTRAINT notifications_recipient_user_id_fkey
  FOREIGN KEY (recipient_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- Friendships (if you use this table)
ALTER TABLE public.friendships DROP CONSTRAINT IF EXISTS friendships_requester_user_id_fkey;
ALTER TABLE public.friendships ADD CONSTRAINT friendships_requester_user_id_fkey
  FOREIGN KEY (requester_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.friendships DROP CONSTRAINT IF EXISTS friendships_addressee_user_id_fkey;
ALTER TABLE public.friendships ADD CONSTRAINT friendships_addressee_user_id_fkey
  FOREIGN KEY (addressee_user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
```

## Optional migration: group cover photo

If your `groups` table already exists without the cover column, run:

```sql
ALTER TABLE public.groups ADD COLUMN IF NOT EXISTS group_cover_photo_url TEXT;
```

- **group_photo_url** = circular group avatar (main screen list + profile).
- **group_cover_photo_url** = rectangular cover image (top of group home, Facebook-style).

## Setup Notes

- **Storage (required for group + profile photos)**  
  - **"Bucket not found"**: Create the buckets. **Supabase Dashboard** → **Storage** → **New bucket** → create **`avatars`** and **`media`** (lowercase).
  - **Make both buckets public**: Open each bucket → **Configuration** → enable **Public bucket**.
  - **403 "new row violates row-level security policy" (Unauthorized)**: The bucket exists but RLS is blocking uploads. Either use the Dashboard (**Storage** → bucket → **Policies** → New policy → allow **INSERT** and **UPDATE** for `authenticated`), or run this in the **SQL Editor** to allow authenticated uploads to both buckets:

```sql
-- Allow authenticated users to upload to avatars and media buckets
CREATE POLICY "Allow authenticated uploads to avatars"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'avatars');
CREATE POLICY "Allow authenticated updates to avatars"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'avatars');

CREATE POLICY "Allow authenticated uploads to media"
ON storage.objects FOR INSERT TO authenticated
WITH CHECK (bucket_id = 'media');
CREATE POLICY "Allow authenticated updates to media"
ON storage.objects FOR UPDATE TO authenticated
USING (bucket_id = 'media');
```

    If you get "policy already exists", drop them first: `DROP POLICY IF EXISTS "Allow authenticated uploads to avatars" ON storage.objects;` (and same for the other three names) then re-run the CREATEs.

- **Cron** (recommended): schedule `public.resolve_expired_vote_cases()` every minute.


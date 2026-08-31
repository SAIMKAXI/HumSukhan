-- Persist an optional profile photo representation.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS avatar_data TEXT;

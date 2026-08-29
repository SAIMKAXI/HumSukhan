-- ============================================
-- HumSukhan Supabase Schema
-- Run this in the Supabase SQL Editor
-- ============================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- PROFILES
-- ============================================
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT DEFAULT 'User',
  avatar_emoji TEXT DEFAULT '👤',
  preferred_language TEXT DEFAULT 'English',
  tutor_name TEXT DEFAULT 'Sam',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- SETTINGS
-- ============================================
CREATE TABLE IF NOT EXISTS settings (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  settings JSONB DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- FOLDERS
-- ============================================
CREATE TABLE IF NOT EXISTS folders (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- SESSIONS
-- ============================================
CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  type INTEGER DEFAULT 0,
  folder_id UUID REFERENCES folders(id) ON DELETE SET NULL,
  caption_language TEXT DEFAULT 'English',
  retention_days INTEGER DEFAULT 7 CHECK (retention_days >= 1 AND retention_days <= 15),
  created_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ NOT NULL,
  status INTEGER DEFAULT 0,
  transcript_text TEXT
);

-- ============================================
-- CAPTIONS
-- ============================================
CREATE TABLE IF NOT EXISTS captions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  speaker TEXT DEFAULT 'Speaker 1',
  timestamp TIMESTAMPTZ DEFAULT now(),
  language TEXT DEFAULT 'English',
  is_partial BOOLEAN DEFAULT false,
  is_own BOOLEAN DEFAULT false
);

-- ============================================
-- INSIGHTS
-- ============================================
CREATE TABLE IF NOT EXISTS insights (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  session_id UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  summary TEXT DEFAULT '',
  vocabulary JSONB DEFAULT '[]',
  themes JSONB DEFAULT '[]',
  action_items JSONB DEFAULT '[]',
  deadlines JSONB DEFAULT '[]',
  mentioned_people JSONB DEFAULT '[]',
  generated_at TIMESTAMPTZ DEFAULT now(),
  is_available BOOLEAN DEFAULT false
);

-- ============================================
-- QUICK REPLIES
-- ============================================
CREATE TABLE IF NOT EXISTS quick_replies (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  text TEXT NOT NULL,
  category TEXT DEFAULT 'General',
  is_favorite BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- INDEXES
-- ============================================
CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires_at ON sessions(expires_at);
CREATE INDEX IF NOT EXISTS idx_captions_session_id ON captions(session_id);
CREATE INDEX IF NOT EXISTS idx_captions_user_id ON captions(user_id);
CREATE INDEX IF NOT EXISTS idx_insights_session_id ON insights(session_id);
CREATE INDEX IF NOT EXISTS idx_folders_user_id ON folders(user_id);
CREATE INDEX IF NOT EXISTS idx_quick_replies_user_id ON quick_replies(user_id);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE folders ENABLE ROW LEVEL SECURITY;
ALTER TABLE sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE captions ENABLE ROW LEVEL SECURITY;
ALTER TABLE insights ENABLE ROW LEVEL SECURITY;
ALTER TABLE quick_replies ENABLE ROW LEVEL SECURITY;

-- ============================================
-- RLS POLICIES
-- ============================================

-- Profiles: Users can only access their own profile
CREATE POLICY "Users can view own profile"
  ON profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can delete own profile"
  ON profiles FOR DELETE
  USING (auth.uid() = id);

-- Settings: Users can only access their own settings
CREATE POLICY "Users can view own settings"
  ON settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can update own settings"
  ON settings FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own settings"
  ON settings FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own settings"
  ON settings FOR DELETE
  USING (auth.uid() = user_id);

-- Folders: Users can only access their own folders
CREATE POLICY "Users can view own folders"
  ON folders FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own folders"
  ON folders FOR ALL
  USING (auth.uid() = user_id);

-- Sessions: Users can only access their own sessions
CREATE POLICY "Users can view own sessions"
  ON sessions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own sessions"
  ON sessions FOR ALL
  USING (auth.uid() = user_id);

-- Captions: Users can only access their own captions
CREATE POLICY "Users can view own captions"
  ON captions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own captions"
  ON captions FOR ALL
  USING (auth.uid() = user_id);

-- Insights: Users can only access their own insights
CREATE POLICY "Users can view own insights"
  ON insights FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own insights"
  ON insights FOR ALL
  USING (auth.uid() = user_id);

-- Quick Replies: Users can only access their own quick replies
CREATE POLICY "Users can view own quick replies"
  ON quick_replies FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can manage own quick replies"
  ON quick_replies FOR ALL
  USING (auth.uid() = user_id);

-- ============================================
-- AUTO-EXPIRE FUNCTION
-- ============================================

-- Function to automatically clean expired sessions
CREATE OR REPLACE FUNCTION cleanup_expired_sessions()
RETURNS void AS $$
BEGIN
  DELETE FROM sessions WHERE expires_at < now();
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- TRIGGER: Auto-create profile on signup
-- ============================================

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, name)
  VALUES (new.id, COALESCE(new.raw_user_meta_data->>'name', 'User'));
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger the function every time a user is created
CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION handle_new_user();

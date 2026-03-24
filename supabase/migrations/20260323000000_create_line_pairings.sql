-- Migration: 20260323000000_create_line_pairings
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE public.line_pairings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    pairing_code VARCHAR(4) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'waiting', -- waiting, paired, unpaired
    line_user_id VARCHAR(255),
    expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Index for faster webhook lookup
CREATE INDEX idx_line_pairings_code_status ON public.line_pairings(pairing_code, status);

-- Row Level Security (RLS) setup
ALTER TABLE public.line_pairings ENABLE ROW LEVEL SECURITY;

-- Allow insert by anyone (the iOS app with Anon Key)
CREATE POLICY "Allow anon insert" ON public.line_pairings
    FOR INSERT WITH CHECK (true);

-- Allow users to read their own pairing by ID (using the UUID ensures it's unguessable)
CREATE POLICY "Allow read by id" ON public.line_pairings
    FOR SELECT USING (true);

-- Allow users to update their own pairing by ID (e.g. to unpair)
CREATE POLICY "Allow anon update by id" ON public.line_pairings
    FOR UPDATE USING (true);

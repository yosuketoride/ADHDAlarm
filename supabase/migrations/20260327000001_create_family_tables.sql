-- 家族リモートスケジュール設定用テーブル

-- デバイス登録（匿名認証ユーザーとAPNsトークンの紐付け）
CREATE TABLE public.devices (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    device_token TEXT,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    updated_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 家族ペアリング（親と子のデバイスを紐付ける）
CREATE TABLE public.family_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_device_id UUID REFERENCES public.devices(id) NOT NULL,
    child_device_id UUID REFERENCES public.devices(id),
    pairing_code TEXT NOT NULL,
    display_name TEXT,  -- 子が設定する表示名（例:「娘のゆり」）
    status TEXT DEFAULT 'waiting' NOT NULL CHECK (status IN ('waiting', 'paired', 'unpaired')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL
);

CREATE INDEX idx_family_links_code ON public.family_links(pairing_code) WHERE status = 'waiting';

-- リモート予定（子から親への予定送信）
CREATE TABLE public.remote_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_link_id UUID REFERENCES public.family_links(id) NOT NULL,
    creator_device_id UUID REFERENCES public.devices(id) NOT NULL,
    target_device_id UUID REFERENCES public.devices(id) NOT NULL,
    title TEXT NOT NULL,
    fire_date TIMESTAMPTZ NOT NULL,
    pre_notification_minutes INT DEFAULT 15 NOT NULL,
    voice_character TEXT DEFAULT 'femaleConcierge' NOT NULL,
    note TEXT,
    status TEXT DEFAULT 'pending' NOT NULL CHECK (status IN ('pending', 'synced', 'cancelled', 'rolled_back')),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    synced_at TIMESTAMPTZ
);

CREATE INDEX idx_remote_events_target ON public.remote_events(target_device_id, status);
CREATE INDEX idx_remote_events_creator ON public.remote_events(creator_device_id);

-- RLSを有効化
ALTER TABLE public.devices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.family_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.remote_events ENABLE ROW LEVEL SECURITY;

-- devices: 自分のデバイス行のみ操作可能
CREATE POLICY "devices_self_select" ON public.devices
    FOR SELECT USING (id = auth.uid());

CREATE POLICY "devices_self_insert" ON public.devices
    FOR INSERT WITH CHECK (id = auth.uid());

CREATE POLICY "devices_self_update" ON public.devices
    FOR UPDATE USING (id = auth.uid());

-- family_links: 自分が親または子であるリンクのみ操作可能
CREATE POLICY "family_links_participant_select" ON public.family_links
    FOR SELECT USING (
        parent_device_id = auth.uid() OR child_device_id = auth.uid()
    );

CREATE POLICY "family_links_parent_insert" ON public.family_links
    FOR INSERT WITH CHECK (parent_device_id = auth.uid());

CREATE POLICY "family_links_participant_update" ON public.family_links
    FOR UPDATE USING (
        parent_device_id = auth.uid() OR child_device_id = auth.uid()
    );

-- ペアリングコードで参加する子は、自分のchild_device_idを設定できる
-- （status='waiting'の行に対してchild_device_idとstatusを更新する権限）
CREATE POLICY "family_links_child_join" ON public.family_links
    FOR UPDATE USING (
        status = 'waiting' AND expires_at > now() AND child_device_id IS NULL
    )
    WITH CHECK (child_device_id = auth.uid());

-- remote_events: 自分が作成者または受信者の行のみ操作可能
CREATE POLICY "remote_events_creator_insert" ON public.remote_events
    FOR INSERT WITH CHECK (
        creator_device_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.family_links fl
            WHERE fl.id = family_link_id
            AND fl.child_device_id = auth.uid()
            AND fl.status = 'paired'
        )
    );

CREATE POLICY "remote_events_creator_update" ON public.remote_events
    FOR UPDATE USING (creator_device_id = auth.uid());

CREATE POLICY "remote_events_target_select" ON public.remote_events
    FOR SELECT USING (
        creator_device_id = auth.uid() OR target_device_id = auth.uid()
    );

CREATE POLICY "remote_events_target_update" ON public.remote_events
    FOR UPDATE USING (target_device_id = auth.uid());

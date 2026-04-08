-- remote_events.status に家族側反応ステータスを追加
-- completed / skipped / snoozed / missed / expired を許可する

ALTER TABLE public.remote_events
    DROP CONSTRAINT IF EXISTS remote_events_status_check;

ALTER TABLE public.remote_events
    ADD CONSTRAINT remote_events_status_check
    CHECK (
        status IN (
            'pending',
            'synced',
            'completed',
            'skipped',
            'snoozed',
            'missed',
            'expired',
            'cancelled',
            'rolled_back'
        )
    );

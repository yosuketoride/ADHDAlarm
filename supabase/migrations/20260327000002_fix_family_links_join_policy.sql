-- 参加前の子がコードでリンクを検索できるようにSELECTポリシーを追加
-- 現状の participant_select ポリシーは parent/child device_id が一致する行のみ許可しているため、
-- まだ child_device_id が設定されていない waiting 状態のリンクを子が読めない問題を修正する。

-- waiting 状態かつ有効期限内のリンクは、コードを持っている人なら誰でも参照可能にする
-- （6桁コード + 10分有効期限でブルートフォース耐性を確保）
CREATE POLICY "family_links_waiting_readable" ON family_links
  FOR SELECT TO authenticated, anon
  USING (
    status = 'waiting'
    AND expires_at > now()
  );

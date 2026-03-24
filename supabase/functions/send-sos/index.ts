import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const LINE_CHANNEL_ACCESS_TOKEN = Deno.env.get('LINE_CHANNEL_ACCESS_TOKEN') ?? ''

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }

  try {
    const { pairingId, alarmTitle, minutes } = await req.json()

    if (!pairingId) {
      return new Response(JSON.stringify({ error: 'Missing pairingId' }), { status: 400 })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // pairingIdからLINE User IDを検索（セキュリティのため、アプリからはUser IDを直接送らせない）
    const { data, error } = await supabase
      .from('line_pairings')
      .select('line_user_id, status')
      .eq('id', pairingId)
      .limit(1)

    if (error || !data || data.length === 0) {
      return new Response(JSON.stringify({ error: 'Pairing record not found' }), { status: 404 })
    }

    const pairing = data[0]
    if (pairing.status !== 'paired' || !pairing.line_user_id) {
      return new Response(JSON.stringify({ error: 'User is not paired' }), { status: 400 })
    }

    const userId = pairing.line_user_id
    const message = `⚠️ 【SOS】声メモアラームからのお知らせ\n\n「${alarmTitle}」のアラームが${minutes}分間止められていません。\n念のためご確認をお願いいたします。`

    // LINE Push API
    const res = await fetch("https://api.line.me/v2/bot/message/push", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${LINE_CHANNEL_ACCESS_TOKEN}`
      },
      body: JSON.stringify({
        to: userId,
        messages: [{ type: "text", text: message }]
      })
    })

    const result = await res.text()
    return new Response(result, { status: res.status })
  } catch (e) {
    console.error("SOS Function Error:", e)
    return new Response(JSON.stringify({ error: 'Internal Server Error' }), { status: 500 })
  }
})
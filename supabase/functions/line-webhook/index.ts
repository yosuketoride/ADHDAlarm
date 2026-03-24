import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

const LINE_CHANNEL_ACCESS_TOKEN = Deno.env.get('LINE_CHANNEL_ACCESS_TOKEN') ?? ''

serve(async (req) => {
  try {
    const payload = await req.json()
    console.log("Received payload:", JSON.stringify(payload)) // ここに受信内容を表示
    const events = payload.events || []

    for (const event of events) {
      if (event.type === 'message' && event.message.type === 'text') {
        const text = event.message.text.trim()
        const userId = event.source?.userId
        console.log("Received message:", text, "from user:", userId)

        if (/^\d{4}$/.test(text)) {
          const supabase = createClient(
            Deno.env.get('SUPABASE_URL') ?? '',
            Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
          )

          const nowIso = new Date().toISOString()
          const { data, error } = await supabase
            .from('line_pairings')
            .select('*')
            .eq('pairing_code', text)
            .eq('status', 'waiting')
            .gt('expires_at', nowIso)

          console.log("Found pairings:", data, "Error:", error)

          if (data && data.length > 0) {
            const pairingId = data[0].id
            await supabase
              .from('line_pairings')
              .update({ status: 'paired', line_user_id: userId })
              .eq('id', pairingId)

            console.log("Successfully paired!")
            await replyToLine(event.replyToken, '✅ 連携が完了しました！')
          }
        }
      }
    }
    return new Response('OK', { status: 200 })
  } catch (error) {
    console.error("Webhook Error:", error)
    return new Response('Error', { status: 500 })
  }
})

async function replyToLine(replyToken: string, text: string) {
  await fetch('https://api.line.me/v2/bot/message/reply', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${LINE_CHANNEL_ACCESS_TOKEN}`
    },
    body: JSON.stringify({
      replyToken,
      messages: [{ type: 'text', text }]
    })
  })
}

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4"

serve(async (req) => {
  const authHeader = req.headers.get("Authorization")
  if (!authHeader) {
    return new Response("Unauthorized", { status: 401 })
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL") ?? "",
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
  )

  const token = authHeader.replace("Bearer ", "")
  const {
    data: { user },
    error: userError,
  } = await supabase.auth.getUser(token)

  if (userError || !user) {
    return new Response("Unauthorized", { status: 401 })
  }

  const userId = user.id

  // 家族リンクは削除ではなく解除状態にして、相手側の整合性を保つ。
  await supabase
    .from("family_links")
    .update({ status: "unpaired" })
    .or(`parent_device_id.eq.${userId},child_device_id.eq.${userId}`)

  // 送受信どちらに関わる予定も削除する。
  await supabase
    .from("remote_events")
    .delete()
    .or(`creator_device_id.eq.${userId},target_device_id.eq.${userId}`)

  await supabase
    .from("devices")
    .delete()
    .eq("id", userId)

  const { error: deleteError } = await supabase.auth.admin.deleteUser(userId)
  if (deleteError) {
    return new Response("Failed to delete user", { status: 500 })
  }

  return new Response(JSON.stringify({ success: true }), {
    headers: { "Content-Type": "application/json" },
  })
})

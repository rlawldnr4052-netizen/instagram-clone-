import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import admin from "npm:firebase-admin@11.11.0";

const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}');

if (admin.apps.length === 0) {
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
    });
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req) => {
    try {
        const payload = await req.json();
        console.log('[DEBUG] Webhook Payload:', JSON.stringify(payload));

        if (payload.type !== 'INSERT' || payload.table !== 'story_replies') {
            console.log('[DEBUG] Ignored event type:', payload.type);
            return new Response('Ignored', { status: 200 });
        }

        const { story_id, user_id, message } = payload.record;
        console.log(`[DEBUG] Processing Reply: story_id=${story_id}, sender_id=${user_id}`);

        // 2. Get Story Owner
        const { data: story, error: storyError } = await supabase
            .from('stories')
            .select('user_id')
            .eq('id', story_id)
            .single();

        if (storyError || !story) {
            console.error('[ERROR] Story lookup failed:', storyError);
            throw new Error('Story not found');
        }
        console.log(`[DEBUG] Story Owner ID: ${story.user_id}`);

        if (story.user_id === user_id) {
            console.log('[DEBUG] Self-reply detected. (TEST MODE: SENDING ANYWAY)');
            // return new Response('Self-reply', { status: 200 });
        }

        // 3. Get Owner's FCM Token
        const { data: ownerProfile, error: profileError } = await supabase
            .from('profiles')
            .select('fcm_token, username')
            .eq('id', story.user_id)
            .single();

        if (profileError || !ownerProfile) {
            console.error('[ERROR] Owner profile lookup failed:', profileError);
            return new Response('Profile not found', { status: 200 });
        }

        if (!ownerProfile.fcm_token) {
            console.log(`[DEBUG] User ${ownerProfile.username} has NULL fcm_token. Cannot send.`);
            return new Response('No Token', { status: 200 });
        }

        console.log(`[DEBUG] Found FCM Token for ${ownerProfile.username}: ${ownerProfile.fcm_token.substring(0, 10)}...`);

        // 4. Get Sender's Name
        const { data: senderProfile } = await supabase
            .from('profiles')
            .select('username')
            .eq('id', user_id)
            .single();

        const senderName = senderProfile?.username || 'Someone';

        // 5. Send FCM Message
        console.log('[DEBUG] Sending FCM Message...');
        const fcmMessage = {
            token: ownerProfile.fcm_token,
            notification: {
                title: 'New Story Reply',
                body: `${senderName}: ${message}`,
            },
            data: {
                story_id: story_id,
                click_action: 'FLUTTER_NOTIFICATION_CLICK'
            }
        };

        const result = await admin.messaging().send(fcmMessage);
        console.log('[DEBUG] FCM Send Result:', result);

        return new Response(JSON.stringify({ success: true, result }), { headers: { 'Content-Type': 'application/json' } });

    } catch (error) {
        console.error('[ERROR] Exception:', error);
        return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    }
});


import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as admin from "https://esm.sh/firebase-admin@11.11.0/app";
import { getMessaging } from "https://esm.sh/firebase-admin@11.11.0/messaging";

// 1. Initialize Firebase Admin
// You need to set SERVICE_ACCOUNT_JSON env var handling the newline chars properly
const serviceAccount = JSON.parse(Deno.env.get('FIREBASE_SERVICE_ACCOUNT') || '{}');

if (admin.getApps().length === 0) {
    admin.initializeApp({
        credential: admin.cert(serviceAccount),
    });
}

const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const supabase = createClient(supabaseUrl, supabaseKey);

serve(async (req) => {
    try {
        const payload = await req.json();
        console.log('Webhook Payload:', payload);

        // Only listen to INSERT on story_replies
        if (payload.type !== 'INSERT' || payload.table !== 'story_replies') {
            return new Response('Ignored', { status: 200 });
        }

        const { story_id, user_id, message } = payload.record; // user_id is Sender

        // 2. Get Story Owner
        const { data: story, error: storyError } = await supabase
            .from('stories')
            .select('user_id')
            .eq('id', story_id)
            .single();

        if (storyError || !story) throw new Error('Story not found');

        // Don't notify if replying to own story
        if (story.user_id === user_id) return new Response('Self-reply', { status: 200 });

        // 3. Get Owner's FCM Token
        const { data: ownerProfile, error: profileError } = await supabase
            .from('profiles')
            .select('fcm_token, username')
            .eq('id', story.user_id)
            .single();

        if (profileError || !ownerProfile || !ownerProfile.fcm_token) {
            console.log('No FCM token for user');
            return new Response('No Token', { status: 200 });
        }

        // 4. Get Sender's Name
        const { data: senderProfile } = await supabase
            .from('profiles')
            .select('username')
            .eq('id', user_id)
            .single();

        const senderName = senderProfile?.username || 'Someone';

        // 5. Send FCM Message
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

        await getMessaging().send(fcmMessage);

        return new Response(JSON.stringify({ success: true }), { headers: { 'Content-Type': 'application/json' } });

    } catch (error) {
        console.error(error);
        return new Response(JSON.stringify({ error: error.message }), { status: 400 });
    }
});

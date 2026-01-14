
# Script to test FCM Trigger
# Run this in your terminal to bypass the database trigger and test the Edge Function directly.

curl -i --location --request POST 'https://lumsuaiybqvgcwhrszrw.supabase.co/functions/v1/push-notification' \
  --header 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imx1bXN1YWl5YnF2Z2N3aHJzenJ3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5NTg2ODQsImV4cCI6MjA4MzUzNDY4NH0.0zEUuSszizgpEbz_mzUz_HLfaWmCEOZlXz5up2JHlHA' \
  --header 'Content-Type: application/json' \
  --data '{"type":"INSERT","table":"story_replies","record":{"story_id":"INSERT_REAL_STORY_ID","user_id":"INSERT_SENDER_USER_ID","message":"Test via Curl"}}'

# NOTE: You MUST replace INSERT_REAL_STORY_ID and INSERT_SENDER_USER_ID with valid UUIDs from your tables.
# Use Supabase Dashboard table editor to copy an existing story_id and user_id.

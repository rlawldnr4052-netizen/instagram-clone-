-- Check valid FCM tokens
SELECT 
  username, 
  left(fcm_token, 20) as token_fragment, 
  length(fcm_token) as token_length,
  updated_at
FROM profiles
WHERE fcm_token IS NOT NULL;

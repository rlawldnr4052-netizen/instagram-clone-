-- Add FCM Token column to profiles table
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS fcm_token text;

-- Policy: Users can update their own FCM token
create policy "Users can update their own fcm_token"
  on profiles for update
  using ( auth.uid() = id )
  with check ( auth.uid() = id );

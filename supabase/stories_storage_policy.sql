-- Enable RLS for storage.objects (if not already enabled)
-- alter table storage.objects enable row level security; 
-- (Usually enabled by default in Supabase Storage)

-- Policy to allow Public View (Select) of any file in 'stories' bucket
create policy "Give public access to stories"
on storage.objects for select
using ( bucket_id = 'stories' );

-- Policy to allow Authenticated Users to Upload (Insert) to 'stories' bucket
-- Restricting to their own folder: user_id/*
create policy "Allow authenticated uploads to stories"
on storage.objects for insert
with check (
  bucket_id = 'stories' 
  and auth.role() = 'authenticated'
  and (storage.foldername(name))[1] = auth.uid()::text
);

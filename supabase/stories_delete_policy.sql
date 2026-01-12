-- Enable deletion for users' own stories
create policy "Users can delete their own stories"
  on public.stories for delete
  using ( auth.uid() = user_id );

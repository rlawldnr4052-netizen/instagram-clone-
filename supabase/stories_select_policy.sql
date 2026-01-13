-- Enable public read access to stories
create policy "Anyone can view stories"
  on public.stories for select
  using ( true );

create table public.story_replies (
  id uuid default gen_random_uuid() primary key,
  story_id uuid references public.stories(id) on delete cascade not null,
  user_id uuid references public.profiles(id) not null,
  message text not null,
  created_at timestamp with time zone default now() not null
);

-- Enable RLS
alter table public.story_replies enable row level security;

-- Policies
create policy "Anyone can view replies"
  on public.story_replies for select
  using ( true );

create policy "Authenticated users can reply"
  on public.story_replies for insert
  with check ( auth.uid() = user_id );

-- Enable Realtime
alter publication supabase_realtime add table public.story_replies;

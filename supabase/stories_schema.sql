-- Create stories table
create table public.stories (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references public.profiles(id) not null,
  image_url text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Enable RLS
alter table public.stories enable row level security;

-- Policies
create policy "Public stories are viewable by everyone"
  on public.stories for select
  using ( true );

create policy "Users can insert their own stories"
  on public.stories for insert
  with check ( auth.uid() = user_id );

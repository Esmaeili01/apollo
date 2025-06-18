create table public.profiles (
  id uuid not null,
  username text null,
  name text not null,
  avatar_url text null,
  status text null,
  is_online boolean null default false,
  birthday date null,
  bio text null,
  constraint profiles_pkey primary key (id),
  constraint profiles_username_key unique (username),
  constraint profiles_id_fkey foreign KEY (id) references auth.users (id) on delete CASCADE,
  constraint profiles_bio_check check ((length(bio) <= 100))
) TABLESPACE pg_default;

create table public.groups (
  id uuid not null default gen_random_uuid (),
  name text not null,
  bio text null,
  avatar_url text null,
  creator_id uuid null,
  can_send_message boolean null default true,
  can_send_media boolean null default true,
  can_add_members boolean null default true,
  can_pin_message boolean null default true,
  can_change_info boolean null default true,
  can_delete_message boolean null default false,
  is_public boolean null default false,
  created_at timestamp with time zone null default timezone ('utc'::text, now()),
  invite_link text not null,
  constraint groups_pkey primary key (id),
  constraint groups_invite_link_key unique (invite_link),
  constraint groups_creator_id_fkey foreign KEY (creator_id) references profiles (id)
) TABLESPACE pg_default;

create table public.messages (
  id uuid not null default gen_random_uuid (),
  sender_id uuid null,
  receiver_id uuid null,
  group_id uuid null,
  reply_to_id uuid null,
  content text null,
  type text null,
  is_multimedia boolean null default false,
  media_url text[] null,
  created_at timestamp with time zone null default timezone ('utc'::text, now()),
  is_read boolean null default false,
  constraint messages_pkey primary key (id),
  constraint messages_group_id_fkey foreign KEY (group_id) references groups (id),
  constraint messages_receiver_id_fkey foreign KEY (receiver_id) references profiles (id),
  constraint messages_sender_id_fkey foreign KEY (sender_id) references profiles (id),
  constraint messages_reply_to_id_fkey foreign KEY (reply_to_id) references messages (id)

) TABLESPACE pg_default;

create table public.group_members (
  group_id uuid not null,
  user_id uuid not null,
  joined_at timestamp with time zone null default timezone ('utc'::text, now()),
  constraint group_members_pkey primary key (group_id, user_id),
  constraint group_members_group_id_fkey foreign KEY (group_id) references groups (id) on delete CASCADE,
  constraint group_members_user_id_fkey foreign KEY (user_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;

create table public.blocked_users (
  blocker_id uuid not null,
  blocked_id uuid not null,
  created_at timestamp with time zone null default timezone ('utc'::text, now()),
  constraint blocked_users_pkey primary key (blocker_id, blocked_id),
  constraint blocked_users_blocked_id_fkey foreign KEY (blocked_id) references profiles (id) on delete CASCADE,
  constraint blocked_users_blocker_id_fkey foreign KEY (blocker_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;

create table public.login_logs (
  id uuid not null default gen_random_uuid (),
  user_id uuid null,
  login_time timestamp with time zone null default timezone ('utc'::text, now()),
  ip_address text null,
  device_info text null,
  success boolean null default true,
  constraint login_logs_pkey primary key (id),
  constraint login_logs_user_id_fkey foreign KEY (user_id) references profiles (id) on delete CASCADE
) TABLESPACE pg_default;
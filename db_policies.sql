ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.groups ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocked_users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.login_logs ENABLE ROW LEVEL SECURITY;

-- Allow users to view all profiles
CREATE POLICY "Allow read profiles" ON public.profiles
FOR SELECT
USING (true);

-- Allow users to insert their own profile
CREATE POLICY "Allow insert own profile" ON public.profiles
FOR INSERT
WITH CHECK (auth.uid() = id);

-- Allow users to update their own profile
CREATE POLICY "Allow update own profile" ON public.profiles
FOR UPDATE
USING (auth.uid() = id);

-- Allow users to delete their own profile
CREATE POLICY "Allow delete own profile" ON public.profiles
FOR DELETE
USING (auth.uid() = id);


-- Allow users to view all groups
CREATE POLICY "Allow read groups" ON public.groups
FOR SELECT
USING (true);

-- Allow users to create groups (must be the creator)
CREATE POLICY "Allow insert group" ON public.groups
FOR INSERT
WITH CHECK (auth.uid() = creator_id);

-- Allow group creator to update group info
CREATE POLICY "Allow update group by creator" ON public.groups
FOR UPDATE
USING (auth.uid() = creator_id);

-- Allow group creator to delete group
CREATE POLICY "Allow delete group by creator" ON public.groups
FOR DELETE
USING (auth.uid() = creator_id);

-- Allow users to read messages where they are sender, receiver, or group member
CREATE POLICY "Allow read messages" ON public.messages
FOR SELECT
USING (
  sender_id = auth.uid()
  OR receiver_id = auth.uid()
  OR group_id IN (
    SELECT group_id FROM public.group_members WHERE user_id = auth.uid()
  )
);

-- Allow users to send messages as themselves
CREATE POLICY "Allow insert own messages" ON public.messages
FOR INSERT
WITH CHECK (
  sender_id = auth.uid()
);

-- Allow users to update their own messages (e.g., for delete/edit)
CREATE POLICY "Allow update own messages" ON public.messages
FOR UPDATE
USING (sender_id = auth.uid());

-- Allow receivers to update message status (is_seen, is_delivered)
CREATE POLICY "Allow update message status by receiver" ON public.messages
FOR UPDATE
USING (receiver_id = auth.uid());

-- Allow users to delete their own messages
CREATE POLICY "Allow delete own messages" ON public.messages
FOR DELETE
USING (sender_id = auth.uid());


-- Allow users to view group memberships they are part of
CREATE POLICY "Allow read own group memberships" ON public.group_members
FOR SELECT
USING (user_id = auth.uid());

-- Allow users to join a group (insert themselves)
CREATE POLICY "Allow insert self to group" ON public.group_members
FOR INSERT
WITH CHECK (user_id = auth.uid());

-- Allow users to leave a group (delete themselves)
CREATE POLICY "Allow delete self from group" ON public.group_members
FOR DELETE
USING (user_id = auth.uid());


-- Allow users to view who they have blocked or who has blocked them
CREATE POLICY "Allow read own blocked users" ON public.blocked_users
FOR SELECT
USING (blocker_id = auth.uid() OR blocked_id = auth.uid());

-- Allow users to block others
CREATE POLICY "Allow insert block" ON public.blocked_users
FOR INSERT
WITH CHECK (blocker_id = auth.uid());

-- Allow users to unblock (delete) others
CREATE POLICY "Allow delete block" ON public.blocked_users
FOR DELETE
USING (blocker_id = auth.uid());


-- Allow users to view their own login logs
CREATE POLICY "Allow read own login logs" ON public.login_logs
FOR SELECT
USING (user_id = auth.uid());

-- Allow users to insert their own login log
CREATE POLICY "Allow insert own login log" ON public.login_logs
FOR INSERT
WITH CHECK (user_id = auth.uid());
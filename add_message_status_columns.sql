-- Add is_delivered and is_seen columns to messages table
-- This replaces the existing is_read column with more granular status tracking

ALTER TABLE public.messages 
DROP COLUMN IF EXISTS is_read;

ALTER TABLE public.messages 
ADD COLUMN is_delivered boolean DEFAULT false,
ADD COLUMN is_seen boolean DEFAULT false,
ADD COLUMN last_seen timestamp with time zone;

-- Add missing last_seen column to profiles table if it doesn't exist
ALTER TABLE public.profiles 
ADD COLUMN IF NOT EXISTS last_seen timestamp with time zone;

-- Update existing messages to have is_delivered = true (assuming they were delivered)
UPDATE public.messages 
SET is_delivered = true 
WHERE is_delivered IS NULL;

-- Add index for better performance on status queries
CREATE INDEX IF NOT EXISTS idx_messages_status ON public.messages(is_delivered, is_seen);
CREATE INDEX IF NOT EXISTS idx_messages_receiver_unread ON public.messages(receiver_id, is_seen) WHERE is_seen = false;

-- Create a secure function for updating message status
CREATE OR REPLACE FUNCTION mark_message_as_seen(message_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.messages 
  SET 
    is_seen = true,
    last_seen = timezone('utc'::text, now())
  WHERE 
    id = message_id 
    AND receiver_id = auth.uid()
    AND is_seen = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function for marking multiple messages as seen
CREATE OR REPLACE FUNCTION mark_messages_as_seen_by_sender(sender_user_id uuid)
RETURNS void AS $$
BEGIN
  UPDATE public.messages 
  SET 
    is_seen = true,
    last_seen = timezone('utc'::text, now())
  WHERE 
    sender_id = sender_user_id 
    AND receiver_id = auth.uid()
    AND is_seen = false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions to authenticated users
GRANT EXECUTE ON FUNCTION mark_message_as_seen(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION mark_messages_as_seen_by_sender(uuid) TO authenticated;

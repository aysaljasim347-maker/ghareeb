-- 011: InKind progressive flow — inkind-based chat rooms, photo_url fix

-- Allow chat_rooms to exist without a task (for inkind donor-beneficiary chat)
ALTER TABLE chat_rooms ALTER COLUMN task_id DROP NOT NULL;

-- Link chat rooms to inkind requests
ALTER TABLE chat_rooms
  ADD COLUMN inkind_request_id INT REFERENCES inkind_requests(id) ON DELETE CASCADE;

-- Ensure every room has exactly one context (task OR inkind request)
ALTER TABLE chat_rooms
  ADD CONSTRAINT chat_rooms_one_context CHECK (
    (task_id IS NOT NULL AND inkind_request_id IS NULL) OR
    (task_id IS NULL    AND inkind_request_id IS NOT NULL)
  );

-- Back-reference from request to its chat room for fast lookup
ALTER TABLE inkind_requests
  ADD COLUMN chat_room_id INT REFERENCES chat_rooms(id);

-- Fix column name: storage_key → photo_url (column already correct in DB; this is a no-op if already named photo_url)
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'inkind_donations' AND column_name = 'storage_key'
  ) THEN
    ALTER TABLE inkind_donations RENAME COLUMN storage_key TO photo_url;
  END IF;
END $$;

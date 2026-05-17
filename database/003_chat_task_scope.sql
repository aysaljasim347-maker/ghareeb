-- Phase 4: Enforce one chat room per task via unique index.
-- Deduplicates any orphan duplicates first (keeps the lowest id).
DELETE FROM chat_messages
  WHERE room_id IN (
    SELECT id FROM chat_rooms
    WHERE id NOT IN (
      SELECT MIN(id) FROM chat_rooms GROUP BY task_id
    )
  );

DELETE FROM chat_rooms
  WHERE id NOT IN (
    SELECT MIN(id) FROM chat_rooms GROUP BY task_id
  );

CREATE UNIQUE INDEX IF NOT EXISTS uq_chat_rooms_task_id ON chat_rooms(task_id);

/**
 * Chat Mapper
 */
export const mapChatRoom = (raw: any) => {
  return {
    id: Number(raw.id),
    task_id: Number(raw.task_id),
    task_title: raw.task_title || null,
    task_status: raw.task_status || null,
    creator_name: raw.creator_name || null,
    claimer_name: raw.claimer_name || null,
    coordinator_name: raw.coordinator_name || null,
    message_count: Number(raw.message_count || 0),
    created_at: raw.created_at ? new Date(raw.created_at).toISOString() : null,
  };
};

export const mapChatMessage = (raw: any) => {
  return {
    id: Number(raw.id),
    room_id: Number(raw.room_id),
    sender_id: Number(raw.sender_id),
    sender_name: raw.sender_name || '',
    text: raw.text || '',
    created_at: raw.created_at ? new Date(raw.created_at).toISOString() : null,
  };
};

export const mapChatRoomList = (rawList: any[]) => {
  return {
    data: rawList.map(mapChatRoom),
    meta: { total: rawList.length }
  };
};

export const mapChatMessageList = (rawList: any[]) => {
  return {
    data: rawList.map(mapChatMessage),
    meta: { total: rawList.length }
  };
};

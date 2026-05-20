import { Router } from 'express';
import { chatController } from './chat.controller.js';
import { authenticate } from '../../middleware/auth.js';

const router = Router();

/**
 * POST /api/chat/rooms
 * Create a chat room for a task.
 */
router.post(
  '/rooms',
  authenticate,
  (req, res, next) => chatController.createRoom(req, res, next)
);

/**
 * GET /api/chat/rooms
 * Get user's chat rooms.
 */
router.get(
  '/rooms',
  authenticate,
  (req, res, next) => chatController.getMyRooms(req, res, next)
);

/**
 * GET /api/chat/rooms/task/:taskId
 * Get chat room for a specific task.
 */
router.get(
  '/rooms/task/:taskId',
  authenticate,
  (req, res, next) => chatController.getRoomByTaskId(req, res, next)
);

/**
 * GET /api/chat/rooms/inkind/:requestId
 * Get or create a chat room for an inkind request (donor ↔ beneficiary).
 */
router.get(
  '/rooms/inkind/:requestId',
  authenticate,
  (req, res, next) => chatController.getInKindRoom(req, res, next)
);

/**
 * POST /api/chat/rooms/:roomId/messages
 * Send a message.
 */
router.post(
  '/rooms/:roomId/messages',
  authenticate,
  (req, res, next) => chatController.sendMessage(req, res, next)
);

/**
 * GET /api/chat/rooms/:roomId/messages
 * Get messages in a room.
 */
router.get(
  '/rooms/:roomId/messages',
  authenticate,
  (req, res, next) => chatController.getMessages(req, res, next)
);

export default router;

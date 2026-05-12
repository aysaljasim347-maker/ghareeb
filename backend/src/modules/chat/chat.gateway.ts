import { Server as SocketIOServer, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env.js';
import { chatService } from './chat.service.js';

interface AuthenticatedSocket extends Socket {
  userId?: number;
}

/**
 * Socket.IO gateway for real-time chat messaging.
 */
export function initializeChatGateway(io: SocketIOServer): void {
  // Authentication middleware for Socket.IO
  io.use((socket: AuthenticatedSocket, next) => {
    const token = socket.handshake.auth.token || socket.handshake.query.token;
    if (!token || typeof token !== 'string') {
      return next(new Error('Authentication required'));
    }

    try {
      const decoded = jwt.verify(token, env.JWT_SECRET) as { userId: number };
      socket.userId = decoded.userId;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket: AuthenticatedSocket) => {
    console.log(`Socket connected: user ${socket.userId}`);

    // Join a chat room
    socket.on('join_room', (roomId: number) => {
      socket.join(`room:${roomId}`);
      console.log(`User ${socket.userId} joined room ${roomId}`);
    });

    // Leave a chat room
    socket.on('leave_room', (roomId: number) => {
      socket.leave(`room:${roomId}`);
    });

    // Send a message
    socket.on('send_message', async (data: { roomId: number; text: string }) => {
      if (!socket.userId) return;

      try {
        const message = await chatService.sendMessage(
          data.roomId,
          socket.userId,
          data.text
        );

        // Broadcast to all users in the room
        io.to(`room:${data.roomId}`).emit('new_message', message);
      } catch (err) {
        socket.emit('error', { message: 'Failed to send message' });
      }
    });

    // Typing indicator
    socket.on('typing', (data: { roomId: number; isTyping: boolean }) => {
      socket.to(`room:${data.roomId}`).emit('user_typing', {
        userId: socket.userId,
        isTyping: data.isTyping,
      });
    });

    socket.on('disconnect', () => {
      console.log(`Socket disconnected: user ${socket.userId}`);
    });
  });
}

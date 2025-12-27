// Notification API routes for Claude Code hooks
import { Router } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { wsManager } from '../services/ws.js';

const router = Router();

// Notification types
export type NotificationType = 'task_complete' | 'task_error' | 'permission_required' | 'session_idle' | 'custom';
export type NotificationPriority = 'low' | 'normal' | 'high' | 'urgent';

interface NotificationRequest {
  type: string;
  message: string;
  session_id?: string;
  priority?: NotificationPriority;
  details?: Record<string, unknown>;
  sound?: boolean;
}

// POST /api/notifications - Receive notification from Claude Code hooks
router.post('/', async (req, res) => {
  const notification: NotificationRequest = req.body;

  console.log(
    `Received notification: type=${notification.type}, ` +
    `message=${notification.message}, priority=${notification.priority || 'normal'}`
  );

  const notificationId = `notif_${uuidv4().replace(/-/g, '').slice(0, 12)}`;
  const timestamp = new Date().toISOString();

  // Build WebSocket message
  const wsMessage = {
    type: 'notification',
    data: {
      notificationId,
      notificationType: notification.type,
      message: notification.message,
      sessionId: notification.session_id,
      priority: notification.priority || 'normal',
      details: notification.details,
      sound: notification.sound !== false,
      timestamp,
    },
  };

  // Broadcast to all connected clients
  await wsManager.broadcastAll(wsMessage);

  console.log(`Notification sent: id=${notificationId}, type=${notification.type}`);

  res.json({
    success: true,
    notification_id: notificationId,
    timestamp,
  });
});

// GET /api/notifications/types - List notification types
router.get('/types', (req, res) => {
  res.json({
    types: ['task_complete', 'task_error', 'permission_required', 'session_idle', 'custom'],
    priorities: ['low', 'normal', 'high', 'urgent'],
  });
});

export default router;

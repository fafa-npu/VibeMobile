/**
 * Browser Notification Service
 *
 * This module provides a unified interface for browser notifications,
 * handling permission requests, notification display, and sound alerts.
 *
 * Features:
 * - System push notifications (Web Notifications API)
 * - Sound alerts for urgent notifications
 * - Permission management
 * - Notification history tracking
 * - Customizable notification options
 *
 * Usage:
 *   import { notificationService } from './notification';
 *
 *   // Initialize (request permission)
 *   await notificationService.initialize();
 *
 *   // Show notification
 *   notificationService.show({
 *     title: 'Task Complete',
 *     body: 'Claude has finished the task',
 *     priority: 'high'
 *   });
 */

/**
 * Notification priority levels
 */
export type NotificationPriority = 'low' | 'normal' | 'high' | 'urgent';

/**
 * Notification types matching server-side types
 */
export type NotificationType =
  | 'task_complete'
  | 'task_error'
  | 'permission_required'
  | 'session_idle'
  | 'custom';

/**
 * Options for showing a notification
 */
export interface NotificationOptions {
  title: string;
  body: string;
  type?: NotificationType;
  priority?: NotificationPriority;
  icon?: string;
  tag?: string;
  sound?: boolean;
  onClick?: () => void;
  data?: Record<string, unknown>;
}

/**
 * Notification history entry
 */
export interface NotificationHistoryEntry {
  id: string;
  title: string;
  body: string;
  type: NotificationType;
  priority: NotificationPriority;
  timestamp: Date;
  read: boolean;
}

/**
 * Notification permission status
 */
export type PermissionStatus = 'granted' | 'denied' | 'default' | 'unsupported';

/**
 * Browser Notification Service
 *
 * Singleton service for managing browser notifications.
 */
class NotificationService {
  private _permission: PermissionStatus = 'default';
  private _history: NotificationHistoryEntry[] = [];
  private _maxHistorySize = 100;
  private _soundEnabled = true;
  private _notificationSound: HTMLAudioElement | null = null;

  /**
   * Default notification icon (can be overridden)
   */
  private _defaultIcon = '/icon-192.png';

  /**
   * Sound URL for notification alerts
   */
  private _soundUrl = '/notification.mp3';

  /**
   * Check if the browser supports notifications
   */
  get isSupported(): boolean {
    return 'Notification' in window;
  }

  /**
   * Get current permission status
   */
  get permission(): PermissionStatus {
    if (!this.isSupported) return 'unsupported';
    return Notification.permission as PermissionStatus;
  }

  /**
   * Get notification history
   */
  get history(): ReadonlyArray<NotificationHistoryEntry> {
    return [...this._history];
  }

  /**
   * Get unread notification count
   */
  get unreadCount(): number {
    return this._history.filter((n) => !n.read).length;
  }

  /**
   * Initialize the notification service
   *
   * Requests permission from the user if not already granted.
   * Should be called early in the app lifecycle.
   *
   * @returns The permission status after initialization
   */
  async initialize(): Promise<PermissionStatus> {
    if (!this.isSupported) {
      console.warn('[NotificationService] Notifications not supported');
      return 'unsupported';
    }

    // Check current permission
    this._permission = Notification.permission as PermissionStatus;

    // If permission hasn't been requested yet, request it
    if (this._permission === 'default') {
      try {
        const result = await Notification.requestPermission();
        this._permission = result as PermissionStatus;
        console.log('[NotificationService] Permission result:', result);
      } catch (error) {
        console.error('[NotificationService] Permission request failed:', error);
      }
    }

    // Preload notification sound
    this._preloadSound();

    return this._permission;
  }

  /**
   * Request notification permission
   *
   * Use this when the user explicitly wants to enable notifications.
   *
   * @returns The new permission status
   */
  async requestPermission(): Promise<PermissionStatus> {
    if (!this.isSupported) return 'unsupported';

    try {
      const result = await Notification.requestPermission();
      this._permission = result as PermissionStatus;
      return this._permission;
    } catch (error) {
      console.error('[NotificationService] Permission request failed:', error);
      return this._permission;
    }
  }

  /**
   * Show a notification
   *
   * @param options Notification options
   * @returns The notification instance, or null if permission denied
   */
  show(options: NotificationOptions): Notification | null {
    if (!this.isSupported || this.permission !== 'granted') {
      console.warn('[NotificationService] Cannot show notification:', this.permission);
      return null;
    }

    const {
      title,
      body,
      type = 'custom',
      priority = 'normal',
      icon = this._defaultIcon,
      tag,
      sound = true,
      onClick,
      data,
    } = options;

    // Create browser notification
    const notification = new Notification(title, {
      body,
      icon,
      tag: tag || `vibe-${Date.now()}`,
      data,
      // Use require interaction for high priority notifications
      requireInteraction: priority === 'high' || priority === 'urgent',
    });

    // Handle click
    notification.onclick = () => {
      window.focus();
      notification.close();
      onClick?.();
    };

    // Play sound for high priority or if explicitly requested
    if (sound && this._soundEnabled && (priority === 'high' || priority === 'urgent')) {
      this._playSound();
    }

    // Add to history
    this._addToHistory({
      title,
      body,
      type,
      priority,
    });

    return notification;
  }

  /**
   * Show a task completion notification
   *
   * Convenience method for the most common notification type.
   *
   * @param message The notification message
   * @param options Additional options
   */
  showTaskComplete(
    message: string,
    options?: Partial<Omit<NotificationOptions, 'title' | 'body' | 'type'>>
  ): Notification | null {
    return this.show({
      title: '✅ Claude 任务完成',
      body: message,
      type: 'task_complete',
      priority: 'high',
      sound: true,
      ...options,
    });
  }

  /**
   * Show a task error notification
   *
   * @param message The error message
   * @param options Additional options
   */
  showTaskError(
    message: string,
    options?: Partial<Omit<NotificationOptions, 'title' | 'body' | 'type'>>
  ): Notification | null {
    return this.show({
      title: '❌ Claude 任务出错',
      body: message,
      type: 'task_error',
      priority: 'urgent',
      sound: true,
      ...options,
    });
  }

  /**
   * Show a permission required notification
   *
   * @param message The message describing what permission is needed
   * @param options Additional options
   */
  showPermissionRequired(
    message: string,
    options?: Partial<Omit<NotificationOptions, 'title' | 'body' | 'type'>>
  ): Notification | null {
    return this.show({
      title: '🔐 Claude 需要权限',
      body: message,
      type: 'permission_required',
      priority: 'urgent',
      sound: true,
      ...options,
    });
  }

  /**
   * Enable or disable notification sounds
   */
  setSoundEnabled(enabled: boolean): void {
    this._soundEnabled = enabled;
  }

  /**
   * Mark a notification as read
   */
  markAsRead(id: string): void {
    const notification = this._history.find((n) => n.id === id);
    if (notification) {
      notification.read = true;
    }
  }

  /**
   * Mark all notifications as read
   */
  markAllAsRead(): void {
    this._history.forEach((n) => (n.read = true));
  }

  /**
   * Clear notification history
   */
  clearHistory(): void {
    this._history = [];
  }

  /**
   * Preload the notification sound
   */
  private _preloadSound(): void {
    try {
      this._notificationSound = new Audio(this._soundUrl);
      this._notificationSound.preload = 'auto';
    } catch (error) {
      console.warn('[NotificationService] Could not preload sound:', error);
    }
  }

  /**
   * Play the notification sound
   */
  private _playSound(): void {
    if (this._notificationSound) {
      // Reset and play
      this._notificationSound.currentTime = 0;
      this._notificationSound.play().catch((error) => {
        console.warn('[NotificationService] Could not play sound:', error);
      });
    }
  }

  /**
   * Add an entry to notification history
   */
  private _addToHistory(
    entry: Omit<NotificationHistoryEntry, 'id' | 'timestamp' | 'read'>
  ): void {
    const historyEntry: NotificationHistoryEntry = {
      ...entry,
      id: `notif_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      timestamp: new Date(),
      read: false,
    };

    this._history.unshift(historyEntry);

    // Trim history if it exceeds max size
    if (this._history.length > this._maxHistorySize) {
      this._history = this._history.slice(0, this._maxHistorySize);
    }
  }
}

// Export singleton instance
export const notificationService = new NotificationService();

// Export class for testing or custom instances
export { NotificationService };

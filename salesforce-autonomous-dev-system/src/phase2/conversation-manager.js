// src/phase2/conversation-manager.js
// Manages conversation sessions and history for natural language interactions

import Database from 'better-sqlite3';
import pkg from 'uuid';
const { v4: uuidv4 } = pkg;

export class ConversationManager {
  constructor(dbPath = process.env.DB_PATH) {
    this.db = new Database(dbPath);
    this.initSchema();
    this.sessions = new Map(); // In-memory session cache
    this.SESSION_TIMEOUT = 30 * 60 * 1000; // 30 minutes
    this.startCleanupTimer();
  }

  initSchema() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
        metadata TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_conversations_session ON conversations(session_id);
      CREATE INDEX IF NOT EXISTS idx_conversations_user ON conversations(user_id);
      CREATE INDEX IF NOT EXISTS idx_conversations_timestamp ON conversations(timestamp);
    `);
  }

  /**
   * Get or create a session for a user
   */
  getSession(userId) {
    let session = this.sessions.get(userId);

    if (!session || this.isSessionExpired(session)) {
      // Create new session
      session = {
        sessionId: uuidv4(),
        userId,
        messages: [],
        context: {},
        createdAt: Date.now(),
        lastActivity: Date.now()
      };
      this.sessions.set(userId, session);
    } else {
      // Update last activity
      session.lastActivity = Date.now();
    }

    return session;
  }

  /**
   * Add message to conversation
   */
  addMessage(userId, role, content, metadata = null) {
    const session = this.getSession(userId);

    const message = {
      role, // 'user' or 'assistant'
      content,
      timestamp: Date.now(),
      metadata
    };

    // Add to in-memory session
    session.messages.push(message);

    // Persist to database
    const stmt = this.db.prepare(`
      INSERT INTO conversations (user_id, session_id, role, content, metadata)
      VALUES (?, ?, ?, ?, ?)
    `);

    stmt.run(
      userId,
      session.sessionId,
      role,
      content,
      metadata ? JSON.stringify(metadata) : null
    );

    return message;
  }

  /**
   * Get conversation history for a user
   * @param {string} userId - User ID
   * @param {number} limit - Max number of messages to return (default: 20 for full context)
   */
  getHistory(userId, limit = 20) {
    const session = this.getSession(userId);
    return session.messages.slice(-limit);
  }

  /**
   * Get formatted history for Claude API
   * Returns alternating user/assistant messages
   */
  getFormattedHistory(userId, limit = 20) {
    const history = this.getHistory(userId, limit);

    // Filter to only user/assistant messages, format for Claude
    return history
      .filter(msg => msg.role === 'user' || msg.role === 'assistant')
      .map(msg => ({
        role: msg.role,
        content: msg.content
      }));
  }

  /**
   * Store context for a session (e.g., pending approval, suggested plan)
   */
  setContext(userId, key, value) {
    const session = this.getSession(userId);
    session.context[key] = value;
  }

  /**
   * Get context from session
   */
  getContext(userId, key) {
    const session = this.getSession(userId);
    return session.context[key];
  }

  /**
   * Clear specific context
   */
  clearContext(userId, key) {
    const session = this.getSession(userId);
    delete session.context[key];
  }

  /**
   * End a session
   */
  endSession(userId) {
    this.sessions.delete(userId);
  }

  /**
   * Check if session is expired
   */
  isSessionExpired(session) {
    return Date.now() - session.lastActivity > this.SESSION_TIMEOUT;
  }

  /**
   * Cleanup expired sessions
   */
  cleanupExpiredSessions() {
    const now = Date.now();
    for (const [userId, session] of this.sessions.entries()) {
      if (this.isSessionExpired(session)) {
        this.sessions.delete(userId);
      }
    }
  }

  /**
   * Start periodic cleanup timer
   */
  startCleanupTimer() {
    setInterval(() => {
      this.cleanupExpiredSessions();
    }, 5 * 60 * 1000); // Every 5 minutes
  }

  /**
   * Get conversation statistics
   */
  getStats() {
    const activeSessions = this.sessions.size;

    const totalConversations = this.db.prepare(`
      SELECT COUNT(DISTINCT session_id) as count
      FROM conversations
      WHERE timestamp > datetime('now', '-24 hours')
    `).get().count;

    const totalMessages = this.db.prepare(`
      SELECT COUNT(*) as count
      FROM conversations
      WHERE timestamp > datetime('now', '-24 hours')
    `).get().count;

    return {
      activeSessions,
      totalConversations24h: totalConversations,
      totalMessages24h: totalMessages
    };
  }

  /**
   * Get recent conversations for a user
   */
  getUserConversations(userId, limit = 5) {
    const conversations = this.db.prepare(`
      SELECT DISTINCT session_id,
             MIN(timestamp) as started_at,
             MAX(timestamp) as last_message_at,
             COUNT(*) as message_count
      FROM conversations
      WHERE user_id = ?
      GROUP BY session_id
      ORDER BY last_message_at DESC
      LIMIT ?
    `).all(userId, limit);

    return conversations;
  }

  /**
   * Load session history from database (for restart/recovery)
   */
  loadSessionFromDB(userId, sessionId) {
    const messages = this.db.prepare(`
      SELECT role, content, timestamp, metadata
      FROM conversations
      WHERE user_id = ? AND session_id = ?
      ORDER BY timestamp ASC
    `).all(userId, sessionId);

    if (messages.length === 0) return null;

    const session = {
      sessionId,
      userId,
      messages: messages.map(msg => ({
        role: msg.role,
        content: msg.content,
        timestamp: new Date(msg.timestamp).getTime(),
        metadata: msg.metadata ? JSON.parse(msg.metadata) : null
      })),
      context: {},
      createdAt: new Date(messages[0].timestamp).getTime(),
      lastActivity: Date.now()
    };

    this.sessions.set(userId, session);
    return session;
  }
}

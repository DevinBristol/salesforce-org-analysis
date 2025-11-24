# OPUS Task: Generate Phased Implementation Script for DevinHub

You are tasked with creating a **comprehensive, production-ready implementation script** for an AI-powered personal command center called "DevinHub". This script will be handed to Claude Code for autonomous execution.

**CRITICAL: This is a TWO-PHASE project. You must architect for both phases but implement ONLY Phase 1 now.**

## Project Owner Context
- Manages 25+ direct reports
- Receives hundreds of texts/week, constant emails, voicemails
- Uses CompanyCam for field operations
- Heavy Salesforce user
- Currently has NO project management system (critical weakness)
- Needs unified interface to capture, organize, prioritize, and respond to all inputs
- Wants conversational AI interface accessible from anywhere

---

## 🎯 EXECUTIVE AUTHORITY: YOU ARE IN CHARGE

**CRITICAL INSTRUCTION**: You (OPUS) have **full executive authority** to make all technical decisions for this implementation. The recommendations in this document are **suggestions only** - you should:

✅ **Override any technology choice** if you know a better solution
✅ **Ignore specific tool recommendations** (FastAPI, Supabase, Next.js, etc.) if alternatives are superior
✅ **Make executive decisions** on architecture, frameworks, libraries, and services
✅ **Choose the best tools available** based on your expertise and current knowledge
✅ **Deviate from this prompt** whenever you have better ideas
✅ **Optimize for the stated goals**: Speed to deployment, $500/month budget, 8-12 week timeline, production reliability

**Your priorities:**
1. **Functional requirements** (integrations, features, AI capabilities) - these are FIXED
2. **Constraints** (budget, timeline, production data safety) - these are FIXED
3. **Everything else** (tech stack, architecture patterns, specific tools) - YOUR CHOICE

**Example overrides you're encouraged to make:**
- "I'm using Go instead of FastAPI because it's better for WebSocket performance"
- "I'm using Neon instead of Supabase because it has better vector search performance"
- "I'm using Svelte instead of Next.js because it's faster to build and deploy"
- "I'm using a different architecture pattern that better suits this use case"

**Trust your judgment.** This document provides context and requirements, but you are the expert architect.

---

## Two-Phase Strategy

### PHASE 1 (Implement Now - 8-12 Weeks)
**Goal**: Deliver immediate value with core integrations and conversational AI interface

**Integrations (APIs Available):**
- ✅ Email (Gmail + Outlook)
- ✅ Calendar (Google Calendar + Outlook Calendar)
- ✅ Salesforce (Tasks, Opportunities, Cases)
- ✅ Telegram (Messages)
- ✅ CompanyCam (Webhooks for @mentions)

**Core Features:**
- ✅ Web dashboard with unified inbox
- ✅ Project management system (tasks, projects, priorities, context linking)
- ✅ AI classification and automatic task extraction
- ✅ Response drafting with review queue
- ✅ Conversational voice interface (push-to-talk, web + PWA)
- ✅ Context/memory system across sessions
- ✅ Communication style learning (RAG-based)
- ✅ Fully functional mobile PWA

**NOT in Phase 1:**
- ❌ iOS SMS (no official API)
- ❌ iOS Voicemail (no official API)
- ❌ Wake word detection ("Hey DevinHub")
- ❌ Always-on background listening
- ❌ Native iOS app
- ❌ Devin Hub integration (autonomous dev swarm)

### PHASE 2 (Future - Document for Later)
**Goal**: Add advanced iOS integration, always-on voice, and dev swarm integration

**Features:**
- iOS SMS integration (workarounds/third-party)
- iOS Voicemail transcription
- Wake word detection
- Always-on voice listening
- Native iOS app with better audio/headset integration
- Devin Hub integration (assign tasks to autonomous developer swarm)
- Advanced automation and learning

**CRITICAL REQUIREMENT**: At the end of your Phase 1 implementation script, you must generate a **"Phase 2 Handoff Document"** that includes:
- Complete architecture overview of what was built in Phase 1
- Database schema and how to extend it
- Integration patterns used
- Where Phase 2 features should plug in
- A **detailed OPUS prompt** for Phase 2 that can be run later with full context

---

## PHASE 1 DETAILED REQUIREMENTS

### Core Functionality
DevinHub is an AI-powered hub that:
1. **Ingests** inputs from 5 channels simultaneously in real-time
2. **Organizes** all inputs into unified task/project management system
3. **Learns** user's communication style via RAG and maintains context on all contacts
4. **Assists** with drafting responses (email, Telegram) that sound like the user
5. **Proactively manages** user's attention and priorities
6. **Provides conversational voice interface** (push-to-talk, works on web + phone)
7. **Maintains memory** across all sessions and conversations

### Input Channels (Phase 1)

#### 1. Email (Gmail + Outlook)
- OAuth 2.0 authentication for both
- Real-time inbox monitoring (webhooks or polling)
- Send capabilities with proper threading
- Thread/conversation tracking
- Attachment handling
- **Production data**: Handle carefully, no destructive actions without review

#### 2. Calendar (Google Calendar + Outlook Calendar)
- OAuth 2.0 for both
- Bi-directional sync
- Event creation from voice/text commands
- Conflict detection
- Meeting attendee information
- Integration with task deadlines

#### 3. Salesforce
- OAuth + Salesforce REST API
- Sync: Tasks, Opportunities, Cases
- Bi-directional updates
- Link Salesforce records to DevinHub projects/tasks
- **Production data**: Read-only by default, write operations require review queue

#### 4. Telegram
- Bot API setup
- Personal messages and group messages
- Send/receive capabilities
- Media handling
- Real-time updates via webhooks

#### 5. CompanyCam
- Webhook setup for @mentions and comments
- API access for reading context (projects, photos)
- API for posting comments/replies
- Media/photo display in dashboard

#### 6. Voice Input (Phase 1: Push-to-Talk)
- Web-based microphone access (WebRTC)
- Mobile PWA microphone access
- Push-to-talk interface (button to activate)
- Real-time Speech-to-Text (OpenAI Whisper or Deepgram)
- Text-to-Speech for responses (ElevenLabs or OpenAI TTS)
- Full conversational capability with context
- Low-latency (<1 second response time)

#### 7. Manual Entry
- Web interface for direct task/project/note creation

### AI Capabilities & Intelligence

#### Context Management (Phase 1)
- **Cross-session memory**: Vector database (embeddings) for semantic search of all past interactions
- **Contact profiles**: Maintain detailed context for ALL contacts:
  - Communication history (emails, messages, calls)
  - Associated projects and tasks
  - Organizational relationships (who reports to whom, who works on what)
  - Individual preferences and context
  - Response patterns and priorities
- **Project/topic tracking**: Automatically link all inputs to relevant projects
- **Communication style learning (RAG approach)**:
  - Store embeddings of user's past emails/messages
  - When drafting responses, retrieve similar past messages
  - Use retrieved examples as context for Claude to match style
  - Learn preferred phrases, tone, formality level, sign-offs

#### Natural Language Understanding
Phase 1 must handle voice/text inputs like:

**Example 1:** *"Remind me to follow up with Sarah about the CompanyCam integration next Tuesday at 2pm and add it to the Phoenix project"*
- Parse entities: person (Sarah), topic (CompanyCam integration), date/time (Tuesday 2pm), project (Phoenix)
- Actions: Create calendar event, create task, link to Phoenix project, associate with Sarah's contact profile

**Example 2:** *"What did John say about the Denver site yesterday?"*
- Search: Contact (John), topic (Denver site), timeframe (yesterday)
- Return: Summarized conversation with source links (email thread, Telegram message, etc.)

**Example 3:** *"Draft a response to Lisa's email saying we'll handle it but need until Friday"*
- Retrieve Lisa's email from context
- Pull similar past responses from RAG
- Generate email in user's style
- Set deadline task for Friday
- Add to review queue

#### Autonomous Behaviors (Modifiable Rules)
**Default settings** (user can modify per contact/channel):
- ✅ **Draft responses for review** (don't auto-send)
- ✅ **Classify and organize** all inputs automatically
- ✅ **Proactive suggestions** ("You haven't responded to Mike in 3 days about urgent CompanyCam issue")
- ✅ **Entity extraction and linking** (auto-associate with projects, people, dates)
- ✅ **Calendar event creation** from natural language
- ❌ **Auto-send** (disabled by default, can enable for specific contacts/scenarios)

**Review Queue System**:
- All drafted responses wait in queue
- User can approve, edit, or reject
- System learns from edits (store edited versions in RAG for future reference)
- Configurable rules per contact: "Auto-approve routine responses to [person]"
- Confidence scores for each draft

### Voice Interface (Phase 1: Push-to-Talk Conversational)

#### Architecture
- **Web Dashboard**: Microphone button, click to talk
- **Mobile PWA**: Tap-to-talk on phone (works in browser)
- **Real-time audio pipeline**:
  1. User clicks/taps microphone
  2. Audio streams to backend via WebSocket
  3. Real-time STT (Whisper/Deepgram) transcribes
  4. Text sent to Claude with full context
  5. Claude responds with text
  6. TTS (ElevenLabs/OpenAI) generates audio
  7. Audio streams back to user
  8. Total latency goal: <1 second

#### Conversational Capabilities
- **Maintain context** during conversation (remember what was just discussed)
- **Follow-up questions**: "Tell me more about that", "Who else was involved?"
- **Multi-turn commands**:
  - User: "What's urgent?"
  - AI: [Lists 3 items]
  - User: "Draft a response to item 2"
  - AI: "Done, it's in your review queue"
- **Natural interruption**: User can interrupt AI mid-response

#### Voice Notifications (Phase 1)
- **Spoken alerts** for urgent items (plays audio notification)
- User can click to hear full context
- Can respond by voice immediately

#### Phase 2 Voice Enhancements (Not Now)
- Wake word detection ("Hey DevinHub")
- Always-on listening (background process)
- Native iOS app with better Bluetooth headset support
- Works while phone is locked

### Project Management System (Build From Scratch - Phase 1)
User currently has NO PM system. Build integrated solution:

#### Data Model
- **Projects**:
  - Name, description, status (active, on-hold, completed)
  - Associated contacts
  - Linked tasks
  - Timeline/milestones
  - Auto-created from recurring topics in communications

- **Tasks**:
  - Title, description, status (todo, in-progress, done, blocked)
  - Priority (urgent, high, medium, low) - AI-suggested
  - Due date (from calendar or NLP extraction)
  - Assigned to (contact)
  - Associated project
  - Source links (email thread, Telegram message, Salesforce record, voice conversation)
  - Dependencies (task X blocks task Y)

- **Context/Notes**:
  - Free-form notes
  - Voice memos (transcribed + audio)
  - Auto-generated from conversations

#### Features
- **Auto-categorization**: AI suggests project and priority for each task
- **Smart inbox**: All inputs appear here, user can process into tasks
- **Views**: Kanban board, list view, timeline/Gantt, calendar integration
- **Search**: Semantic search across all tasks, projects, communications
- **Voice interaction**: "Show me all Phoenix project tasks", "What's blocking the Denver site?"

### Output Interfaces (Phase 1)

#### Web Dashboard (Must Have)
**Core pages:**
1. **Unified Inbox**: All inputs from all channels in chronological order
   - Filter by channel, contact, project, urgency
   - AI-suggested actions for each item

2. **Review Queue**: Drafted responses awaiting approval
   - Edit inline with rich text editor
   - Approve/reject buttons
   - Learning feedback loop

3. **Projects View**:
   - Card view of all projects
   - Click into project for tasks, communications, timeline

4. **Tasks View**:
   - Kanban board (todo, in-progress, done)
   - List view with filters
   - Calendar view

5. **Contacts**:
   - List of all people
   - Click into contact for full history and context

6. **Voice Chat**:
   - Push-to-talk interface
   - Conversation history
   - Waveform visualization

7. **Analytics**:
   - Communication patterns
   - Response times
   - Task completion rates
   - Most active projects/contacts

#### Mobile PWA (Fully Functional - Phase 1)
- **Responsive design**: Works perfectly on iPhone
- **Installable**: Add to home screen
- **Offline capabilities**: Basic functionality without network
- **Push notifications**: For urgent items (web push API)
- **Voice interface**: Tap-to-talk works seamlessly
- **All features**: Full feature parity with desktop dashboard

#### Daily Digests
- **Morning briefing** (voice + email):
  - "Good morning. Here's your day..."
  - Today's calendar
  - Urgent tasks
  - Pending responses
  - Top 3 priorities (AI-suggested)

- **End-of-day summary** (voice + email):
  - Completed tasks
  - What's still pending
  - Tomorrow's prep

- **Weekly rollup** (email):
  - Projects progress
  - Communication stats
  - Insights and suggestions

---

## TECHNICAL IMPLEMENTATION (Phase 1)

### Infrastructure & Hosting

**⚠️ NOTE**: These are **SUGGESTIONS**. Choose whatever hosting and architecture you think is best.

#### Cloud Platform (YOUR CHOICE)
- **Suggested**: Railway, Render, Fly.io, or Vercel
- **Why suggested**: Fast deployment, good DX, scaling, reasonable pricing
- **But feel free to use**: AWS, GCP, Azure, DigitalOcean, Hetzner, Cloudflare, or whatever you prefer
- **Hard requirements**:
  - Always-on for real-time processing
  - Must fit within $500/month budget initially (plenty for Phase 1)
  - Reliable uptime

#### Architecture Pattern (YOUR CHOICE)
- **Suggested**: Monolithic initially, can split into microservices later
- **But feel free to use**: Microservices from start, serverless, edge functions, or whatever architecture you think best balances speed-to-deployment with scalability
- **Required capabilities**:
  - PostgreSQL or equivalent (relational data)
  - Vector search (embeddings for RAG)
  - Real-time communication (WebSockets, SSE, or equivalent)
  - Background job processing for async tasks
  - File storage for voice recordings, attachments (S3-compatible or equivalent)

### Technology Stack (Phase 1)

**⚠️ NOTE**: The following are **SUGGESTIONS ONLY**. You (OPUS) should choose whatever stack you believe is best for meeting the functional requirements within budget and timeline constraints. Feel free to completely ignore these recommendations if you have better alternatives.

#### Backend (YOUR CHOICE)
- **Suggested**: FastAPI (Python) or NestJS (TypeScript)
- **Why suggested**: Native async, good docs, fast, easy integration with AI libraries
- **But feel free to use**: Go, Rust, Elixir, Java, or whatever you think is best

#### Database (YOUR CHOICE)
- **Suggested**: PostgreSQL via Supabase
- **Why suggested**: Managed Postgres with pgvector for embeddings, built-in auth, real-time subscriptions, fast to set up
- **But feel free to use**: Neon, direct Postgres + pgvector, Pinecone, Qdrant, or whatever you think is best
- **Required capability**: Vector search for RAG (this is the only hard requirement)
- **Schema**: Detailed schema provided below as a starting point - modify as needed

#### AI/LLM Stack (MOSTLY FIXED)
- **Primary LLM**: Claude API (Anthropic) - **REQUIRED** (user specifically wants Claude)
  - **Opus**: Complex reasoning, important responses, learning
  - **Sonnet**: Most responses, classification, extraction (cost/speed balance)
  - **Haiku**: Simple tasks, notifications
- **Embeddings**: OpenAI `text-embedding-3-small` suggested, but use whatever you think is best (Voyage, Cohere, etc.)
- **Vector Search**: Whatever works with your database choice
- **Voice** (YOUR CHOICE):
  - **STT**: OpenAI Whisper, Deepgram, AssemblyAI, or whatever is best for <1s latency
  - **TTS**: ElevenLabs, OpenAI TTS, Play.ht, or whatever sounds best and fits budget

#### Frontend (YOUR CHOICE)
- **Suggested**: Next.js 14 (React) with TypeScript
- **Why suggested**: SSR, excellent PWA support, good DX, large ecosystem
- **But feel free to use**: SvelteKit, Remix, Astro, Vue/Nuxt, or whatever you think is fastest to build and deploy
- **UI Library**: shadcn/ui suggested, but use whatever you prefer (Material UI, Chakra, custom, etc.)
- **State Management**: Your choice (Zustand, Redux, Jotai, Svelte stores, whatever)
- **Real-time**: Your choice (Socket.io, native WebSockets, SSE, whatever works best)
- **Voice**: WebRTC + Web Audio API or alternatives

#### Mobile PWA (YOUR CHOICE)
- **Suggested**: Same codebase as web dashboard (if using responsive framework)
- **Required**: Must be installable on iPhone, work offline (basic functionality), support push notifications
- **Implementation**: Your choice on how to achieve this

#### Integration Framework (YOUR CHOICE)
- **Suggested**: MCP (Model Context Protocol) for each integration where applicable
- **Why suggested**: Standardized, maintainable, can be used by other Claude instances
- **But feel free to use**: Direct API integrations, Zapier/n8n, custom integration layer, or whatever you think is best
- **Required**: Must support all 7 integrations in Phase 1

#### Real-time Communication (YOUR CHOICE)
- **Suggested**: WebSockets (Socket.io or native)
- **Required capability**: Live updates for inbox, voice streaming, notifications
- **Implementation**: Your choice (WebSockets, SSE, polling, long-polling, whatever)

### Database Schema (Phase 1)

**⚠️ NOTE**: This schema is a **STARTING POINT**. Feel free to modify, optimize, or completely redesign based on your chosen database and architecture. The important thing is that it supports the functional requirements (contacts, projects, tasks, messages, RAG/vector search, etc.).

```sql
-- Contacts: All people
CREATE TABLE contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255)[],  -- Array for multiple emails
    phone VARCHAR(50)[],    -- Array for multiple phones
    telegram_username VARCHAR(255),
    salesforce_id VARCHAR(255),
    organization VARCHAR(255),
    role VARCHAR(255),
    reports_to UUID REFERENCES contacts(id),  -- Org hierarchy
    context JSONB,  -- Flexible field for any contact-specific data
    communication_preferences JSONB,  -- How they like to be contacted
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Projects: Group related work
CREATE TABLE projects (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'active',  -- active, on-hold, completed
    priority VARCHAR(50),  -- urgent, high, medium, low
    owner_id UUID REFERENCES contacts(id),
    start_date DATE,
    target_date DATE,
    metadata JSONB,  -- Flexible field
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Tasks: From all sources
CREATE TABLE tasks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    title VARCHAR(500) NOT NULL,
    description TEXT,
    status VARCHAR(50) DEFAULT 'todo',  -- todo, in-progress, done, blocked
    priority VARCHAR(50),  -- urgent, high, medium, low (AI-suggested)
    due_date TIMESTAMP,
    project_id UUID REFERENCES projects(id),
    assigned_to UUID REFERENCES contacts(id),
    source_type VARCHAR(50),  -- email, telegram, salesforce, voice, manual
    source_id VARCHAR(255),  -- ID from source system
    source_url TEXT,  -- Link back to source
    depends_on UUID[],  -- Array of task IDs this depends on
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Messages: Unified inbox for all input types
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel VARCHAR(50) NOT NULL,  -- email, telegram, salesforce, companycam, voice
    channel_message_id VARCHAR(255),  -- Original message ID from source
    from_contact_id UUID REFERENCES contacts(id),
    to_contact_ids UUID[],  -- Array for multiple recipients
    subject VARCHAR(500),
    body TEXT,
    thread_id VARCHAR(255),  -- For email threads
    parent_message_id UUID REFERENCES messages(id),  -- For replies
    attachments JSONB,  -- Array of attachment info
    metadata JSONB,  -- Channel-specific data
    is_urgent BOOLEAN DEFAULT FALSE,  -- AI-classified
    requires_response BOOLEAN,  -- AI-classified
    processed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT NOW(),
    received_at TIMESTAMP NOT NULL
);

-- Responses: Drafted replies in review queue
CREATE TABLE responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID REFERENCES messages(id),  -- Responding to which message
    channel VARCHAR(50) NOT NULL,
    to_contact_ids UUID[],
    subject VARCHAR(500),
    body TEXT,
    status VARCHAR(50) DEFAULT 'pending',  -- pending, approved, rejected, sent
    confidence_score FLOAT,  -- AI confidence in this draft
    draft_reasoning TEXT,  -- Why AI drafted this way
    user_edits TEXT,  -- Track what user changed (for learning)
    created_at TIMESTAMP DEFAULT NOW(),
    reviewed_at TIMESTAMP,
    sent_at TIMESTAMP
);

-- Context Memory: For RAG and conversation history
CREATE TABLE context_memory (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content TEXT NOT NULL,
    content_type VARCHAR(50),  -- email, message, voice, note, task
    source_id UUID,  -- Links to messages, tasks, etc.
    contact_ids UUID[],  -- Associated contacts
    project_ids UUID[],  -- Associated projects
    embedding vector(1536),  -- OpenAI embedding dimension
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Create index for vector similarity search
CREATE INDEX ON context_memory USING ivfflat (embedding vector_cosine_ops);

-- Voice Conversations: Track voice interactions
CREATE TABLE voice_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id UUID NOT NULL,  -- Group multi-turn conversations
    user_transcript TEXT,
    ai_response TEXT,
    audio_url TEXT,  -- S3 URL for audio recording
    context_used JSONB,  -- What context was retrieved for this turn
    actions_taken JSONB,  -- What actions resulted (tasks created, etc.)
    created_at TIMESTAMP DEFAULT NOW()
);

-- Automation Rules: User-configurable
CREATE TABLE automation_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_type VARCHAR(50),  -- auto_approve, auto_classify, priority_boost
    conditions JSONB,  -- When this rule applies
    actions JSONB,  -- What to do
    enabled BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

-- Communication Style Examples: For RAG-based style learning
CREATE TABLE communication_examples (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    example_type VARCHAR(50),  -- email, telegram, voice
    recipient_type VARCHAR(50),  -- direct_report, peer, executive, external
    context VARCHAR(255),  -- Brief description
    content TEXT NOT NULL,  -- The actual message user sent
    embedding vector(1536),  -- For similarity search
    metadata JSONB,
    created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX ON communication_examples USING ivfflat (embedding vector_cosine_ops);
```

### AI Orchestration Logic (Phase 1)

#### Input Processing Pipeline
```
1. INPUT ARRIVES (email, Telegram, Salesforce update, voice, CompanyCam comment)
   ↓
2. INGEST
   - Store in messages table
   - Extract metadata (sender, timestamp, channel)
   ↓
3. TRANSCRIBE (if voice)
   - OpenAI Whisper API
   - Store transcript
   ↓
4. ENTITY EXTRACTION (Claude Haiku for speed)
   - People: Named entities, extract contact IDs
   - Dates/Times: Parse natural language dates
   - Projects: Match to existing or suggest new
   - Topics: Key themes/subjects
   - Actions: Requests, questions, FYIs
   ↓
5. CONTEXT ENRICHMENT (Vector Search)
   - Generate embedding of message
   - Search context_memory for similar past interactions
   - Pull relevant contact history
   - Pull relevant project information
   - Recent conversation history with this person
   ↓
6. CLASSIFICATION (Claude Sonnet)
   - Urgency: urgent/high/medium/low
   - Type: question, request, FYI, meeting invite, etc.
   - Requires response: yes/no
   - Sentiment: positive, neutral, negative, frustrated
   ↓
7. ACTION DETERMINATION (Claude Sonnet with context)
   Based on classification and content:
   - Create task? (if request or action item)
   - Create calendar event? (if meeting or deadline)
   - Draft response? (if requires reply)
   - Link to project? (if related to existing project)
   - Notify user? (if urgent)
   - Just archive? (if FYI only)
   ↓
8. EXECUTION
   - Create tasks in database
   - Create calendar events via API
   - Draft response (if needed) → Review Queue
   - Update project associations
   - Create notifications
   ↓
9. NOTIFICATION (conditional)
   - If urgent: Voice notification (play TTS alert) + visual alert
   - If high: Visual dashboard notification
   - If medium/low: Just appears in inbox
   ↓
10. MEMORY UPDATE
    - Store processed message content + entities in context_memory with embedding
    - Update contact profile with new interaction
    - Update project timeline
```

#### Response Generation (RAG-based Style Learning)
```
1. USER APPROVAL to draft response (from review queue or voice command)
   ↓
2. GATHER CONTEXT
   - Original message/email being responded to
   - Thread history (if email thread)
   - Recent interactions with this contact
   - Relevant project information
   ↓
3. RETRIEVE SIMILAR PAST RESPONSES (RAG)
   - Generate embedding of: recipient + context + intent
   - Vector search in communication_examples table
   - Retrieve top 5 similar messages user has sent before
   - Extract patterns:
     * Greeting style ("Hi John," vs "John," vs "Hey!")
     * Tone (formal, casual, friendly)
     * Common phrases user uses
     * Sign-off ("Best," vs "Thanks," vs "Cheers")
     * Length and structure preferences
   ↓
4. GENERATE DRAFT (Claude Opus for important, Sonnet for routine)
   - Prompt includes:
     * Original message
     * Context about relationship/project
     * Retrieved example responses (RAG results)
     * Specific instructions from user if given
   - Prompt: "Draft a response that matches the user's style from these examples..."
   ↓
5. CONFIDENCE SCORING
   - High confidence: Clear request, have similar examples, straightforward
   - Low confidence: Ambiguous, no similar examples, sensitive topic
   ↓
6. ADD TO REVIEW QUEUE
   - Store in responses table with status='pending'
   - Show in dashboard with confidence score
   - Include reasoning: "I drafted this as a friendly approval based on your past responses to Sarah"
   ↓
7. USER REVIEW
   - Approve → Send via appropriate channel
   - Edit → Store edits, learn from changes, then send
   - Reject → Don't send, analyze why (low quality, wrong tone?)
   ↓
8. LEARNING
   - If approved: Store as positive example in communication_examples
   - If edited: Store final version (after edits) as better example
   - If rejected: Note what was wrong (if user provides feedback)
   ↓
9. SEND
   - Email: via Gmail/Outlook API
   - Telegram: via Bot API
   - Salesforce: post comment/update
   - CompanyCam: post comment
   ↓
10. UPDATE MEMORY
    - Store sent message in context_memory
    - Mark original message as processed
    - Update contact interaction history
```

#### Voice Interaction Flow (Phase 1: Push-to-Talk)
```
1. USER CLICKS/TAPS MICROPHONE
   - WebSocket connection established (if not already open)
   - Frontend starts recording audio
   ↓
2. AUDIO STREAMING
   - Audio chunks stream to backend via WebSocket
   - Real-time STT (Whisper/Deepgram) transcribes in real-time
   - Show live transcript to user (visual feedback)
   ↓
3. USER RELEASES BUTTON or says complete phrase
   - Final transcript ready
   ↓
4. CONTEXT RETRIEVAL
   - Maintain conversation_id for this session
   - Retrieve past turns in this conversation (last 5 turns)
   - Vector search in context_memory for relevant information
   ↓
5. INTENT CLASSIFICATION (Claude Sonnet fast)
   - Query: "What's urgent?" → fetch_urgent_items
   - Command: "Draft a response to Lisa" → draft_response
   - Update: "Add this to Phoenix project" → create_task
   - Question: "What did Mike say yesterday?" → search_history
   ↓
6. EXECUTE ACTION
   - Fetch data from database
   - Perform operations (create task, draft response, etc.)
   - Format results as natural language
   ↓
7. GENERATE RESPONSE (Claude Sonnet)
   - Conversational, natural tone
   - Include relevant details
   - Ask clarifying questions if needed
   ↓
8. TEXT-TO-SPEECH
   - Convert response text to audio (ElevenLabs/OpenAI TTS)
   - Stream audio back to frontend
   ↓
9. PLAY AUDIO + SHOW TEXT
   - User hears spoken response
   - Text appears on screen simultaneously
   - Waveform visualization
   ↓
10. WAIT FOR NEXT INPUT
    - Conversation continues (maintain context)
    - User can interrupt or start new turn
    ↓
11. STORE CONVERSATION TURN
    - Save in voice_conversations table
    - Add to context_memory for future retrieval
```

### Integration Specifications (Phase 1)

#### Integration 1: Gmail
**Setup:**
- Google Cloud Project with Gmail API enabled
- OAuth 2.0 credentials (client ID, secret)
- Scopes: `gmail.modify`, `gmail.send`, `gmail.labels`

**Implementation:**
- MCP Server: `mcp-server-gmail`
- Watch for new messages: Gmail Push Notifications (Pub/Sub webhook)
- Polling fallback: Every 60 seconds
- Send emails: Gmail API `messages.send` with proper threading
- Thread tracking: Use Gmail's `threadId`

**Key Operations:**
- `fetch_unread()`: Get unread messages
- `get_thread(thread_id)`: Get full conversation
- `send_email(to, subject, body, thread_id?)`: Send or reply
- `mark_read(message_id)`: Mark as processed

#### Integration 2: Outlook (Microsoft 365)
**Setup:**
- Azure AD App Registration
- OAuth 2.0 with Microsoft Graph API
- Scopes: `Mail.ReadWrite`, `Mail.Send`

**Implementation:**
- MCP Server: `mcp-server-outlook`
- Watch for new messages: Microsoft Graph webhooks (subscription)
- Polling fallback: Every 60 seconds
- Send emails: Graph API `/me/sendMail`
- Thread tracking: Use `conversationId`

**Key Operations:**
- `fetch_unread()`: Get unread messages
- `get_conversation(conversation_id)`: Get thread
- `send_email(to, subject, body, reply_to_id?)`: Send or reply
- `mark_read(message_id)`: Mark as processed

#### Integration 3: Google Calendar
**Setup:**
- Same Google Cloud Project as Gmail
- OAuth 2.0 credentials
- Scopes: `calendar.events`

**Implementation:**
- MCP Server: `mcp-server-google-calendar`
- Watch for changes: Google Calendar Push Notifications
- Polling fallback: Every 5 minutes
- Create events: Calendar API `events.insert`
- Update events: Calendar API `events.patch`
- Conflict detection: Check existing events before creating

**Key Operations:**
- `get_events(start_date, end_date)`: Fetch events in range
- `create_event(title, start, end, attendees[], description)`: New event
- `update_event(event_id, updates)`: Modify event
- `check_conflicts(start, end)`: Return overlapping events

#### Integration 4: Outlook Calendar
**Setup:**
- Same Azure AD app as Outlook email
- Scopes: `Calendars.ReadWrite`

**Implementation:**
- MCP Server: `mcp-server-outlook-calendar`
- Watch for changes: Microsoft Graph webhooks
- Polling fallback: Every 5 minutes
- Create events: Graph API `/me/calendar/events`
- Similar to Google Calendar operations

#### Integration 5: Salesforce
**Setup:**
- Salesforce Connected App
- OAuth 2.0 with Salesforce REST API
- Scopes: Access to Tasks, Opportunities, Cases objects

**Implementation:**
- MCP Server: `mcp-server-salesforce`
- Watch for changes: Salesforce Platform Events or polling (every 10 min)
- **Read operations**: Fetch Tasks, Opportunities, Cases assigned to user
- **Write operations**: By default, only update via review queue (production safety)
- Link Salesforce records to DevinHub projects via custom field or external mapping

**Key Operations:**
- `fetch_tasks()`: Get user's Salesforce tasks
- `fetch_opportunities()`: Get opportunities user owns
- `fetch_cases()`: Get cases assigned to user
- `create_task(subject, description, due_date)`: Create task (review queue)
- `update_record(record_id, fields)`: Update any record (review queue)

**Production Safety**:
- All write operations go through review queue
- User approves before Salesforce is updated
- Read-only mode by default

#### Integration 6: Telegram
**Setup:**
- Create bot via @BotFather
- Get bot token
- Set webhook URL for real-time message delivery

**Implementation:**
- MCP Server: `mcp-server-telegram`
- Webhook: Telegram sends POST requests for new messages
- Send messages: Telegram Bot API `sendMessage`
- Group messages: Handle group context separately

**Key Operations:**
- `receive_message(webhook_payload)`: Process incoming message
- `send_message(chat_id, text)`: Send message
- `get_chat(chat_id)`: Get chat info
- `handle_group_message(payload)`: Special handling for groups

#### Integration 7: CompanyCam
**Setup:**
- CompanyCam API key
- Webhook configuration for @mentions

**Implementation:**
- MCP Server: `mcp-server-companycam`
- Webhook: CompanyCam sends POST when user is @mentioned
- API: Fetch project details, photos, comments
- Post comments: CompanyCam API

**Key Operations:**
- `receive_mention(webhook_payload)`: Process @mention
- `get_project(project_id)`: Fetch project details
- `get_photos(project_id)`: Fetch project photos
- `post_comment(project_id, text)`: Reply to comment

#### Integration 8: Voice Input (Phase 1 Implementation)
**Setup:**
- OpenAI API key (for Whisper STT) or Deepgram API key
- ElevenLabs API key (for TTS) or OpenAI API key
- WebSocket server for real-time audio streaming

**Implementation:**
- Frontend: WebRTC MediaRecorder API for audio capture
- Backend: WebSocket endpoint `/voice/stream`
- STT: Stream audio chunks to Whisper/Deepgram API
- TTS: Generate audio from text responses
- Storage: Save voice recordings to S3 for history

**Key Operations:**
- `start_voice_session()`: Establish WebSocket connection
- `stream_audio(audio_chunk)`: Send audio to STT
- `process_transcript(text)`: Handle transcribed text
- `generate_speech(text)`: Convert response to audio
- `stream_audio_response(audio_chunk)`: Send audio back to user

### Frontend Implementation (Phase 1)

#### Tech Stack
- **Framework**: Next.js 14 with App Router
- **Language**: TypeScript
- **Styling**: Tailwind CSS
- **Components**: shadcn/ui (Radix primitives + Tailwind)
- **State**: Zustand for global state
- **Real-time**: Socket.io client
- **Voice**: WebRTC + Web Audio API

#### Key Pages/Routes

1. **`/dashboard`** (Home)
   - Unified inbox (all channels)
   - Today's priorities
   - Quick stats
   - Recent activity

2. **`/inbox`**
   - Filterable message list
   - Channel tabs (All, Email, Telegram, Salesforce, etc.)
   - Mark as processed
   - Quick actions (draft response, create task)

3. **`/review-queue`**
   - Drafted responses awaiting approval
   - Inline editing
   - Approve/reject buttons
   - Confidence scores

4. **`/projects`**
   - Project cards
   - Click into project detail view
   - Task lists per project
   - Activity timeline

5. **`/tasks`**
   - Kanban board view (default)
   - List view option
   - Calendar view option
   - Filters (priority, status, project, assignee)

6. **`/contacts`**
   - Searchable list
   - Click into contact detail
   - Full communication history
   - Associated projects/tasks

7. **`/voice`**
   - Voice chat interface
   - Push-to-talk button
   - Conversation history
   - Transcript display

8. **`/settings`**
   - Integration management (connect/disconnect accounts)
   - Automation rules editor
   - Notification preferences
   - Voice settings

#### PWA Setup
```json
// public/manifest.json
{
  "name": "DevinHub",
  "short_name": "DevinHub",
  "description": "AI-Powered Personal Command Center",
  "start_url": "/dashboard",
  "display": "standalone",
  "background_color": "#ffffff",
  "theme_color": "#000000",
  "icons": [
    {
      "src": "/icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "/icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    }
  ]
}
```

Service worker for offline support and push notifications.

#### Real-time Updates
- Socket.io connection established on app load
- Listen for events: `new_message`, `task_created`, `response_drafted`
- Update UI in real-time without refresh
- Toast notifications for important events

### Deployment (Phase 1)

#### Step-by-Step Deployment to Render/Railway

1. **Prepare Repository**
   - Initialize git repo
   - Create `.env.example` with all required variables
   - Add `.gitignore` (node_modules, .env, etc.)

2. **Set Up Supabase**
   - Create new Supabase project
   - Run database migrations (create all tables)
   - Enable pgvector extension
   - Get connection string

3. **Set Up Render/Railway**
   - Connect GitHub repo
   - Create services:
     - Backend (FastAPI): `uvicorn main:app --host 0.0.0.0 --port $PORT`
     - Frontend (Next.js): Auto-detected
   - Add environment variables (all API keys, database URL, etc.)

4. **Configure OAuth Applications**
   - **Google**: Create OAuth credentials, add redirect URI
   - **Microsoft**: Create Azure AD app, add redirect URI
   - **Salesforce**: Create Connected App, add callback URL
   - Store credentials in environment variables

5. **Set Up External Services**
   - **Telegram**: Create bot, set webhook to backend URL
   - **CompanyCam**: Configure webhook to backend URL
   - **OpenAI/Deepgram**: Get API keys
   - **ElevenLabs**: Get API key

6. **Deploy**
   - Push to GitHub
   - Render/Railway auto-deploys
   - Verify both frontend and backend are running
   - Check logs for errors

7. **Initial Setup Flow**
   - User visits frontend
   - Goes through onboarding:
     - Connect Gmail (OAuth flow)
     - Connect Outlook (OAuth flow)
     - Connect Google Calendar (OAuth flow)
     - Connect Outlook Calendar (OAuth flow)
     - Connect Salesforce (OAuth flow)
     - Connect Telegram (save chat ID)
     - Set CompanyCam webhook
   - AI starts ingesting data

8. **Monitoring**
   - Set up Sentry for error tracking
   - Monitor API usage (stay within budget)
   - Set up alerts for critical failures

### Testing Strategy (Phase 1)

#### Integration Tests
For each integration:
- Test OAuth flow
- Test receiving data (mock webhook or actual test message)
- Test sending data (draft email, create calendar event)
- Test error handling (rate limits, API failures)

#### Voice Interface Tests
- Record audio → check transcription accuracy
- Send text → check TTS audio quality
- Test conversation context (multi-turn)
- Test latency (under 1 second)

#### AI Pipeline Tests
- Send test email → verify task extraction
- Send test with date mention → verify calendar event creation
- Request response draft → verify style matches RAG examples
- Test urgent classification → verify notification sent

#### End-to-End Scenarios
1. **Email arrives** → Auto-creates task → User asks via voice "what's new?" → AI speaks the task → User says "draft a response" → Draft appears in review queue
2. **Telegram message** mentions meeting → Calendar event created → Conflict detected → User notified
3. **Voice command**: "Add a task to Phoenix project: review budget by Friday" → Task created with correct project, due date

### Production Data Safety (Phase 1)

**Critical: User has 25+ reports, production Salesforce, real emails**

#### Safety Measures
1. **Read-only by default**:
   - All integrations start in read-only mode
   - Write operations require explicit user approval

2. **Review Queue for all outgoing**:
   - Never auto-send emails, messages, or Salesforce updates
   - Always go through review queue
   - User must explicitly approve

3. **Test Mode**:
   - Include a "test mode" toggle in settings
   - In test mode, simulate sending (don't actually send)
   - Log what would have been sent

4. **Backup/Audit Log**:
   - Log all operations (creates, updates, sends)
   - Allow user to see full audit trail
   - Can rollback if needed (for Salesforce updates)

5. **Gradual Rollout**:
   - Start with monitoring only (no responses)
   - User gets comfortable seeing AI classifications
   - Then enable draft responses
   - User manually reviews for a few weeks
   - Optionally enable auto-approve for specific contacts

---

## PHASE 2 HANDOFF DOCUMENT (Generate This)

At the end of your Phase 1 implementation script, you MUST generate a comprehensive "Phase 2 Handoff Document" that includes:

### What to Include in Phase 2 Handoff:

1. **Architecture Overview**
   - What was built in Phase 1
   - How components interact (system diagram)
   - Database schema and how to extend it
   - Where Phase 2 features should plug in

2. **Integration Patterns**
   - How Phase 1 integrations were implemented
   - Pattern to follow for new integrations (SMS, voicemail)
   - MCP server structure

3. **AI Pipeline Documentation**
   - How input processing works
   - How to extend for new input types
   - Where to add new classification logic

4. **Voice System Architecture**
   - Phase 1: Push-to-talk implementation
   - Phase 2 additions needed:
     - Wake word detection (Picovoice Porcupine?)
     - Background listening process
     - Native iOS app requirements
     - Better Bluetooth audio handling

5. **Phase 2 Feature Specifications**
   - **iOS SMS**: Technical approaches and limitations
   - **iOS Voicemail**: Technical approaches and limitations
   - **Wake Word**: Implementation plan
   - **Always-on Voice**: Architecture changes needed
   - **Native iOS App**: Why it's needed, what it provides
   - **Devin Hub Integration**: How to connect to autonomous dev swarm

6. **OPUS Prompt for Phase 2**
   - Complete, detailed prompt that can be given to OPUS
   - Includes full context from Phase 1
   - Specifies exactly what to build in Phase 2
   - References existing codebase structure
   - Provides implementation guide for Phase 2 only

---

## YOUR DELIVERABLES (What You Must Generate)

### 1. Architecture Document
- System diagram (ASCII art or description for diagramming)
- Component breakdown
- Data flow diagrams
- Technology stack with justifications
- Why each choice was made

### 2. Complete Codebase Structure

Provide full directory structure and key files:

```
devinhub/
├── backend/
│   ├── main.py                 # FastAPI app entry point
│   ├── config.py               # Environment variables, settings
│   ├── database.py             # Database connection, models
│   ├── routers/
│   │   ├── auth.py            # OAuth flows
│   │   ├── messages.py        # Inbox API
│   │   ├── tasks.py           # Task management API
│   │   ├── projects.py        # Project management API
│   │   ├── responses.py       # Review queue API
│   │   ├── voice.py           # Voice WebSocket endpoint
│   │   └── contacts.py        # Contact management API
│   ├── services/
│   │   ├── ai_orchestrator.py    # Main AI pipeline
│   │   ├── input_processor.py    # Process incoming messages
│   │   ├── entity_extractor.py   # NLP entity extraction
│   │   ├── context_manager.py    # RAG and memory
│   │   ├── response_generator.py # Draft responses
│   │   ├── voice_handler.py      # STT/TTS logic
│   │   └── notification_service.py # Alerts
│   ├── mcp_servers/
│   │   ├── gmail/
│   │   ├── outlook/
│   │   ├── google_calendar/
│   │   ├── outlook_calendar/
│   │   ├── salesforce/
│   │   ├── telegram/
│   │   └── companycam/
│   ├── models/                 # Pydantic models
│   ├── migrations/             # Database migrations
│   └── requirements.txt
├── frontend/
│   ├── app/
│   │   ├── dashboard/
│   │   ├── inbox/
│   │   ├── review-queue/
│   │   ├── projects/
│   │   ├── tasks/
│   │   ├── contacts/
│   │   ├── voice/
│   │   └── settings/
│   ├── components/
│   │   ├── ui/                # shadcn components
│   │   ├── MessageCard.tsx
│   │   ├── TaskCard.tsx
│   │   ├── VoiceInterface.tsx
│   │   └── ReviewQueueItem.tsx
│   ├── lib/
│   │   ├── socket.ts          # Socket.io client
│   │   ├── api.ts             # API client
│   │   └── store.ts           # Zustand store
│   ├── public/
│   │   ├── manifest.json      # PWA manifest
│   │   └── sw.js              # Service worker
│   ├── package.json
│   └── next.config.js
├── docker-compose.yml          # Local development
├── .env.example
└── README.md
```

For each key file, provide:
- Full implementation or detailed pseudocode
- Comments explaining logic
- TODO markers for Claude Code to fill in

### 3. Configuration Files

**docker-compose.yml** (for local development)
**Dockerfile** (for backend)
**.env.example** (all required environment variables with descriptions)
**Railway/Render config** (deployment configuration)

### 4. Step-by-Step Implementation Guide for Claude Code

Provide numbered, sequential steps that Claude Code can follow:

```
PHASE 1 IMPLEMENTATION STEPS:

Step 1: Initialize Project Structure
  - Create directories as shown above
  - Initialize git repo
  - Create .env.example

Step 2: Set Up Database
  - Create Supabase project
  - Run SQL migrations (create all tables)
  - Enable pgvector extension
  - Get connection string

Step 3: Backend - Core Setup
  - Install Python dependencies
  - Create FastAPI app in main.py
  - Set up database connection
  - Create Pydantic models

Step 4: Implement MCP Server - Gmail
  - Create mcp_servers/gmail/ directory
  - Implement OAuth flow
  - Implement webhook receiver
  - Implement send_email function
  - Test with personal Gmail

Step 5: Implement MCP Server - Outlook
  - [Similar to Gmail...]

[Continue for each integration...]

Step 10: Implement AI Orchestrator
  - Create services/ai_orchestrator.py
  - Implement input processing pipeline
  - Implement entity extraction (Claude API)
  - Implement context retrieval (vector search)
  - Implement classification logic

Step 11: Implement Response Generator (RAG)
  - Create services/response_generator.py
  - Implement style learning (RAG approach)
  - Implement draft generation (Claude API)
  - Implement review queue logic

Step 12: Implement Voice Handler
  - Create services/voice_handler.py
  - Set up WebSocket endpoint
  - Integrate Whisper/Deepgram STT
  - Integrate ElevenLabs/OpenAI TTS
  - Implement conversation context

Step 13: Frontend - Core Setup
  - Initialize Next.js project
  - Install dependencies (shadcn/ui, Socket.io, etc.)
  - Set up Tailwind CSS
  - Create base layout

Step 14: Frontend - Dashboard Page
  - Create app/dashboard/page.tsx
  - Implement unified inbox view
  - Connect to backend API
  - Set up Socket.io for real-time updates

[Continue for each page...]

Step 20: Implement PWA
  - Create manifest.json
  - Create service worker
  - Add to Next.js config
  - Test installation on iPhone

Step 21: Voice Interface Frontend
  - Create components/VoiceInterface.tsx
  - Implement WebRTC audio capture
  - Connect to voice WebSocket
  - Implement push-to-talk UI
  - Display transcript and waveform

Step 22: Deploy Backend to Render/Railway
  - Connect GitHub repo
  - Configure environment variables
  - Deploy
  - Verify deployment

Step 23: Deploy Frontend to Vercel/Render
  - Configure build settings
  - Set environment variables (backend API URL)
  - Deploy
  - Verify PWA works

Step 24: Configure OAuth Integrations
  - Google Cloud Console: Create OAuth credentials
  - Azure Portal: Create AD app
  - Salesforce: Create Connected App
  - Update redirect URIs to production URLs
  - Test each OAuth flow

Step 25: Configure Webhooks
  - Telegram: Set webhook URL
  - CompanyCam: Configure webhook
  - Gmail: Set up Pub/Sub push notifications
  - Outlook: Set up Microsoft Graph subscriptions

Step 26: Seed Communication Examples
  - User provides 10-20 example emails they've sent
  - Store in communication_examples table with embeddings
  - Verify RAG retrieval works

Step 27: End-to-End Testing
  - Send test email → verify task creation
  - Use voice interface → verify conversation works
  - Request response draft → verify style matches examples
  - Approve draft → verify email sends
  - Check Salesforce sync → verify tasks appear

Step 28: User Onboarding
  - Create onboarding flow in frontend
  - Guide user through connecting all accounts
  - Provide tutorial for voice interface
  - Show example of review queue

Step 29: Monitor Initial Usage
  - Check logs for errors
  - Monitor API usage vs. budget
  - Gather user feedback
  - Fix any critical bugs

Step 30: Generate Phase 2 Handoff Document
  - Document everything built
  - Create Phase 2 OPUS prompt
  - Save to repository
```

### 5. Testing Checklist

Provide a checklist of tests to run:
- [ ] Gmail OAuth connects successfully
- [ ] New Gmail received → appears in inbox
- [ ] Email classification works (urgent/not urgent)
- [ ] Task auto-created from email with date mention
- [ ] Response draft generated in user's style
- [ ] Calendar event created from voice command
- [ ] Salesforce tasks synced to DevinHub
- [ ] Voice conversation maintains context across turns
- [ ] PWA installable on iPhone
- [ ] Real-time dashboard updates work
- [ ] Review queue approval sends email
- [ ] All integrations working together

### 6. User Documentation

Create a `USER_GUIDE.md` that explains:
- How to use DevinHub
- Connecting each integration
- Voice commands reference ("What can I say?")
- Review queue workflow
- Setting up automation rules
- Interpreting AI classifications

### 7. Phase 2 Handoff Document (CRITICAL)

At the end, generate `PHASE_2_HANDOFF.md` that includes:

```markdown
# DevinHub Phase 2 Handoff Document

## Phase 1 Summary
[What was built, architecture, etc.]

## Architecture for Phase 2
[How Phase 2 features plug into Phase 1 system]

## Phase 2 Features
### iOS SMS Integration
[Technical approach, challenges, implementation guide]

### iOS Voicemail Integration
[Technical approach, challenges, implementation guide]

### Wake Word Detection
[Recommended solution, integration with existing voice system]

### Always-On Voice
[Architecture changes needed, battery considerations]

### Native iOS App
[Why needed, what it provides over PWA, implementation plan]

### Devin Hub Integration
[How to connect to autonomous developer swarm]

## OPUS Prompt for Phase 2
[Complete, self-contained prompt that OPUS can use to implement Phase 2]
[Include full context from Phase 1]
[Reference codebase structure]
[Specify Phase 2 implementation steps]
```

---

## SUCCESS CRITERIA (Phase 1)

The Phase 1 implementation is successful when:

- ✅ All 5 integrations receiving data in real-time (Email x2, Calendar x2, Salesforce, Telegram, CompanyCam)
- ✅ User can have voice conversations via web dashboard or mobile PWA (push-to-talk)
- ✅ Tasks auto-create from emails/messages with correct entity extraction (people, dates, projects)
- ✅ Responses are drafted in user's style (RAG-based) and appear in review queue
- ✅ Web dashboard shows unified view of all inputs with real-time updates
- ✅ Mobile PWA is fully functional and installable on iPhone
- ✅ Voice notifications work for urgent items
- ✅ Calendar events auto-create from voice commands
- ✅ System maintains context across sessions (can ask "what did John say yesterday?")
- ✅ Project management system works (create projects, assign tasks, track progress)
- ✅ Can ask voice questions and get accurate, contextual answers
- ✅ System is deployed on Render/Railway and accessible from anywhere
- ✅ All OAuth integrations configured and working
- ✅ Production data handled safely (review queue, no auto-send)
- ✅ Phase 2 Handoff Document generated with OPUS prompt for Phase 2

---

## CONSTRAINTS & PREFERENCES

- **Prioritize speed to deployment** over perfection - working system in 8-12 weeks
- **Full-featured for Phase 1** - all specified integrations and voice interface working
- Security can be enhanced post-launch (but don't be reckless)
- Must work within $500/month initial budget (should be plenty for Phase 1)
- Use MCP protocol for integrations where applicable
- Code should be maintainable, well-documented, and well-commented
- **Production data safety is critical** - review queue mandatory, no destructive actions

---

## IMPORTANT NOTES FOR OPUS

### Your Role & Authority
- **You are the technical architect** - make all technology decisions based on your expertise
- **Override this prompt freely** when you have better ideas
- **Choose your own stack** - the suggestions here are just starting points
- **Optimize for the goals**: 8-12 week delivery, $500/month budget, production reliability, user's needs

### Implementation Guidelines
- This script will be handed to **Claude Code (Sonnet 4.5)** for autonomous execution
- Be **extremely specific and detailed** - assume Claude Code is capable but needs complete instructions
- Include all necessary **API documentation references**
- Provide **example code** for complex integrations (OAuth flows, WebSocket voice, RAG retrieval)
- Think through **edge cases**: What if email OAuth fails? How to handle rate limits? What if voice STT returns gibberish?
- Claude Code should be able to execute steps **sequentially without asking questions**
- If something is ambiguous, provide a **sensible default** and note it in comments

### What's Fixed vs. Flexible
**FIXED (Don't change):**
- Functional requirements (all integrations, features, AI capabilities listed)
- Phase 1 vs Phase 2 scope (don't implement Phase 2 features now)
- Budget constraint ($500/month)
- Timeline goal (8-12 weeks)
- Production data safety (review queue, no auto-send)
- Use of Claude API as primary LLM

**FLEXIBLE (Your choice):**
- Technology stack (backend, frontend, database, hosting, etc.)
- Architecture patterns (monolithic vs. microservices, etc.)
- Specific tools and libraries
- Implementation approach for each feature
- Database schema (provided schema is just a suggestion)
- Development workflow

### Required Deliverables
- **Generate the Phase 2 Handoff Document** at the end with a complete OPUS prompt for Phase 2
- Full implementation script that Claude Code can execute
- Clear justification for your technology choices (helps user understand your decisions)

---

## BEGIN YOUR IMPLEMENTATION SCRIPT NOW

Structure it so Claude Code can execute it step-by-step to build the entire Phase 1 of DevinHub.

Focus on:
1. Clear, sequential steps
2. Complete code examples
3. Configuration templates
4. Testing procedures
5. Deployment instructions
6. Phase 2 handoff documentation

**You have a $500/month budget, 8-12 week timeline, and a user who needs this system to manage overwhelming information flow. Deliver Phase 1 that provides immediate, tangible value.**

Go! 🚀

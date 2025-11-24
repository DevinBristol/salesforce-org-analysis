# OPUS Task: Generate Complete Implementation Script for DevinHub

You are tasked with creating a **comprehensive, production-ready implementation script** for an AI-powered personal command center called "DevinHub". This script will be handed to Claude Code for autonomous execution. The system must be functional at launch with all features integrated.

## Project Owner Context
- Manages 25+ direct reports
- Receives hundreds of texts/week, constant emails, voicemails
- Uses CompanyCam for field operations
- Heavy Salesforce user
- Currently has NO project management system (critical weakness)
- Needs unified interface to capture, organize, prioritize, and respond to all inputs
- Wants to carry headset for always-on voice interaction

## System Requirements

### Core Functionality
DevinHub is an AI-powered hub that:
1. **Ingests** inputs from multiple channels simultaneously
2. **Organizes** all inputs into unified task/project management system
3. **Learns** user's communication style and maintains context on all contacts
4. **Assists** with drafting responses (email, SMS, Telegram)
5. **Proactively manages** user's attention and priorities
6. **Provides voice interface** for hands-free interaction
7. **Maintains memory** across all sessions and conversations

### Input Channels (All Must Be Integrated)
1. **iOS SMS/iMessage** - Incoming texts
2. **Email** - Multi-account (Gmail, Outlook, etc.)
3. **Calendar** - Google Calendar and Outlook Calendar (bi-directional sync)
4. **CompanyCam** - Webhook for @mentions and comments
5. **Telegram** - Messages and groups
6. **iOS Voicemails** - Transcription and processing
7. **Salesforce** - Tasks, opportunities, cases
8. **Voice Input** - User speaking ideas, todos, commands (via headset/phone)
9. **Manual Entry** - Web interface for direct input

### AI Capabilities & Intelligence

#### Context Management
- **Cross-session memory**: Remember all previous conversations, decisions, projects
- **Contact profiles**: Maintain detailed context for ALL contacts including:
  - Communication patterns and history
  - Associated projects and tasks
  - Organizational relationships
  - Individual preferences and context
  - Past interactions and outcomes
- **Project/topic tracking**: Link all inputs to relevant projects automatically
- **Communication style learning**: Analyze past emails/texts to draft responses that sound like the user

#### Natural Language Understanding
Voice/text input examples that must work:
- *"Remind me to follow up with Sarah about the CompanyCam integration next Tuesday at 2pm and add it to the Phoenix project"*
  - Parse: person (Sarah), topic (CompanyCam integration), date/time (next Tuesday 2pm), project (Phoenix)
  - Actions: Create calendar event, create task, link to project, associate with Sarah's profile

- *"What did John say about the Denver site yesterday?"*
  - Search: Contact (John), topic (Denver site), timeframe (yesterday)
  - Return: Summarized conversation with source links

- *"Draft a response to Lisa's email saying we'll handle it but need until Friday"*
  - Action: Generate email in user's style, set deadline, create reminder

#### Autonomous Behaviors (Modifiable Rules)
**Default settings** (user can modify per contact/channel):
- ✅ **Draft responses for review** (don't auto-send)
- ✅ **Classify and organize** all inputs automatically
- ✅ **Proactive suggestions** ("You haven't responded to Mike in 3 days about urgent CompanyCam issue")
- ✅ **Entity extraction and linking** (auto-associate with projects, people, dates)
- ❌ **Auto-send** (disabled by default, can enable for specific contacts/scenarios)

**Review Queue System**:
- Drafted responses wait in queue
- User can approve, edit, or reject
- Learn from edits to improve future drafts
- Configurable rules: "Auto-approve responses to [person] about [topic]"

### Voice Interface (CRITICAL FEATURE)

#### Two-Mode Voice System
1. **Conversational Assistant**:
   - User: "Hey DevinHub, what's urgent today?"
   - DevinHub: [Spoken] "You have 3 urgent items: Mike needs approval on CompanyCam budget by EOD, Sarah's waiting on Phoenix timeline, and you have an unread voicemail from the CFO."
   - User: "Tell me about Mike's request"
   - DevinHub: [Spoken] "Mike submitted a $15K equipment request for the Denver site. He mentioned it's blocking progress. Would you like me to pull up the details or draft a response?"
   - User: "Draft approval and cc Sarah"
   - DevinHub: "Done. Draft is in your review queue."

2. **Spoken Notifications with Voice Reply**:
   - DevinHub: [Interrupts] "Urgent: CompanyCam comment from site supervisor mentions safety issue at Phoenix location."
   - User: "Read it"
   - DevinHub: [Reads full comment]
   - User: "Add to urgent tasks and text Sarah to call me"
   - DevinHub: "Task created. Text drafted for your review."

#### Hardware Support
- **Primary**: iPhone (already owned) with Bluetooth headset
- **Wake word**: Preferred but not required initially (can start with push-to-talk)
- **Always-available**: Works from phone when headset not connected

### Project Management System (Build From Scratch)
User currently has NO PM system. Build integrated solution with:
- **Projects**: Group related tasks/communications
- **Tasks**: From all input channels, auto-categorized
- **Priorities**: AI-suggested based on urgency, relationships, deadlines
- **Timeline view**: Calendar integration
- **Dependencies**: Link tasks to each other
- **Context linking**: Every task links to relevant emails, texts, calls, CompanyCam comments
- **Voice interaction**: "Show me all Phoenix project tasks" → spoken summary + dashboard view

### Output Interfaces

#### Web Dashboard (Must Have)
- **Unified inbox**: All inputs from all channels in one view
- **Review queue**: Drafted responses awaiting approval
- **Project views**: Kanban, list, timeline, calendar
- **Contact profiles**: Click any person to see full context
- **Voice chat interface**: Web-based voice conversation with DevinHub
- **Analytics**: Communication patterns, response times, task completion

#### Real-time Notifications (Must Have)
- **Voice notifications**: Spoken alerts for urgent items (via headset/phone)
- **Visual**: Dashboard alerts
- **Configurable**: Set priorities for what triggers voice interruption vs. silent notification

#### Daily Digests
- **Morning briefing** (voice + email): "Here's your day..."
- **End-of-day summary**: Completed tasks, pending items, tomorrow's priorities
- **Weekly rollup**: Projects progress, communication stats

### Technical Implementation Requirements

#### Infrastructure & Hosting
- **Cloud hosting**: Render (user has experience) or better alternative if justified
- **Budget**: $500/month initial, can scale much higher for proven results
- **Always-on**: Must run 24/7 for real-time processing
- **Scalability**: Handle hundreds of daily inputs

#### Technology Stack (Your Recommendations)
You must specify:
- **Backend framework**: (FastAPI, Node.js, etc.)
- **Database**: PostgreSQL + Vector DB for semantic search (Supabase recommended for speed)
- **Voice processing**:
  - Speech-to-text (OpenAI Whisper, Deepgram, etc.)
  - Text-to-speech (ElevenLabs, OpenAI TTS, etc.)
  - Wake word detection (if implementing)
- **AI/LLM**:
  - Claude API (Opus for complex reasoning, Sonnet for speed/cost balance, Haiku for simple tasks)
  - Embedding model for semantic search
- **Frontend**:
  - Web dashboard (React, Next.js, etc.)
  - Mobile: **iOS app vs PWA** - you decide based on speed to deployment
- **Integration framework**: MCP (Model Context Protocol) servers for each input channel
- **Real-time**: WebSockets for live updates
- **Voice infrastructure**: How to handle always-on voice connection from iPhone/headset

#### Security & Authentication (Speed Priority)
- Favor **speed to deployment** over maximum security initially
- Implement OAuth flows for all integrations (Gmail, Outlook, Telegram, Salesforce, etc.)
- Secure credential storage
- Basic encryption for stored data
- **Note**: Can enhance security after initial deployment

#### Integration Specifications

Each integration must be fully specified with:

1. **iOS SMS/iMessage**:
   - How to access (iOS Shortcuts + webhook relay? Third-party API?)
   - Bi-directional (receive and send)

2. **Email** (Gmail, Outlook, others):
   - OAuth setup
   - Real-time inbox monitoring
   - Send capabilities
   - Thread tracking

3. **Calendar** (Google + Outlook):
   - OAuth for both
   - Bi-directional sync
   - Event creation from voice/text
   - Conflict detection

4. **CompanyCam**:
   - Webhook setup for @mentions
   - API access for posting comments
   - Media/photo handling

5. **Telegram**:
   - Bot setup
   - Message receiving and sending
   - Group message handling

6. **iOS Voicemail**:
   - Access method (visual voicemail API, carrier integration, manual upload?)
   - Transcription pipeline

7. **Salesforce**:
   - OAuth + Salesforce API
   - Tasks, opportunities, cases sync
   - Bi-directional updates

8. **Voice Input**:
   - iPhone microphone access
   - Bluetooth headset support
   - Streaming vs. batch audio processing
   - Real-time transcription

#### Database Schema
Provide complete schema including:
- **Contacts table**: All people, with context fields
- **Messages table**: Unified storage for all input types
- **Tasks table**: From all sources
- **Projects table**: User-created and AI-suggested
- **Responses table**: Drafted replies in review queue
- **Context/Memory table**: Vector embeddings for semantic search
- **Rules table**: User's modifiable automation rules
- **Interaction logs**: For learning communication style

### AI Orchestration Logic

#### Input Processing Pipeline
```
Input arrives (email, text, voice, etc.)
  ↓
1. Transcribe (if voice)
  ↓
2. Entity extraction (people, dates, projects, topics)
  ↓
3. Context enrichment (pull relevant history from vector DB)
  ↓
4. Classification (urgent? requires response? information only?)
  ↓
5. Action determination (create task? draft response? update project? calendar event?)
  ↓
6. Execution (perform actions, add to review queue if needed)
  ↓
7. Notification (voice alert if urgent, otherwise silent)
  ↓
8. Memory update (store in vector DB for future context)
```

#### Response Generation
- Use Claude Opus for complex/important responses
- Use Claude Sonnet for routine responses
- Include context from: past communications with person, related project info, user's style
- Present in review queue with confidence score
- Learn from user's edits

#### Voice Interaction Flow
- Continuous listening when headset connected (or push-to-talk if wake word not implemented)
- Real-time STT streaming
- Context-aware conversation (remember what was just discussed)
- Interrupt capability for urgent items
- Natural language command execution

### Mobile Strategy (You Decide)
**Options**:
1. **Native iOS app**: Better integration with iOS features (notifications, voice, etc.) but slower to deploy
2. **PWA (Progressive Web App)**: Faster deployment, works cross-platform, may have limitations with voice/notifications

**Your decision should prioritize**: Speed to deployment while maintaining core functionality (voice interface, notifications)

### Future Integration (Specify but Don't Implement Yet)
- **Devin Hub integration**: User has autonomous developer swarm, wants DevinHub to assign dev tasks
- Specify architecture for this but mark as Phase 2

### Deployment & Setup Instructions
Provide **step-by-step** instructions for:
1. Setting up cloud infrastructure
2. Deploying backend services
3. Configuring all OAuth integrations (with specific steps for each service)
4. Database setup and migration
5. Frontend deployment
6. Mobile app deployment (iOS App Store or PWA hosting)
7. Connecting voice services
8. Initial user onboarding flow
9. Testing checklist

### Monitoring & Maintenance
- Logging strategy
- Error alerting
- API usage monitoring (stay within budget)
- Performance metrics

## Your Deliverable

Generate a **complete implementation script** that includes:

### 1. Architecture Document
- System diagram
- Component breakdown
- Data flow
- Technology stack with justifications

### 2. Complete Code Structure
- Directory structure
- All MCP server implementations for each integration
- Backend API endpoints
- Database models and migrations
- Frontend components (dashboard, review queue, voice interface)
- Mobile app structure (iOS or PWA)
- AI orchestration service
- Voice processing pipeline

### 3. Configuration Files
- Docker/docker-compose for deployment
- Environment variables template
- OAuth configuration templates for each service
- Database connection config
- API keys and secrets management

### 4. Step-by-Step Implementation Guide
Numbered steps that Claude Code can follow autonomously:
1. Initialize project structure
2. Set up database
3. Implement MCP servers for each integration
4. Build backend API
5. Create frontend dashboard
6. Implement voice processing
7. Set up AI orchestration
8. Deploy to cloud
9. Configure integrations
10. Test end-to-end

### 5. Testing Strategy
- Integration tests for each input channel
- Voice interface testing
- AI response quality evaluation
- End-to-end scenarios

### 6. User Documentation
- How to use DevinHub
- Configuring automation rules
- Voice commands reference
- Review queue workflow

## Success Criteria

The implementation is successful when:
- ✅ All 8 input channels are receiving data in real-time
- ✅ User can speak to DevinHub via headset and have conversations
- ✅ Tasks auto-create from emails, texts, voice inputs with correct entity extraction
- ✅ Responses are drafted in user's style and appear in review queue
- ✅ Web dashboard shows unified view of all inputs
- ✅ Voice notifications work for urgent items
- ✅ Calendar events auto-create from voice commands
- ✅ System maintains context across sessions
- ✅ Can ask "What did [person] say about [topic]?" and get accurate answers
- ✅ System is deployed and running on cloud infrastructure
- ✅ User can access from iPhone and web browser

## Constraints & Preferences
- **Prioritize speed to deployment** over perfection
- **Full-featured at launch** (all integrations working, not MVP)
- Security can be enhanced post-launch
- Must work within $500/month initial budget (though can grow)
- Favor iPhone/existing hardware over requiring new purchases
- Use MCP protocol for integrations where applicable
- Code should be maintainable and well-documented

## Important Notes
- This script will be handed to Claude Code (Sonnet 4.5) for autonomous execution
- Be extremely specific and detailed - assume Claude Code is capable but needs complete instructions
- Include all necessary API documentation references
- Provide example code for complex integrations
- Think through edge cases (what if email OAuth fails? How to handle rate limits?)

Begin your implementation script now. Structure it so Claude Code can execute it step-by-step to build the entire DevinHub system.

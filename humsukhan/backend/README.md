# HumSukhan Backend

Production-ready FastAPI backend for the HumSukhan accessibility assistant.

## Architecture

```
FastAPI + PostgreSQL
├── Authentication (JWT)
├── Professional Sessions (CRUD)
├── Transcripts
├── AI Insights (OpenAI)
├── Export (TXT/PDF)
├── Retention Management
└── User Management
```

## Quick Start

### With Docker (Recommended)

```bash
docker-compose up -d
```

### Manual Setup

```bash
# Create virtual environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Set up environment
cp .env.example .env
# Edit .env with your settings

# Run the server
uvicorn app.main:app --reload
```

## API Documentation

- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc

## Endpoints

### Authentication
- `POST /api/v1/auth/register` - Create account
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/refresh` - Refresh token
- `GET /api/v1/auth/me` - Get profile
- `PUT /api/v1/auth/me` - Update profile

### Professional Sessions
- `GET /api/v1/professional/sessions` - List sessions
- `POST /api/v1/professional/sessions` - Create session
- `GET /api/v1/professional/sessions/:id` - Get session detail
- `PUT /api/v1/professional/sessions/:id` - Update session
- `DELETE /api/v1/professional/sessions/:id` - Delete session
- `POST /api/v1/professional/sessions/:id/captions` - Add caption
- `POST /api/v1/professional/sessions/:id/insights` - Generate AI insights
- `GET /api/v1/professional/sessions/:id/insights` - Get insights
- `GET /api/v1/professional/sessions/:id/export` - Export session

### Folders
- `GET /api/v1/professional/folders` - List folders
- `POST /api/v1/professional/folders` - Create folder
- `DELETE /api/v1/professional/folders/:id` - Delete folder

## Data Models

- **User** - User accounts with profile
- **ProfessionalSession** - Meetings, lectures, classes
- **Folder** - Session organization
- **Transcript** - Captions and text
- **ProfessionalInsight** - AI-generated analysis
- **RetentionPolicy** - Data retention rules
- **ExportRecord** - Export history

## Security

- JWT authentication
- bcrypt password hashing
- User data isolation
- TLS encryption (in production)
- No raw audio storage
- Production log sanitization

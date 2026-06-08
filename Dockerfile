# Multi-stage build for Azure Container App deployment
FROM node:18-alpine AS frontend-build

# Build frontend
WORKDIR /app/frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build:prod

# Python runtime stage
FROM python:3.11-slim

# ✅ Install ALL system dependencies including aiortc requirements
RUN apt-get update && apt-get install -y \
    # Basic tools
    curl \
    gcc \
    g++ \
    pkg-config \
    # FFmpeg libraries (required by aiortc)
    libavformat-dev \
    libavcodec-dev \
    libavdevice-dev \
    libavutil-dev \
    libswscale-dev \
    libswresample-dev \
    libavfilter-dev \
    # Audio/Video codecs
    libopus-dev \
    libvpx-dev \
    # WebRTC security
    libsrtp2-dev \
    libssl-dev \
    # Networking
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Install Python dependencies
COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Copy backend code
COPY backend/ ./

# Copy built frontend static files
COPY --from=frontend-build /app/frontend/dist ./static

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

EXPOSE 8000

# ✅ Direct command - no start.sh line ending issues
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--workers", "1"]
#!/bin/bash
# Local development run script for Django backend
# Usage: ./run_local.sh [--migrate] [--port PORT]

set -e

cd "$(dirname "$0")"

# Default port
PORT=8000
RUN_MIGRATIONS=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --migrate)
            RUN_MIGRATIONS=true
            shift
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--migrate] [--port PORT]"
            exit 1
            ;;
    esac
done

# Activate virtual environment if it exists
if [ -d ".venv" ]; then
    echo "Activating virtual environment..."
    source .venv/bin/activate
elif [ -d "venv" ]; then
    echo "Activating virtual environment..."
    source venv/bin/activate
else
    echo "⚠️  No virtual environment found. Using system Python."
fi

# Set local development mode
export LOCAL_DEV=true

# Load .env file if it exists
if [ -f "../.env" ]; then
    echo "Loading environment variables from .env file..."
    export $(cat ../.env | grep -v '^#' | xargs)
elif [ -f ".env" ]; then
    echo "Loading environment variables from .env file..."
    export $(cat .env | grep -v '^#' | xargs)
fi

# Check if SECRET_KEY is set
if [ -z "$SECRET_KEY" ]; then
    echo "⚠️  Warning: SECRET_KEY not set. Using default from local_settings.py"
fi

# Run migrations if requested
if [ "$RUN_MIGRATIONS" = true ]; then
    echo ""
    echo "Running migrations..."
    python manage.py migrate
    echo ""
fi

# Check if port is available
if lsof -Pi :$PORT -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo ""
    echo "❌ Error: Port $PORT is already in use."
    echo ""
    echo "Options:"
    echo "  1. Stop the process using port $PORT"
    echo "  2. Use a different port: ./run_local.sh --port 8080"
    echo ""
    echo "To find what's using the port:"
    echo "  lsof -i :$PORT"
    echo ""
    exit 1
fi

# Check Django configuration
echo ""
echo "Checking Django configuration..."
python manage.py check --deploy || echo "⚠️  Some deployment checks failed (this is OK for local dev)"

echo ""
echo "Starting Django development server with WebSocket support on http://0.0.0.0:$PORT"
echo "Using Daphne (ASGI) for WebSocket support"
echo "Press Ctrl+C to stop"
echo ""

# Check if daphne is available
if command -v daphne &> /dev/null || python -c "import daphne" 2>/dev/null; then
    # Run with Daphne (ASGI) for WebSocket support
    daphne -b 0.0.0.0 -p $PORT main.asgi:application
else
    echo "⚠️  Warning: Daphne not found. WebSockets will not work."
    echo "   Install with: pip install daphne"
    echo "   Falling back to runserver (no WebSocket support)"
    echo ""
    python manage.py runserver 0.0.0.0:$PORT
fi


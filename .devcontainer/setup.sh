#!/bin/bash
set -e

echo "🚀 Setting up Makerkit development environment..."

# Install PNPM
echo "📦 Installing PNPM..."
npm install -g pnpm

# Install Supabase CLI using recommended method
echo "📦 Installing Supabase CLI..."
curl -fsSL https://github.com/supabase/cli/releases/download/v2.75.0/supabase_linux_amd64.tar.gz | tar -xz -C /tmp
sudo mv /tmp/supabase /usr/local/bin/supabase
sudo chmod +x /usr/local/bin/supabase

# Get workspace directory (works for both /workspace and /workspaces)
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspaces/nextjs-saas-starter-kit-lite}"
if [ ! -d "$WORKSPACE_DIR" ]; then
  WORKSPACE_DIR="/workspace"
fi

# Install dependencies
echo "📦 Installing project dependencies..."
cd "$WORKSPACE_DIR"
pnpm install

# Get Codespace URLs and update config BEFORE starting Supabase
if [ -n "$CODESPACE_NAME" ]; then
  SUPABASE_URL="https://${CODESPACE_NAME}-54321.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
  SITE_URL="https://${CODESPACE_NAME}-3000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
  
  echo "🔧 Updating Supabase config for Codespaces..."
  cd "$WORKSPACE_DIR/apps/web"
  sed -i "s|site_url = \".*\"|site_url = \"${SITE_URL}\"|" supabase/config.toml
  sed -i "s|additional_redirect_urls = \[.*\]|additional_redirect_urls = [\"http://localhost:3000\", \"http://localhost:3000/auth/callback\", \"http://localhost:3000/update-password\", \"${SITE_URL}\", \"${SITE_URL}/auth/callback\", \"${SITE_URL}/update-password\"]|" supabase/config.toml
  cd "$WORKSPACE_DIR"
else
  SUPABASE_URL="http://127.0.0.1:54321"
  SITE_URL="http://localhost:3000"
fi

# Start Supabase
echo "🔧 Starting Supabase..."
pnpm run supabase:web:start &

# Wait for Supabase to be ready
echo "⏳ Waiting for Supabase to start..."
MAX_ATTEMPTS=60
ATTEMPT=0
while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  if pnpm --filter web supabase status > /dev/null 2>&1; then
    echo "✅ Supabase is ready!"
    break
  fi
  ATTEMPT=$((ATTEMPT + 1))
  echo "Waiting... ($ATTEMPT/$MAX_ATTEMPTS)"
  sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
  echo "❌ Supabase failed to start in time"
  exit 1
fi

# Extract keys from Supabase status
echo "🔑 Extracting Supabase keys..."
cd "$WORKSPACE_DIR/apps/web"
SUPABASE_STATUS=$(pnpm supabase status)

ANON_KEY=$(echo "$SUPABASE_STATUS" | grep "Publishable key:" | awk '{print $3}')
SERVICE_ROLE_KEY=$(echo "$SUPABASE_STATUS" | grep "Secret key:" | awk '{print $3}')

# Create .env.local
echo "📝 Creating .env.local..."
cat > .env.local << EOF
NEXT_PUBLIC_SITE_URL=${SITE_URL}
NEXT_PUBLIC_SUPABASE_URL=${SUPABASE_URL}
NEXT_PUBLIC_SUPABASE_ANON_KEY=${ANON_KEY}
SUPABASE_SERVICE_ROLE_KEY=${SERVICE_ROLE_KEY}
EOF

echo ""
echo "✅ Setup complete!"
echo ""
echo "🌐 Your URLs:"
echo "   App: ${SITE_URL}"
echo "   Supabase API: ${SUPABASE_URL}"
if [ -n "$CODESPACE_NAME" ]; then
  echo "   Supabase Studio: https://${CODESPACE_NAME}-54323.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
fi
echo ""
echo "🚀 Run 'pnpm run dev' to start the Next.js app"

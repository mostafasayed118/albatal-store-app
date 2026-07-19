#!/bin/bash
# ============================================================
# Al Batal Elite — Staging Deployment Script
# Run this after creating your Supabase project
# ============================================================

set -e

echo "🚀 Al Batal Elite — Staging Deployment"
echo "======================================="

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Install it first:"
    echo "   npm install -g supabase"
    exit 1
fi

# Check if .env.staging exists
if [ ! -f .env.staging ]; then
    echo "❌ .env.staging not found. Create it from .env.example"
    exit 1
fi

# Link to Supabase project
echo "📦 Linking to Supabase project..."
supabase link

# Apply migrations in order
echo "🗄️  Applying migrations..."
for migration in supabase/migrations/*.sql; do
    echo "   Applying: $(basename $migration)"
    supabase db push --linked
done

# Deploy Edge Functions
echo "⚡ Deploying Edge Functions..."
for func in supabase/functions/*/; do
    funcname=$(basename $func)
    echo "   Deploying: $funcname"
    supabase functions deploy $funcname
done

# Set Edge Function secrets
echo "🔑 Setting Edge Function secrets..."
echo "   Run these commands manually with your actual credentials:"
echo "   supabase secrets set PAYMOB_API_KEY=your-key"
echo "   supabase secrets set PAYMOB_INTEGRATION_ID=your-id"
echo "   supabase secrets set PAYMOB_HMAC_SECRET=your-secret"
echo "   supabase secrets set VODAFONE_CASH_MERCHANT_CODE=your-code"
echo "   supabase secrets set VODAFONE_CASH_API_KEY=your-key"

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Set Edge Function secrets in Supabase dashboard"
echo "2. Update .env.staging with your project URL and anon key"
echo "3. Run: flutter run"
echo "4. Execute verify_rls.sql in SQL Editor"
echo "5. Complete docs/acceptance-checklist.md"

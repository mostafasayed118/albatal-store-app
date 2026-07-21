#!/bin/bash
# ============================================================
# Al Batal Elite — Staging Deployment Script
# Run this after creating your Supabase project
# ============================================================

set -e

echo "Al Batal Elite — Staging Deployment"
echo "======================================="

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "ERROR: Supabase CLI not found. Install it first:"
    echo "   npm install -g supabase"
    exit 1
fi

# Check if .env.staging exists
if [ ! -f .env.staging ]; then
    echo "ERROR: .env.staging not found. Create it from .env.example"
    exit 1
fi

# Link to Supabase project
echo "Linking to Supabase project..."
supabase link

# Apply migrations in order
echo "Applying migrations..."
for migration in supabase/migrations/*.sql; do
    echo "   Applying: $(basename $migration)"
    supabase db push --linked
done

# Deploy Edge Functions (only active, non-deprecated functions)
echo "Deploying Edge Functions..."
ACTIVE_FUNCTIONS=(
    "checkout"
    "paymob-initiate"
    "paymob-callback"
    "cancel-expired-orders"
    "send-order-notification"
)

for funcname in "${ACTIVE_FUNCTIONS[@]}"; do
    echo "   Deploying: $funcname"
    supabase functions deploy "$funcname"
done

# Set Edge Function secrets
echo "Setting Edge Function secrets..."
echo "   Run these commands manually with your actual credentials:"
echo "   supabase secrets set PAYMOB_API_KEY=your-key"
echo "   supabase secrets set PAYMOB_INTEGRATION_ID=your-id"
echo "   supabase secrets set PAYMOB_IFRAME_ID=your-iframe-id"
echo "   supabase secrets set PAYMOB_HMAC_SECRET=your-secret"
echo "   supabase secrets set CANCEL_EXPIRED_ORDERS_SECRET=your-scheduler-secret"
echo "   supabase secrets set NOTIFICATIONS_INTERNAL_KEY=your-internal-key"

echo ""
echo "Deployment complete!"
echo ""
echo "Deployed functions:"
for funcname in "${ACTIVE_FUNCTIONS[@]}"; do
    echo "  - $funcname"
done
echo ""
echo "Deprecated functions enforced by CI deploy-check job."
echo ""
echo "Next steps:"
echo "1. Undeploy removed functions: supabase functions delete <name>"
echo "2. Set Edge Function secrets in Supabase dashboard"
echo "3. Update .env.staging with your project URL and anon key"
echo "4. Run: flutter run"
echo "5. Execute verify_rls.sql in SQL Editor"
echo "6. Complete docs/acceptance-checklist.md"

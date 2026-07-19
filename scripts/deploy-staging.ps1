# Al Batal Elite - Staging Deployment (PowerShell)
# Run from project root

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host " Al Batal Elite - Staging Deployment" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Check prerequisites
if (-not (Get-Command supabase -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: Supabase CLI not found. Install: npm install -g supabase" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path ".env.staging")) {
    Write-Host "ERROR: .env.staging not found. Copy .env.example to .env.staging" -ForegroundColor Red
    exit 1
}

# Step 1: Link
Write-Host "`n[1/4] Linking to Supabase project..." -ForegroundColor Yellow
supabase link

# Step 2: Apply migrations
Write-Host "`n[2/4] Applying migrations..." -ForegroundColor Yellow
supabase db push --linked

# Step 3: Deploy Edge Functions
Write-Host "`n[3/4] Deploying Edge Functions..." -ForegroundColor Yellow
$functions = @(
    "checkout",
    "paymob-auth",
    "paymob-order",
    "paymob-payment-key",
    "paymob-callback",
    "vodafone-cash-payment",
    "vodafone-cash-verify",
    "send-order-notification"
)

foreach ($func in $functions) {
    Write-Host "   Deploying: $func" -ForegroundColor Gray
    supabase functions deploy $func
}

# Step 4: Done
Write-Host "`n[4/4] Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Set Edge Function secrets in Supabase dashboard"
Write-Host "  2. Update .env.staging with your project URL and anon key"
Write-Host "  3. Run: flutter run"
Write-Host "  4. Execute verify_rls.sql in SQL Editor"
Write-Host "  5. Complete docs/acceptance-checklist.md"

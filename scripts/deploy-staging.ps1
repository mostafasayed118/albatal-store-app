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
Write-Host "`n[1/5] Linking to Supabase project..." -ForegroundColor Yellow
supabase link
if ($LASTEXITCODE -ne 0) {
    Write-Error "Supabase project linking failed."
    exit 1
}

# Step 2: Apply migrations
Write-Host "`n[2/5] Applying migrations..." -ForegroundColor Yellow
supabase db push --linked
if ($LASTEXITCODE -ne 0) {
    Write-Error "Migration push failed."
    exit 1
}

# Step 3: Verify required Edge Function secrets
Write-Host "`n[3/5] Verifying Edge Function secrets..." -ForegroundColor Yellow
$requiredSecrets = @(
    "CORS_ALLOWED_ORIGINS",
    "PAYMOB_API_KEY",
    "PAYMOB_INTEGRATION_ID",
    "PAYMOB_HMAC_SECRET",
    "PAYMOB_IFRAME_ID",
    "SCHEDULER_SECRET",
    "NOTIFICATIONS_INTERNAL_KEY",
    "INSTAPAY_MERCHANT_ADDRESS"
)
$secretsOutput = (& supabase secrets list 2>&1 | Out-String)
$missingSecrets = @($requiredSecrets | Where-Object {
    $secretsOutput -notmatch "(?m)(^|\s)$([regex]::Escape($_))(\s|$)"
})
if ($missingSecrets.Count -gt 0) {
    Write-Error "Missing required Edge Function secrets: $($missingSecrets -join ', ')"
    exit 1
}

# Step 4: Deploy Edge Functions (only active, non-deprecated functions)
Write-Host "`n[4/5] Deploying Edge Functions..." -ForegroundColor Yellow
$functions = @(
    "checkout",
    "paymob-initiate",
    "paymob-callback",
    "cancel-expired-orders",
    "send-order-notification",
    "delete-account",
    "instapay-initiate",
    "instapay-submit-proof",
    "instapay-review"
)

foreach ($func in $functions) {
    Write-Host "   Deploying: $func" -ForegroundColor Gray
    supabase functions deploy $func
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Edge Function deployment failed: $func"
        exit 1
    }
}

# Step 5: Done
Write-Host "`n[5/5] Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Deployed functions:" -ForegroundColor Cyan
foreach ($func in $functions) {
    Write-Host "  - $func" -ForegroundColor Gray
}
Write-Host ""
Write-Host "Deprecated functions enforced by CI deploy-check job." -ForegroundColor DarkGray
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Verify secrets remain configured in Supabase dashboard"
Write-Host "  2. Undeploy removed functions: supabase functions delete <name>"
Write-Host "  3. Update .env.staging with your project URL and anon key"
Write-Host "  4. Run: flutter run"
Write-Host "  5. Execute verify_rls.sql in SQL Editor"
Write-Host "  6. Complete docs/acceptance-checklist.md"

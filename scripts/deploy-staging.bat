@echo off
REM Al Batal Elite - Staging Deployment Script (Windows)

echo =======================================
echo  Al Batal Elite - Staging Deployment
echo =======================================

REM Check if Supabase CLI is installed
where supabase >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Supabase CLI not found. Install it first:
    echo    npm install -g supabase
    exit /b 1
)

REM Check if .env.staging exists
if not exist .env.staging (
    echo ERROR: .env.staging not found. Create it from .env.example
    exit /b 1
)

REM Link to Supabase project
echo [1/4] Linking to Supabase project...
supabase link

REM Apply migrations
echo [2/4] Applying migrations...
supabase db push --linked

REM Deploy Edge Functions
echo [3/4] Deploying Edge Functions...
supabase functions deploy checkout
supabase functions deploy paymob-auth
supabase functions deploy paymob-order
supabase functions deploy paymob-payment-key
supabase functions deploy paymob-callback
supabase functions deploy vodafone-cash-payment
supabase functions deploy vodafone-cash-verify
supabase functions deploy send-order-notification

REM Done
echo.
echo [4/4] Deployment complete!
echo.
echo Next steps:
echo 1. Set Edge Function secrets in Supabase dashboard
echo 2. Update .env.staging with your project URL and anon key
echo 3. Run: flutter run
echo 4. Execute verify_rls.sql in SQL Editor
echo 5. Complete docs/acceptance-checklist.md

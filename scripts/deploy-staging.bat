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

REM Deploy Edge Functions (only active, non-deprecated functions)
echo [3/4] Deploying Edge Functions...
supabase functions deploy checkout
supabase functions deploy paymob-initiate
supabase functions deploy paymob-callback
supabase functions deploy cancel-expired-orders
supabase functions deploy send-order-notification

REM Done
echo.
echo [4/4] Deployment complete!
echo.
echo Deployed functions:
echo   - checkout
echo   - paymob-initiate
echo   - paymob-callback
echo   - cancel-expired-orders
echo   - send-order-notification
echo.
echo REMOVED (deprecated/insecure):
echo   - paymob-order (leaked auth tokens)
echo   - paymob-auth (leaked auth tokens)
echo   - paymob-payment-key (accepted client auth_token)
echo   - vodafone-cash-payment (obsolete)
echo   - vodafone-cash-verify (obsolete)
echo.
echo Next steps:
echo 1. Undeploy removed functions: supabase functions delete ^<name^>
echo 2. Set Edge Function secrets in Supabase dashboard
echo 3. Update .env.staging with your project URL and anon key
echo 4. Run: flutter run
echo 5. Execute verify_rls.sql in SQL Editor
echo 6. Complete docs/acceptance-checklist.md

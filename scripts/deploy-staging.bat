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
echo [1/5] Linking to Supabase project...
supabase link
if errorlevel 1 (
    echo ERROR: Supabase project linking failed.
    exit /b 1
)

REM Apply migrations
echo [2/5] Applying migrations...
supabase db push --linked
if errorlevel 1 (
    echo ERROR: Migration push failed.
    exit /b 1
)

REM Verify required Edge Function secrets
echo [3/5] Verifying Edge Function secrets...
for %%S in (CORS_ALLOWED_ORIGINS PAYMOB_API_KEY PAYMOB_INTEGRATION_ID PAYMOB_HMAC_SECRET PAYMOB_IFRAME_ID SCHEDULER_SECRET NOTIFICATIONS_INTERNAL_KEY INSTAPAY_MERCHANT_ADDRESS) do (
    supabase secrets list | findstr /R /C:"^ *%%S " >nul
    if errorlevel 1 (
        echo ERROR: missing required Edge Function secret: %%S
        exit /b 1
    )
)

REM Deploy Edge Functions (only active, non-deprecated functions)
echo [4/5] Deploying Edge Functions...
supabase functions deploy checkout
if errorlevel 1 exit /b 1
supabase functions deploy paymob-initiate
if errorlevel 1 exit /b 1
supabase functions deploy paymob-callback
if errorlevel 1 exit /b 1
supabase functions deploy cancel-expired-orders
if errorlevel 1 exit /b 1
supabase functions deploy send-order-notification
if errorlevel 1 exit /b 1
supabase functions deploy delete-account
if errorlevel 1 exit /b 1
supabase functions deploy instapay-initiate
if errorlevel 1 exit /b 1
supabase functions deploy instapay-submit-proof
if errorlevel 1 exit /b 1
supabase functions deploy instapay-review
if errorlevel 1 exit /b 1

REM Done
echo.
echo [5/5] Deployment complete!
echo.
echo Deployed functions:
echo   - checkout
echo   - paymob-initiate
echo   - paymob-callback
echo   - cancel-expired-orders
echo   - send-order-notification
echo   - delete-account
echo   - instapay-initiate
echo   - instapay-submit-proof
echo   - instapay-review
echo.
echo Deprecated functions enforced by CI deploy-check job.
echo.
echo Next steps:
echo 1. Undeploy removed functions: supabase functions delete ^<name^>
echo 2. Verify Edge Function secrets remain configured in Supabase dashboard
echo 3. Update .env.staging with your project URL and anon key
echo 4. Run: flutter run
echo 5. Execute verify_rls.sql in SQL Editor
echo 6. Complete docs/acceptance-checklist.md

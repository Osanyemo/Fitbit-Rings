# Fitbit Rings

Native iOS dashboard for daily Fitbit progress from Google Health.

## Local Setup

1. Open `FitbitRings.xcodeproj` in Xcode 15 or newer.
2. Create an iOS OAuth client in Google Cloud.
3. Set these build settings for the app target:
   - `GOOGLE_CLIENT_ID`
   - `REVERSED_GOOGLE_CLIENT_ID`
4. Add the Google Health OAuth scopes to the consent screen:
   - `https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly`
   - `https://www.googleapis.com/auth/googlehealth.health_metrics_and_measurements.readonly`
   - `https://www.googleapis.com/auth/googlehealth.sleep.readonly`

The repo intentionally does not include a backend or client secret. Public release requires Google restricted-scope app verification.

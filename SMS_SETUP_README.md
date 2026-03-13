# Neural Gate - Hands-Free SOS SMS Setup

## Overview
Your Neural Gate app now sends SMS automatically when brain signals exceed the threshold, without requiring any user interaction.

## How It Works
- When your focus power exceeds the threshold, the app sends an HTTP request to a backend service
- The backend service then sends the actual SMS using Twilio
- This approach is more reliable than sending SMS directly from the mobile app

## Setup Instructions

### 1. Backend Service Setup
You'll need to set up a simple backend service to handle SMS sending. Here's how:

#### Option A: Use the Provided Example
1. Install Node.js if you haven't already
2. Create a new directory for your backend: `mkdir neural-gate-sms-service`
3. Copy `sms_backend_example.js` to that directory
4. Run `npm init -y` to create package.json
5. Install dependencies: `npm install express twilio`
6. Sign up for [Twilio](https://www.twilio.com/) and get your credentials
7. Update the credentials in `sms_backend_example.js`:
   ```javascript
   const accountSid = 'your_actual_account_sid';
   const authToken = 'your_actual_auth_token';
   const twilioPhoneNumber = 'your_twilio_phone_number';
   ```
8. Run the server: `node sms_backend_example.js`
9. Deploy to a hosting service (Heroku, Railway, etc.) or run on your local network

#### Option B: Use Other SMS Services
You can modify the backend to use:
- AWS SNS
- Firebase Cloud Functions
- Google Cloud Functions
- Any SMS gateway API

### 2. Update Flutter App
In your Flutter app, update the endpoint URL in `main.dart`:

```dart
Uri.parse('https://your-deployed-backend-url.com/send-sms')
```

Replace `https://your-backend-service.com/send-sms` with your actual backend URL.

### 3. Phone Number
Update the phone number in both `triggerSOS()` and `handleBrainTrigger()` functions:
```dart
'phone': '91XXXXXXXXXX', // Replace with actual phone number
```

## Features
- **Manual SOS**: Tap the SOS button to send emergency SMS
- **Brain-Triggered SOS**: Automatically sends SMS when focus exceeds threshold (when "Phone" target is selected)
- **Fallback**: If backend fails, falls back to opening SMS app
- **Logging**: Console logs for debugging

## Security Notes
- Never commit Twilio credentials to version control
- Use environment variables for sensitive data
- Consider adding authentication to your backend endpoint
- Rate limiting to prevent abuse

## Testing
1. Test with low threshold values first
2. Monitor console logs for debugging
3. Test both manual and brain-triggered SMS sending

## Cost
Twilio charges per SMS sent. Check their pricing at https://www.twilio.com/sms/pricing
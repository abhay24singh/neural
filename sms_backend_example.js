const express = require('express');
const twilio = require('twilio'); // You'll need to install twilio: npm install twilio

const app = express();
app.use(express.json());

// Twilio credentials (replace with your own)
const accountSid = 'your_twilio_account_sid';
const authToken = 'your_twilio_auth_token';
const twilioPhoneNumber = 'your_twilio_phone_number';

const client = twilio(accountSid, authToken);

// CORS middleware for Flutter app
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept, Accept');
  next();
});

// SMS sending endpoint
app.post('/send-sms', async (req, res) => {
  try {
    const { phone, message, source } = req.body;

    console.log(`Sending SMS to ${phone} from source: ${source}`);

    // Send SMS using Twilio
    const smsResponse = await client.messages.create({
      body: message,
      from: twilioPhoneNumber,
      to: phone
    });

    console.log('SMS sent successfully:', smsResponse.sid);
    res.status(200).json({
      success: true,
      messageId: smsResponse.sid,
      status: 'sent'
    });

  } catch (error) {
    console.error('Error sending SMS:', error);
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`SMS service running on port ${PORT}`);
  console.log('Make sure to:');
  console.log('1. Install twilio: npm install twilio');
  console.log('2. Set your Twilio credentials');
  console.log('3. Update the endpoint URL in your Flutter app');
});
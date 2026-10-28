const fs = require('fs');

const copy = {
  en: {
    report_saved_device_sign_in:
      'This report is saved on this device and is not queued for cloud upload. Sign in before submitting a new report to send it to the HealthMate team.',
    report_pending_note:
      'This report is saved on this device. Cloud submission is not confirmed.',
  },
  hi: {
    report_saved_device_sign_in:
      'यह रिपोर्ट इस डिवाइस पर सहेजी गई है और क्लाउड पर अपलोड के लिए कतार में नहीं है। टीम को भेजने के लिए साइन इन करके नई रिपोर्ट जमा करें।',
    report_pending_note:
      'यह रिपोर्ट इस डिवाइस पर सहेजी गई है। क्लाउड पर जमा होने की पुष्टि नहीं हुई है।',
  },
  mr: {
    report_saved_device_sign_in:
      'हा अहवाल या डिव्हाइसवर जतन केला आहे आणि क्लाउडवर अपलोडसाठी रांगेत नाही. टीमला पाठवण्यासाठी साइन इन करून नवीन अहवाल सबमिट करा.',
    report_pending_note:
      'हा अहवाल या डिव्हाइसवर जतन केला आहे. क्लाउडवर सबमिट झाल्याची पुष्टी झालेली नाही.',
  },
  bn: {
    report_saved_device_sign_in:
      'এই রিপোর্টটি এই ডিভাইসে সংরক্ষিত আছে এবং ক্লাউডে আপলোডের জন্য অপেক্ষমাণ নয়। দলের কাছে পাঠাতে সাইন ইন করে নতুন রিপোর্ট জমা দিন।',
    report_pending_note:
      'এই রিপোর্টটি এই ডিভাইসে সংরক্ষিত আছে। ক্লাউডে জমা হওয়ার নিশ্চিতকরণ হয়নি।',
  },
  gu: {
    report_saved_device_sign_in:
      'આ રિપોર્ટ આ ડિવાઇસ પર સાચવેલ છે અને ક્લાઉડ પર અપલોડ માટે કતારમાં નથી. ટીમને મોકલવા માટે સાઇન ઇન કરીને નવો રિપોર્ટ સબમિટ કરો.',
    report_pending_note:
      'આ રિપોર્ટ આ ડિવાઇસ પર સાચવેલ છે. ક્લાઉડ પર સબમિટ થયાની પુષ્ટિ થઈ નથી.',
  },
  ta: {
    report_saved_device_sign_in:
      'இந்த அறிக்கை இந்தச் சாதனத்தில் சேமிக்கப்பட்டுள்ளது; கிளவுட்டில் பதிவேற்ற வரிசையில் இல்லை. குழுவுக்கு அனுப்ப, உள்நுழைந்து புதிய அறிக்கையைச் சமர்ப்பிக்கவும்.',
    report_pending_note:
      'இந்த அறிக்கை இந்தச் சாதனத்தில் சேமிக்கப்பட்டுள்ளது. கிளவுட்டில் சமர்ப்பிக்கப்பட்டது உறுதிசெய்யப்படவில்லை.',
  },
};

for (const [locale, values] of Object.entries(copy)) {
  const file = `lib/l10n/intl_${locale}.arb`;
  const json = JSON.parse(fs.readFileSync(file, 'utf8'));
  Object.assign(json, values);
  fs.writeFileSync(file, JSON.stringify(json, null, 2) + '\n', 'utf8');
  console.log(`Updated ${locale}`);
}

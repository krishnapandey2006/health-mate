const fs = require('fs');

const vaccinePath = 'lib/services/vaccine_service.dart';
let vaccine = fs.readFileSync(vaccinePath, 'utf8');
vaccine = vaccine
  .replace(/9[^0-9]{1,4}12 months/g, '9–12 months')
  .replace(/16[^0-9]{1,4}24 months/g, '16–24 months')
  .replace(/5[^0-9]{1,4}6 years/g, '5–6 years')
  .replace(/9[^0-9]{1,4}14 years/g, '9–14 years')
  .replace(/missed [^ ]+ check/g, 'missed — check');
fs.writeFileSync(vaccinePath, vaccine, 'utf8');

const newsPath = 'lib/health_news_screen.dart';
let news = fs.readFileSync(newsPath, 'utf8');
news = news.replace(/'A[^']* \$\{formatShortDate/, "'• \${formatShortDate");
fs.writeFileSync(newsPath, news, 'utf8');

console.log('Encoding cleanup complete.');

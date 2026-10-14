const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, 'www', 'index.html');
const destDir = path.join(__dirname, 'ios', 'App', 'App', 'public');
const dest = path.join(destDir, 'index.html');

if (fs.existsSync(src)) {
  if (!fs.existsSync(destDir)) {
    fs.mkdirSync(destDir, { recursive: true });
  }
  fs.copyFileSync(src, dest);
  console.log('✓ Successfully synced www/index.html -> ios/App/App/public/index.html');
} else {
  console.log('ℹ No www/index.html to sync; pure native SwiftUI architecture active.');
}


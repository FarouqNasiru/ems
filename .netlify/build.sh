#!/bin/bash

# 1. Install Flutter
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable
fi
export PATH="$PATH:`pwd`/flutter/bin"

# 2. Recreate .env file from Netlify Environment Variables
echo "FIREBASE_API_KEY=$FIREBASE_API_KEY" > .env

# 3. Build Web
flutter build web --release

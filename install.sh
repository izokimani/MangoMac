#!/bin/bash

#  install.sh
#  AI-Vision (v3 - Patched)
#
#  Created by Gemini on 8/2/2025.
#  Copyright © 2025 Gemini. All rights reserved.
#
#  This script performs a comprehensive installation of the AI-Vision tool,
#  including dependencies, local AI models, and application scripts.

echo "🚀 Starting AI-Vision Installation (v3)..."
echo "This process will install several tools and may ask for your password."

# --- Ensure Homebrew is Installed ---
if ! command -v brew &> /dev/null; then
    echo "🍺 Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "✅ Homebrew is already installed."
fi

# --- Install Core Dependencies with Homebrew ---
# Added cmake for whisper.cpp compilation
echo "📦 Installing core dependencies (Tesseract, Python, FFmpeg, CMake)..."
brew install tesseract python ffmpeg cmake

# --- Install Python Libraries ---
# Added --break-system-packages to handle the externally-managed-environment error
echo "🐍 Installing necessary Python libraries..."
pip3 install --break-system-packages openai pillow pytesseract sounddevice scipy

# --- Set Up Secure API Key ---
echo "🔑 Please enter your actual OpenAI API key and press Enter."
printf "OpenAI API Key: "
read -sp OPENAI_API_KEY
echo

# Determine the correct shell profile file
PROFILE_FILE="$HOME/.zshrc"
if [ ! -f "$PROFILE_FILE" ]; then
    PROFILE_FILE="$HOME/.bash_profile"
    if [ ! -f "$PROFILE_FILE" ]; then
        PROFILE_FILE="$HOME/.profile"
    fi
fi

echo "🔐 Adding API key to your shell profile: $PROFILE_FILE"
# Add the export command to the profile file, ensuring it's not duplicated
grep -qF "export OPENAI_API_KEY" "$PROFILE_FILE" || echo "export OPENAI_API_KEY='$OPENAI_API_KEY'" >> "$PROFILE_FILE"
export OPENAI_API_KEY=$OPENAI_API_KEY

# --- Setup Application Directory ---
APP_DIR="$HOME/AI-Vision"
echo "📁 Creating application directory at $APP_DIR..."
mkdir -p "$APP_DIR"

# --- Install Local Whisper (whisper.cpp) ---
echo "🎤 Installing local speech-to-text model (Whisper.cpp)..."
cd "$APP_DIR"
if [ -d "whisper.cpp" ]; then
    echo "   - whisper.cpp directory already exists. Pulling latest changes."
    cd whisper.cpp
    git pull
else
    git clone https://github.com/ggerganov/whisper.cpp.git
    cd whisper.cpp
fi

# Compile the whisper.cpp code using cmake
echo "   - Compiling whisper.cpp..."
cmake -B build
cmake --build build -j

# Download a pre-trained model
MODEL="base.en"
echo "   - Downloading Whisper model ($MODEL)..."
if [ ! -f "models/ggml-$MODEL.bin" ]; then
    ./models/download-ggml-model.sh $MODEL
else
    echo "   - Model ggml-$MODEL.bin already downloaded."
fi
echo "✅ Local Whisper installation complete."


# --- Download Application Scripts ---
# Corrected the paths to download from the root of the repository
echo "⬇️ Downloading application scripts from GitHub..."
curl -L "https://raw.githubusercontent.com/izokimani/MangoMac/main/main.swift" -o "$APP_DIR/main.swift"
curl -L "https://raw.githubusercontent.com/izokimani/MangoMac/main/ai_vision_core.py" -o "$APP_DIR/ai_vision_core.py"


# --- Create and Load LaunchAgent ---
PLIST_PATH="$HOME/Library/LaunchAgents/com.gemini.aivision.plist"
echo "⚙️ Creating system service (LaunchAgent) to run on login..."

FULL_PATH=$(/usr/bin/env bash -c 'echo $PATH')

cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.gemini.aivision</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/bin/swift</string>
        <string>$APP_DIR/main.swift</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
    </dict>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>$FULL_PATH:/opt/homebrew/bin</string>
        <key>OPENAI_API_KEY</key>
        <string>$OPENAI_API_KEY</string>
    </dict>
    <key>StandardOutPath</key>
    <string>$APP_DIR/aivision.log</string>
    <key>StandardErrorPath</key>
    <string>$APP_DIR/aivision.error.log</string>
</dict>
</plist>
EOF

# --- Load the Service ---
echo "▶️ Starting AI-Vision service..."
launchctl load "$PLIST_PATH"

echo "✅🎉 Installation Complete! The AI-Vision icon should appear in your menu bar shortly."
echo "If it doesn't appear, try logging out and back into your Mac."

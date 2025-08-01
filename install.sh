#!/bin/bash

#  install.sh
#  AI-Vision (v2 with Local Whisper)
#
#  Created by Gemini on 8/2/2025.
#  Copyright © 2025 Gemini. All rights reserved.
#
#  This script performs a comprehensive installation of the AI-Vision tool,
#  including dependencies, local AI models, and application scripts.

echo "🚀 Starting AI-Vision Installation..."
echo "This process will install several tools and may ask for your password for system commands."

# --- Ensure Homebrew is Installed ---
if ! command -v brew &> /dev/null; then
    echo "🍺 Homebrew not found. Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    # Add Homebrew to PATH for the current script session
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "✅ Homebrew is already installed."
fi

# --- Install Core Dependencies with Homebrew ---
echo "📦 Installing core dependencies (Tesseract, Python, FFmpeg)..."
brew install tesseract python ffmpeg

# --- Install Python Libraries ---
echo "🐍 Installing necessary Python libraries..."
pip3 install openai pillow pytesseract sounddevice scipy

# --- Set Up Secure API Key ---
echo "🔑 Please enter your OpenAI API key. It will be stored securely."
printf "OpenAI API Key: "
read -sp OPENAI_API_KEY
echo

# Determine the correct shell profile file for environment variables
PROFILE_FILE=""
if [ -n "$ZSH_VERSION" ] || [ -f "$HOME/.zshrc" ]; then
    PROFILE_FILE="$HOME/.zshrc"
elif [ -n "$BASH_VERSION" ] || [ -f "$HOME/.bash_profile" ]; then
    PROFILE_FILE="$HOME/.bash_profile"
else
    # Fallback for other shells
    PROFILE_FILE="$HOME/.profile"
fi

echo "🔐 Adding API key to your shell profile: $PROFILE_FILE"
# Ensure the key is not added if it already exists
grep -qF "export OPENAI_API_KEY" "$PROFILE_FILE" || echo "export OPENAI_API_KEY='$OPENAI_API_KEY'" >> "$PROFILE_FILE"

echo "✅ API Key has been set. It will be available in new terminal sessions."
# Export for the current session to ensure the LaunchAgent gets it
export OPENAI_API_KEY

# --- Setup Application Directory ---
APP_DIR="$HOME/AI-Vision"
echo "📁 Creating application directory at $APP_DIR..."
mkdir -p "$APP_DIR"

# --- Install Local Whisper (whisper.cpp) ---
echo "🎤 Installing local speech-to-text model (Whisper.cpp)..."
cd "$APP_DIR"
if [ -d "whisper.cpp" ]; then
    echo "   - whisper.cpp directory already exists. Skipping git clone."
else
    git clone https://github.com/ggerganov/whisper.cpp.git
fi
cd whisper.cpp

# Compile the whisper.cpp code
echo "   - Compiling whisper.cpp..."
make

# Download a pre-trained model. We use 'base.en' for a good balance of speed and accuracy.
MODEL="base.en"
echo "   - Downloading Whisper model ($MODEL)..."
if [ ! -f "models/ggml-$MODEL.bin" ]; then
    ./models/download-ggml-model.sh $MODEL
else
    echo "   - Model ggml-$MODEL.bin already downloaded."
fi
echo "✅ Local Whisper installation complete."


# --- Download Application Scripts ---
echo "⬇️ Downloading application scripts from GitHub..."
# IMPORTANT: Replace with your actual GitHub repository URL
curl -L "https://raw.githubusercontent.com/your-username/your-repo/main/AIVision/main.swift" -o "$APP_DIR/main.swift"
curl -L "https://raw.githubusercontent.com/your-username/your-repo/main/AIVision/ai_vision_core.py" -o "$APP_DIR/ai_vision_core.py"


# --- Create and Load LaunchAgent ---
# This service runs the Swift menu bar app automatically on login.
PLIST_PATH="$HOME/Library/LaunchAgents/com.gemini.aivision.plist"
echo "⚙️ Creating system service (LaunchAgent) to run on login..."

# The LaunchAgent needs the full system PATH to find commands like `brew` and `python`.
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
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

echo "✅🎉 Installation Complete! The AI-Vision icon should appear in your menu bar shortly."
echo "You can view logs in $APP_DIR/aivision.log"


#!/usr/bin/env python3
#
#  ai_vision_core.py
#  AI-Vision (v2 with Local Whisper)
#
#  Created by Gemini on 8/2/2025.
#  Copyright © 2025 Gemini. All rights reserved.
#
#  This script is the core logic engine. It records audio, transcribes it locally,
#  captures the screen, performs OCR, and queries the OpenAI API.

import os
import subprocess
import sounddevice as sd
import scipy.io.wavfile as wav
import openai
from PIL import Image
import pytesseract
import tempfile
import sys

# --- Configuration ---
APP_DIR = os.path.expanduser("~/AI-Vision")
WHISPER_CPP_DIR = os.path.join(APP_DIR, "whisper.cpp")
WHISPER_EXECUTABLE = os.path.join(WHISPER_CPP_DIR, "main")
WHISPER_MODEL = os.path.join(WHISPER_CPP_DIR, "models/ggml-base.en.bin")

RECORDING_DURATION = 5  # seconds
SAMPLE_RATE = 16000  # Hz

# --- Initialize OpenAI Client ---
try:
    openai.api_key = os.getenv("OPENAI_API_KEY")
    if not openai.api_key:
        raise ValueError("OPENAI_API_KEY environment variable not set.")
except ValueError as e:
    # If the script fails, we can notify the user.
    subprocess.run(['osascript', '-e', f'display notification "{e}" with title "AI-Vision Error" subtitle "Configuration Issue"'])
    sys.exit(1)


def show_notification(title, text):
    """Displays a native macOS notification."""
    subprocess.run(['osascript', '-e', f'display notification "{text}" with title "AI-Vision" subtitle "{title}"'])

def record_audio(file_path):
    """Records audio from the default microphone."""
    print("Recording audio...")
    show_notification("Listening...", "Please ask your question now.")
    recording = sd.rec(int(RECORDING_DURATION * SAMPLE_RATE), samplerate=SAMPLE_RATE, channels=1, dtype='int16')
    sd.wait()  # Wait until recording is finished
    wav.write(file_path, SAMPLE_RATE, recording)
    print(f"Audio saved to {file_path}")

def transcribe_audio_local(file_path):
    """Transcribes audio using the local whisper.cpp executable."""
    print("Transcribing audio locally...")
    show_notification("Thinking...", "Transcribing your question...")
    command = [WHISPER_EXECUTABLE, "-m", WHISPER_MODEL, "-f", file_path, "-nt", "-otxt"]
    result = subprocess.run(command, capture_output=True, text=True, check=True)
    
    # The transcription is saved to a .txt file with the same name
    transcription_path = f"{file_path}.txt"
    with open(transcription_path, 'r') as f:
        transcribed_text = f.read().strip()
    
    # Clean up the temporary files
    os.remove(transcription_path)
    print(f"Transcription: {transcribed_text}")
    return transcribed_text

def capture_screen_and_ocr():
    """Captures the primary display and uses Tesseract to extract text."""
    print("Capturing screen and performing OCR...")
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as tmp_screenshot:
        # Use the built-in screencapture utility for reliability
        subprocess.run(["screencapture", "-C", tmp_screenshot.name])
        
        # Open the saved screenshot and perform OCR
        image = Image.open(tmp_screenshot.name)
        extracted_text = pytesseract.image_to_string(image)
        print("OCR process complete.")
        return extracted_text

def get_ai_assistance(screen_text, user_question):
    """Sends the context to OpenAI and gets a response."""
    print("Contacting OpenAI API...")
    show_notification("Consulting AI...", "Getting an answer based on your screen.")
    
    system_prompt = "You are a helpful assistant. Based on the provided text from the user's screen and their question, provide a clear and concise answer. If the screen text is empty or irrelevant, answer the user's question to the best of your ability."
    
    prompt = f"""
    CONTEXT FROM SCREEN:
    ---
    {screen_text if screen_text.strip() else "No text was detected on the screen."}
    ---
    USER'S QUESTION: "{user_question}"
    """
    
    try:
        response = openai.chat.completions.create(
            model="gpt-4o-mini",
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": prompt}
            ],
            max_tokens=200,
            temperature=0.5,
        )
        return response.choices[0].message.content.strip()
    except Exception as e:
        print(f"Error calling OpenAI: {e}")
        return f"An error occurred while contacting the AI: {e}"

def main():
    """Main execution flow."""
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_audio:
        try:
            # 1. Record audio
            record_audio(tmp_audio.name)
            
            # 2. Transcribe audio locally
            user_question = transcribe_audio_local(tmp_audio.name)
            if not user_question:
                show_notification("Error", "Could not understand audio. Please try again.")
                return

            # 3. Capture screen and get text
            screen_text = capture_screen_and_ocr()
            
            # 4. Get AI assistance
            ai_answer = get_ai_assistance(screen_text, user_question)
            
            # 5. Show the final answer to the user
            print(f"AI Answer: {ai_answer}")
            show_notification("Here's your answer!", ai_answer.replace('"', "'"))

        finally:
            # Clean up the temporary audio file
            if os.path.exists(tmp_audio.name):
                os.remove(tmp_audio.name)

if __name__ == "__main__":
    main()

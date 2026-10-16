<p align="center">
  <img src="verification/icon/Default.png" width="180" alt="Minutes app icon">
</p>

<h1 align="center">Minutes</h1>

<p align="center">
  A native macOS app for recording meetings and transcribing them locally.
</p>

## Build

Requires macOS 15 or later, Apple Silicon, and full Xcode with Swift 6 and Icon Composer.

```sh
bash scripts/swift-local.sh test
bash scripts/build-app.sh release
open dist/Minutes.app
```

## Use

1. Select your browser and click **Start Recording**, or import existing audio.
2. Click **Stop & Transcribe** to create a transcript with speaker labels.
3. Click any word to listen, name speakers, and export Markdown.

Models download automatically on first use. Recordings and transcription stay on your Mac. Optional ChatGPT summaries send transcript text and speaker names to OpenAI.

Settings include saved speakers, calendar meeting reminders, an export folder, and automatic model unloading.


## Meeting summaries

Open **Settings → Summaries**, choose **Sign In**, and approve access in your browser. Minutes uses your eligible ChatGPT plan; no API key or Codex installation is needed. Choose a model from your account's available models, then enable **Automatically summarize transcripts** to generate summaries after transcription and when exporting a meeting without a current summary.

Summaries are saved with each meeting and included above the transcript in Markdown exports and shared Markdown files. Click **Summarize** above any transcript to generate a summary or expand and collapse an existing one. Right-click **Summarize** and choose **Regenerate Summary** to replace it. Changing transcript content or speaker names hides an outdated summary until it is regenerated. Summary failures leave the saved transcript and existing export intact.

Automatic summaries are off by default. Audio is never uploaded for summarization. ChatGPT credentials are stored in macOS Keychain; you can sign in or sign out in Settings. ChatGPT plan availability and usage limits apply. Review generated summaries for accuracy.

The integration follows OpenAI's [direct sign-in flow](https://developers.openai.com/siwc/token-sharing-open-source/sign-in) and [streaming Responses API](https://developers.openai.com/siwc/token-sharing-open-source/models-and-inference).

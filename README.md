# Utter

On-device dictation for macOS. Hold a key, speak, and the text is typed wherever your cursor is.
Speech recognition and cleanup both run on your Mac; nothing you say is sent to a server.

## What it does

- **Hold to dictate.** Hold Right Option (or Right Command, or Fn), speak, release. The text is inserted into the frontmost app.
- **Hands-free.** Double-tap the key to keep listening; tap once more to finish. Esc cancels.
- **Speech models.** Apple's built-in speech recognition, or NVIDIA Parakeet TDT 0.6B v2 (English), downloaded on first use.
- **AI cleanup (optional).** A small local language model fixes punctuation, drops false starts, and keeps only the correction when you change your mind ("send it to Rahul, no actually Priya" becomes "Send it to Priya."). Choose Apple Intelligence or a downloadable Qwen3 model (0.6B, 1.7B or 4B); the app suggests one for your Mac and handles the download.
- **Guarded output.** If a model's answer is not your words in your order, it is discarded and the plain transcript is typed.
- **History and stats.** Past dictations, words dictated, words per minute and a weekly chart, all stored locally.

## Requirements

- macOS 26 or later on Apple silicon
- Xcode 26 with the Metal Toolchain (`xcodebuild -downloadComponent MetalToolchain`)

## Build and run

```sh
scripts/build-app.sh --run
```

This builds the Swift package, compiles the Metal shaders MLX needs, assembles `build/Utter.app`,
signs it, installs it in `/Applications` and launches it. On first launch, grant Microphone and
Accessibility access when asked; Accessibility is what lets Utter see the hotkey and type into other apps.

## Command-line checks

The app binary doubles as a test tool:

```sh
.build/release/Utter --transcribe-file clip.wav --engine parakeet-v2   # run a speech engine on a file
.build/release/Utter --cleanup-test qwen3-1.7b "some text to clean"    # run one cleanup
.build/release/Utter --cleanup-eval qwen3-1.7b                         # score cleanup on eval/cleanup-cases.json
```

Outside the app bundle, copy `.build/metallib/mlx.metallib` next to the binary first.

## Layout

- `Sources/Utter/Engines` – speech engines behind one `TranscriptionEngine` protocol
- `Sources/Utter/Cleanup` – cleanup engines, the model downloader, sentence routing and the output guard
- `Sources/Utter` – the menu bar app, hotkey handling, audio capture, text insertion and the window
- `eval/cleanup-cases.json` – the cleanup test set
- `scripts` – app bundling, shader compilation and the icon generator

## Status

Early. Known limits:

- The built app currently depends on files in this checkout's `.build` folder, so it runs on the Mac that built it. A distributable build is not set up yet.
- English only.
- The cleanup test set is small (20 cases), so its scores are indicative, not a benchmark.

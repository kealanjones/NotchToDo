# NotchTo‑Do for macOS - Engineering Instruction Pack v0.1

Author: Kealan + Coding Agent Date: 26 September 2025 Target platform: macOS 13+ (Ventura) with support through macOS 15+, Apple Silicon first, Intel best‑effort Distribution: Mac App Store optional, primary channel notarised DMG via website

## 1\. Product vision

A lightweight, privacy‑first voice to‑do app that "lives in the notch." It listens only after a wake word, animates subtly around the notch to show state, converts speech to a task, and auto‑files tasks into user‑defined folders using on‑device AI. It returns quick views of lists on demand without occupying screen real estate.

**Principles**

- Always‑ready, never‑intrusive UI
- On‑device by default, cloud optional with user key
- Minimum latency, instant feedback, no spinner fatigue
- Opinionated, simple model, no project management bloat
- Secure by design, least privilege, auditability

**Primary interactions**

- Wake word triggers listening, visual halo animates around the notch
- Voice command becomes task, classifier assigns folder
- Ask to show lists, tiny overlay slides from the notch with scannable cards
- Quick edit, mark done, snooze by voice or keystrokes

## 2\. Core user stories

- As a user, I can say a wake word to start capture, so I do not need to click
- As a user, I can say "add" and the task is stored instantly even offline
- As a user, I can say "new folder" and folders are created by voice
- As a user, I can say "show" to see a compact overlay list from the notch
- As a user, I can correct misclassification with "move to" by voice
- As a user, I can say "list today" to view tasks due today with checkboxes
- As a user, I can export all data to JSON, so I can leave without friction
- As a user, I can sync via iCloud, so my desktop and laptop stay aligned

**Non‑goals v1** email integration, cross‑platform Windows, multi‑user collab, sub‑tasks, reminders calendar integration

## 3\. High‑level architecture

- **UI layer**: SwiftUI + AppKit bridged, Status Bar item with notch‑aligned overlay window
- **Audio I/O**: AVAudioEngine for mic capture, Voice Activity Detection, wake‑word engine
- **ASR**: On‑device Whisper (whisper.cpp via C wrapper) or Apple Speech with on‑device models
- **NLP routing**: Lightweight intent parser + semantic classification to folder using Core ML embedding + k‑NN or small classifier
- **Task domain**: Core Data stack with background contexts, model versioning, migrations
- **Sync**: NSPersistentCloudKitContainer opt‑in
- **Permissions**: Microphone, Speech Recognition, Full Disk Access not required
- **Security**: Hardened Runtime, App Sandbox, Notarisation, crash‑safe persistence

## 4\. Detailed components

### 4.1 Status bar and "notch" UI

- Use NSStatusBar item as main entry point
- Create a borderless NSPanel overlay anchored to the top centre of the active display
- Compute notch bounding box heuristically: for displays with a camera housing, centre top offset equals screen midX, y = screen.maxY
- Render **listening halo** as a circular or semicircular CAShapeLayer arc with pulse on VAD
- States: idle, wake, listening, transcribing, confirming, error
- Animations at 60 fps using Core Animation, energy‑efficient timing
- Overlay sizing: width 420 px, height 520 px max, auto compaction to 280 px when space tight
- Accessibility: VoiceOver labels for icon states, reduced motion flag respected

### 4.2 Wake word and VAD

- Default wake word: "Kilo" (placeholder), configurable
- Engine: Picovoice Porcupine SDK local wake word, or OpenWakeWord on‑device, model packaged
- Add WebRTC VAD or Apple SFSpeechAudioBufferRecognitionRequest.shouldReportPartialResults with custom energy gating
- Hot‑mic policy: mic is off except when engine is armed, wake‑word runs on device without recording

### 4.3 Speech to text (ASR)

- **Preferred**: whisper.cpp integrated via C++ bridge, model base.en by default, small.en optional
- **Alternative**: Apple Speech framework in on‑device mode, fall back to network only if user enables
- Latency target: < 500 ms to first token, < 2.5 s end‑to‑end for 6 second utterance
- Profanity filtering user toggle

### 4.4 Intent detection and NLU

- Pattern layer: small rule set for verbs, e.g. add, create, show, move, mark done, new folder, rename, delete
- Entity extractor: folder names, due dates, priorities
- Semantic classifier for folder routing:
  - Sentence embedding model converted to Core ML, e.g. MiniLM or all‑mpnet base distilled
  - Store centroid vector per folder, classify by cosine similarity, threshold with abstain, then fallback to last used folder
  - Continual learning: when user corrects a misfile, update folder centroid with EMA

### 4.5 Task model and storage

- Core Data entities:
  - Folder { id UUID, name String, createdAt, updatedAt, vector \[Float\], isArchived Bool }
  - Task { id UUID, title String, notes String?, status Enum, dueAt Date?, createdAt, updatedAt, folderId, priority Int, source Enum, transcript String? }
  - Event { id UUID, type Enum, payload JSON, createdAt } for audit and training
- Indices on status, dueAt, folderId
- Write‑ahead logging, background context for ASR pipeline writes
- Export, import as JSON, plus CSV for tasks

### 4.6 Command grammar examples

- "add buy milk" → create Task in default folder
- "add create terms of reference for CRIB meeting" → classify to Consent Work folder
- "new folder triathlon" → create Folder
- "move that to personal" → move last created task
- "show consent work" → render overlay with that list
- "mark 'call Stefan' done" → fuzzy match by title in visible list
- "due tomorrow 9am" → update dueAt, natural language dates via NSDataDetector or Swift Regexes

### 4.7 Privacy and security

- All on‑device by default, no audio leaves machine
- Cloud features off until user opts in and provides API key if using third‑party AI
- App Sandbox entitlements: com.apple.security.app-sandbox, microphone, speech-recognition, com.apple.security.files.user-selected.read-write for exports
- Hardened Runtime, code signing with Developer ID, notarisation CI step
- Secrets storage in Keychain
- Telemetry off by default, if enabled, aggregate, pseudonymous, no content, documented

### 4.8 Performance and energy

- CPU budget idle < 1 percent, listening halo animation uses CADisplayLink with reduced updates on battery saver
- Wake word engine runs in low‑power mode, suspend when on battery if user configures
- Memory target < 300 MB with base.en Whisper model, release ASR after inactivity timeout

### 4.9 Error handling and UX recovery

- Recogniser failures display a tiny toast from the notch, "didn't catch that, try again"
- Network unavailable should never block on‑device path
- Conflict resolution for sync, last‑writer wins with event log for repair

## 5\. Technology choices and rationale

- **Language**: Swift 5.10+, with minimal C++ bridge for Whisper
- **UI**: SwiftUI for views, AppKit for status bar, overlay window management
- **ASR**: whisper.cpp compiled with Metal for Apple Silicon acceleration
- **NLU**: Core ML text embeddings model converted via coremltools, simple k‑NN in Swift
- **Persistence**: Core Data with NSPersistentCloudKitContainer optional
- **Testing**: XCTest, snapshot tests with Point‑Free's SnapshotTesting where viable
- **CI/CD**: Xcode Cloud or GitHub Actions + fastlane for signing, notarisation, DMG build

**Alternatives** if time‑boxed

- Use Apple Speech on‑device only, skip Whisper integration initially
- Use rules‑only intent detection v1, add embeddings in v1.1

## 6\. Public interfaces for the coding agent

### 6.1 Swift protocols

protocol WakeWordEngine {  
func start() throws  
func stop()  
var onTriggered: (() -> Void)? { get set }  
}  
<br/>protocol SpeechRecognizer {  
func start() throws  
func stop()  
var onPartial: ((String) -> Void)? { get set }  
var onFinal: ((String) -> Void)? { get set }  
}  
<br/>protocol IntentRouter {  
func handle(transcript: String, context: RoutingContext) -> Effect&lt;Action&gt;  
}  
<br/>protocol Classifier {  
func predictFolder(for text: String) -> UUID?  
func learn(text: String, correctFolder: UUID)  
}

### 6.2 App state model

enum ListenState { case idle, wake, listening, transcribing, error(String) }  
struct AppState {  
var listenState: ListenState = .idle  
var overlayVisible: Bool = false  
var lastTranscript: String?  
}

### 6.3 Persistence boundaries

- TaskRepository with async CRUD
- FolderRepository with centroid vector read/write

## 7\. Data schema and migrations

- Model version ModelV1
- Migration policy for adding priority and vector later without data loss
- Vector storage options: separate table with BLOB float32 array or JSON array string, benchmark both

## 8\. Security architecture

- Threat model: mic eavesdropping, prompt injection via transcription, model update tampering
- Mitigations: hold‑to‑talk option, on‑device only default, signed model bundles with checksum, limit command vocabulary for privileged actions, content sanitisation on TTS
- Crash logs redacted, no transcripts in logs unless debug flag set by user

## 9\. Build, signing, distribution

- Provisioning: Developer ID Application for DMG, App Store profile optional
- Enable App Sandbox and Hardened Runtime
- CI steps:
  - Build universal Apple Silicon first, optionally Intel
  - Run unit and UI tests
  - Sign, notarise via xcrun altool or notarytool
  - Staple ticket, generate DMG with license, Sparkle appcast if using auto‑updates

## 10\. Quality gates and acceptance criteria

- P0: Wake word to saved task under 3 seconds 95th percentile
- P0: No audio leaves device with defaults
- P0: Mic permission requested once, clear explainer screen
- P1: Folder classification top‑1 accuracy 80 percent after 10 corrections
- P1: Overlay always renders within top 80 px of screen, never blocks menu bar clicks more than 200 ms
- P2: iCloud sync delta under 5 seconds typical on same account

**Definition of Done for v0.1**

- Create, show, move, mark done via voice
- Halo animation with three states
- Local export and import
- Basic classifier with correction learning

## 11\. Testing plan

- Unit tests for parsing, date detection, repository
- Audio integration tests with canned WAV utterances
- Snapshot tests for overlay at different screen scales and notch sizes
- Performance tests: cold start time, ASR roundtrip
- Privacy tests: verify no network calls when cloud is disabled

## 12\. Telemetry, logging, analytics

- Off by default
- If enabled, count of commands, latency histograms, classification confidence buckets
- No raw audio or transcript unless explicit debug mode
- Log levels, error, warn, info, optional verbose in debug builds

## 13\. Accessibility and internationalisation

- VoiceOver labels on all interactive elements
- Respect Reduce Motion and Reduce Transparency
- Localisable strings from day one, en-GB default
- Noise robustness for accents, optional personal pronunciation training

## 14\. Configuration surface

- Wake phrase and sensitivity
- ASR engine and model size
- Auto-dismiss overlay timeout
- Routing confidence threshold and learning toggle
- Battery saver behaviours
- Default export location

## 15\. Roadmap ideas

- Smart summaries per folder on request
- Calendar reminders for due dates
- Handoff wake relay, cross-device continuity
- Share tasks with per-task encryption
- On-device RAG over user docs to suggest next actions
- Spotlight indexing and universal search

## 16\. Prompts and guidance for the coding agent

**General directives**

- SOLID, protocol-driven design, composition over inheritance
- Avoid force unwraps, prefer Result and throws
- Never block main thread, annotate UI with @MainActor
- Feature-oriented file structure, small testable modules
- Doc comments on all public symbols

**UI brief**

- Minimal, notch-native, light and dark mode
- Halo stroke 6 pt, easeInEaseOut, opacity tied to input RMS

**Security brief**

- Keychain for secrets
- Verify model bundle SHA-256 before load
- Confirmation for destructive intents, e.g. "delete all folders"

**Error copy**

- Mic denied, "Microphone access is off in System Settings, Microphone, enable it for NotchTo-Do, then try again"
- Wake phrase training failed, "Wake phrase not saved, try a simpler word or reduce sensitivity"

## 17\. Open questions for product owner

- Final wake word and trademark clearance
- Cloud API fallback in v0.1, yes or no
- iCloud sync default, opt-in or opt-out
- Folder iconography and colours
- Minimum macOS target if Whisper memory footprint increases

## 18\. Deliverables checklist for coding agent

- Xcode project, targets, App, Overlay helper, Whisper bridge
- SwiftPM with pinned dependencies and checksums
- README with build steps and model script
- Unit, UI, snapshot tests with coverage
- Signed, notarised DMG via CI
- Privacy policy markdown and permissions copy
- Release notes and update feed if using Sparkle

## 19\. Suggested repository layout

Notch/

Packages/

Sources/

App/

UI/

Overlay/

Audio/

ASR/

NLU/

Data/

Sync/

Security/

Tests/

Scripts/

Assets/

Models/

README.md

LICENSE

## 20\. Appendix, parsing rules draft

- Verbs, add, create, new folder, show, move, mark done, due, rename, delete, export
- Patterns,
  - ^(add|create)\\s+(?&lt;title&gt;.+)\$
  - ^new\\s+folder\\s+(?&lt;name&gt;.+)\$
  - ^show\\s+(?&lt;folder&gt;.+)\$
  - ^move\\s+(it|that|task)\\s+to\\s+(?&lt;folder&gt;.+)\$
  - ^mark\\s+(?&lt;title&gt;.+)\\s+(done|complete)\$
  - ^due\\s+(?&lt;date&gt;.+)\$

## 21\. Appendix, classification algorithm sketch

- Embed task text to 384-D vector
- Keep a centroid per folder, cosine similarity for routing
- If max similarity ≥ τ, route, else default folder
- On correction, centroid ← α·centroid + (1−α)·example

## 22\. Third-party dependencies and licences

- whisper.cpp, MIT, Metal enabled
- Porcupine or OpenWakeWord, commercial or Apache-2.0 depending on choice, include model licence
- Sparkle (optional), MIT
- LICENSES.md with all notices, show in About

## 23\. Build instructions, developer machine

- Xcode 16+, Command Line Tools
- brew install cmake pkg-config
- git submodule update --init --recursive
- Scripts/build_whisper.sh to compile Metal kernels
- Open workspace, run App target

## 24\. Release channels

- Canary, internal via TestFlight or Sparkle edge
- Beta, wider testers, flags default off
- Stable, notarised DMG, SemVer v0.1.0

## 25\. Risk register, v0.1

- ASR latency, mitigate with streaming partials and smaller model
- Wake word false triggers, tune sensitivity and offer training
- Classifier cold start, default routing plus fast learning on corrections
- Notch geometry variance, robust anchoring and fallback for non-notch displays

## 26\. Privacy policy stub, to ship with DMG

- Audio is processed locally after the wake phrase, no audio or transcripts leave your device by default. If you enable cloud features, requests are sent to the providers you configure under your own API keys. We do not collect personal data unless you enable analytics, in which case only aggregated, non-content metrics are transmitted. You can export and delete your data at any time.

## 27\. Permissions explainer copy, first-run

- Microphone, to capture your voice after the wake word, processed on-device
- Speech Recognition, to transcribe locally, network use is off by default

## 28\. Coding agent execution plan, first milestone

- Status bar app and notch overlay with three states
- Wake word stub and harness, then real engine
- AVAudioEngine to ASR with on-device model
- Rules-based parser, Core Data CRUD for Task and Folder
- Simple k-NN classifier with in-app learning
- Ship v0.1 with export, import and iCloud opt-in
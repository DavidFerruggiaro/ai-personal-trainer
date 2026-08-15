# BodyPark ATOM and Flex AI Workout Trainer: competitive teardown

**Research cutoff:** 2026-07-26

**Repository state inspected:** 2026-07-26

**Status:** Product-intelligence recommendation, not an approved product decision or roadmap change
**Scope:** Exactly two external products: BodyPark ATOM and Flex AI Workout Trainer

## Executive conclusion

The current native app trails both products in product completeness, but not in every dimension that matters.

BodyPark ATOM has the strongest in-set appliance experience: dedicated wide-angle hardware, a glanceable display, audible rep/form cues, visible tracking state, framing guidance, and between-set summaries. Its useful lesson is not “add an AI agent.” It is to make capture eligibility obvious before and during a set, then deliver one short correction while the lifter is resting. Its motion-quality evidence is weak: the public “96%” figure is inconsistently described, advanced metrics are partly marked Preview, no per-exercise validation is published, and even BodyPark says recognition accuracy and equipment-aware planning remain active problems.

Flex AI built the broadest end-to-end gym companion: workout generation, an established logger, prior-performance recall, Apple Watch interaction, progress views, social motivation, progression, and rep-anchored form review. It also offers the best public technical provenance of the two—a relevant patent and an ECCV paper—but neither establishes the accuracy of the 2025–2026 shipped product. The observable form-review flow appears post-set even though marketing repeatedly calls it real-time. Most importantly, Flex laid off its team and ended active operations in March 2026; the app remains online during wind-down. Its breadth is therefore a warning as well as an inspiration.

Our app’s strongest foundation is epistemic: it distinguishes provisional from finalized counts, counted from clean reps, unavailable from zero, analyzer output from user correction, and standard from setup-overridden capture. It also fails closed when retained evidence is compromised. Neither competitor publicly demonstrates that level of result provenance or uncertainty handling. The foundation is nonetheless only a foundation: clean-rep analysis is not implemented, durable history is absent, audio is absent, production counting has only one narrow physical 8/8 observation, and much of the current review journey still lacks real-device verification.

The first competitor behavior to copy should be **BodyPark’s explicit orientation/full-body framing guidance plus out-of-frame recovery**, implemented with our existing uncertainty semantics. The tempting feature to postpone should be **Flex-style conversational workout planning and automatic progression**. The next product sequence should remain: prove capture and counting in messy physical conditions; add one validated post-set squat cue with rep-level evidence; then add local history and a reason to return.

## Method and evidence standard

### Evidence labels

- **REPO** — directly supported by repository code, tests, or project documentation.
- **VERIFIED** — publicly visible in an official product surface, manual, release note, policy, patent, or demonstration. This verifies that the surface or behavior exists, not that it is accurate.
- **MARKETING** — a first-party capability, accuracy, safety, or outcome claim without adequate independent validation.
- **OBSERVATION** — a reviewer or user report. It is evidence about that person’s experience, not a general accuracy result.
- **REPRODUCED MANUAL** — a technical/setup statement visible in a third-party reproduction of a manufacturer manual, but not checked against a manufacturer-hosted copy.
- **INFERENCE** — this report’s synthesis from the cited facts.
- **UNKNOWN** — no adequate public evidence found. Unknown does not mean absent.

The source register records URLs, publication or update dates where available, and the common access date. Company press releases and selected testimonials are treated as marketing even when republished by a media site. A patent establishes claimed intellectual property, not product efficacy. A research paper establishes the reported experiment, not that its model or performance shipped.

### Repository inspection

The repository review followed the required handoff-first order, then inspected the root and iOS READMEs, both milestone task files, decision log, design reviews, current SwiftUI journey, and the PoseCore, SquatAnalysis, TrainerRuntime, and TrainerCore boundaries. The principal repository references appear in the repository evidence register.

No product code, roadmap status, branch, dependency, commit, pull request, or existing document was changed for this research.

---

## 1. Current product baseline

### What the product is today

The native app is an implemented but physically under-validated, in-memory vertical slice for one explicitly selected exercise: side-view barbell back squat. It is not yet a durable workout product. The current path is:

`Quick Start → load → Arm set → setup checks → 5-second countdown → provisional live count → manual Stop → full-sequence finalization → review/correction → Next Set or End Workout → transient summary`

That journey is implemented primarily in `TrainerRootView`, with the domain state in Foundation-only packages and MediaPipe hidden behind app-owned pose types. Unsupported squat variants are present in the catalog but deliberately hidden. There is no account, cloud dependency, program, generic logger, Apple Watch target, social layer, or persistent history. [R1] [R2] [R3] [R4] [R13] [R18]

### Current 10-step journey

| Step | Current native experience | Product implication |
|---|---|---|
| 1. Onboarding | **REPO:** Launch opens a restrained Quick Start view. There is no profile, goals interview, tutorial sequence, or account. Camera permission occurs only when the live session starts. [R13] [R14] | Low friction and aligned with quick-start scope, but a first-time lifter receives little placement education before entering the camera flow. |
| 2. Setup and camera placement | **REPO:** Rear-camera 9:16 portrait preview, pose overlay, and four checks: full body, likely side view, phone stable, and pose confidence. Failed checks provide a corrective instruction; weak setup can be overridden and is marked low confidence. [R13] [R14] [R16] [R22] [R27] | The core gate is stronger than a generic camera preview. Missing pieces are a visual placement prescription, explicit height/distance, continuous in-set framing recovery, and broad device evidence. |
| 3. Exercise selection | **REPO:** Back Squat is the only supported/selectable card. Four planned variants are hidden. [R13] [R23] | Narrowness is a trust advantage until the analyzer is dependable. |
| 4. Starting a set | **REPO:** User enters load and unit, taps `Arm set`, props the phone, enters frame, and gets a five-second countdown when setup is ready. Setup never starts capture without the deliberate arm action. [R13] [R33] [R34] | The hands-away transition is well considered. Wording, discoverability of weak-setup override, and countdown ergonomics remain physically open. |
| 5. During the set | **REPO:** Live camera/overlay, recording state, frame count, Stop, Discard, and a large count explicitly labeled provisional. There is no pause, form assessment, form cue, spoken count, or audio coaching. Countdown haptics are the only cue service. [R13] [R15] | The app currently observes rather than coaches. That restraint is appropriate while form evidence is absent. |
| 6. Ending a set | **REPO:** Stop is manual. The camera disappears immediately, capture drains to an exact event boundary, the retained sequence is batch-analyzed, and processing is shown. Delivery loss or invalid retention fails closed into retry/discard rather than saving partial evidence. [R13] [R19] [R20] [R30] | Strong integrity semantics; the full physical Stop → processing → review path is not yet verified. |
| 7. Review and correction | **REPO:** The finalized result is auto-saved in memory before review. Review discloses live/final count differences, low-confidence setup, and clean unavailable rather than zero. Users can edit load, count, and clean count; original analyzer output remains immutable and corrections retain provenance. [R13] [R17] [R18] [R29] | This is unusually strong trust plumbing. The editor, keyboard, validation, rollback, correction labels, and load carry still need device testing; per-rep/form-label correction and video evidence do not exist. |
| 8. Workout summary | **REPO:** A transient summary shows corrected, non-discarded sets; total counted reps when evidence is complete; clean provenance; and low-confidence capture. It refuses to infer unavailable form trends or mixed-unit volume. [R13] [R21] | Honest but thin. It disappears when the in-memory journey ends. |
| 9. Longitudinal progress | **REPO:** None. Persistence and history have not started. There are no personal-record achievements, trends, standardized comparisons, or video archive. [R8] | This is the largest conventional product gap versus both competitors. |
| 10. Return | **REPO:** The user returns to the same Back Squat Quick Start card. Load carries only within the active session, not across sessions. [R13] [R18] | There is no accumulated value or personalized next-session starting point. |

### What is actually measured and inferred

**Direct inputs and measurements**

- Normalized 2D MediaPipe landmarks, visibility/presence-derived confidence, timestamps, inference latency, and source sequence. [R24] [R31] [R32]
- Core Motion rotation/acceleration for phone stability. [R25]
- Derived knee angle, hip vertical displacement normalized by estimated leg length, rep phase timing, and minimum candidate pose confidence. [R26]
- Setup visibility based on a face/shoulder signal and at least one complete leg/foot chain in frame. [R22]

**Current inferences**

- Likely side view from shoulder/hip horizontal separation relative to torso length. [R22]
- A completed squat from calibrated standing posture, knee flexion plus hip descent, ascent, and return near standing. [R26]
- The primary usable leg from landmark confidence. [R26]
- Low capture confidence from an explicit setup override—not a calibrated probability that a count is wrong. [R16] [R17]

**Not currently assessed**

- Squat depth quality, lockout quality, and tempo quality: the production types exist, but every clean criterion remains `notAssessed`. [R26]
- Torso angle, knee tracking/valgus, bar path, foot pressure/stability, velocity, fatigue, exertion, power, or injury risk.
- A meaningful real-time coaching issue.

### Evidence quality and physical gaps

MediaPipe was selected over Apple Vision after one clean seven-rep labeled barbell clip and a real-device feasibility pass; the clip result was a rough bakeoff score, not certification of the production analyzer. Portrait live capture on one iPhone 16 Pro Max reached roughly 25.5 processed FPS with about 10.6 ms median inference latency and 90.5% pose presence during a squat candidate run. Far-side joints drifted under self-occlusion while near-side signals remained usable. [R11] [R12]

The production integration has one physical observation in which an eight-rep set—including one intentionally shallow rep—counted 8/8, with no phantoms from a few small movements or walking toward the phone. The task document explicitly says this is not an accuracy estimate. No formal 20–30-clip set exists, and clean depth/lockout/tempo gates are unvalidated. [R8] [R10]

Still-open physical checks include Stop/processing/review, retry/discard, normal and overridden review, edits and keyboard behavior, correction provenance and carry-forward, zero-rep paths, multi-set summary, Done, low-confidence presentation, and all future form/audio behavior. [R8] [R10]

---

## 2. BodyPark ATOM

### Product model

| Dimension | Evidence-based teardown |
|---|---|
| Target user | **VERIFIED positioning:** self-directed home, gym, and travel users who want automatic tracking, feedback, and structure without a present coach. **OBSERVATION:** the clearest demonstrated fit is a slow, controlled lifter in a quiet hotel/home gym with clear floor space. **INFERENCE:** its real beachhead is the independent strength trainee willing to place a camera appliance; the “fitness companion for everyone” audience is much less proven. [BP1] [BP10] [BP13] |
| Core job to be done | Keep the phone out of the set: recognize the exercise, count reps/sets, show progress, speak short cues, summarize the set, and sync the workout to the phone afterward. Planning/history sit around that core. [BP1] [BP4] [BP10] |
| Hardware and sensing | **VERIFIED:** roughly 155 g dedicated device with a monocular RGB camera, 160°-class field of view, vertically adjustable head, 1.43-inch display, speaker, microphone, privacy cover, magnetic/floor/tripod mounting, USB-C, Bluetooth, and Wi-Fi. **REPRODUCED MANUAL:** a third-party reproduction of the BPKA1 manual says setup uses the phone app, account pairing, and 2.4 GHz Wi-Fi and that captive portals and 5 GHz are unsupported; a manufacturer-hosted copy was not found. [BP1] [BP3] [BP9] [BP10] |
| Workout flow | **VERIFIED:** users can choose/build a workout and select AI Mode or Record Mode; Log Mode provides manual sets/reps/weight. Follow-along exercise previews, rest transitions, reordering, RPE, exercise search/favorites, and history are evidenced in release notes. The phone is the planning/history surface; ATOM is the in-set display/audio surface. [BP4] [BP5] [BP6] |
| Form-analysis approach | **MARKETING:** DeepBody tracks 34 points, including a proprietary lumbar point, and assesses posture, alignment, depth, tempo, ROM, and trajectory. **VERIFIED narrowly:** the July engine note describes temporal keypoint-state analysis and admits the older pose-snapshot approach produced false positives; back squat is among the first 50 exercises upgraded. **INFERENCE:** image-space points and trajectories are observed; lumbar curve, pelvic tilt, center of gravity, force, power, and “spinal protection” are derived claims. [BP2] [BP3] [BP8] |
| Real-time vs post-set | **VERIFIED:** live rep/audio/form/framing cues and an in-set display; spoken/UI summary during rest; video and report surfaces afterward. **OBSERVATION:** audio worked in a quiet hotel gym but was hard to hear in a crowded gym. [BP4] [BP5] [BP10] |
| Planning and progression | **VERIFIED surfaces:** manual construction, equipment filtering, AI agent, RPE, history. **MARKETING:** goal/equipment/time/history-aware adaptive plans. **First-party problem evidence:** BodyPark said equipment/preference adherence remained a top concern in July. No outcome validation is published. [BP2] [BP5] [BP7] |
| History and progress | **VERIFIED:** workout history and redesigned summary/history pages exist. **MARKETING or preview-limited:** side-by-side video, six performance dimensions, ROM, displacement, velocity, power, bar path, VBT, muscle heat maps, and adaptive trends. The membership page labels range, bar-path, and VBT analysis Preview. [BP1] [BP2] [BP4] |
| Monetization and positioning | **VERIFIED as of access:** $249 list/$219 promotion for standalone hardware, including lifetime Plus and a Pro trial. App Store IAPs list Plus at $6.99/month or $59.99/year and Pro at $19.99/month or $159.99/year; owner-specific Pro prices also appear. **INFERENCE:** “more observant than a watch, more hands-free than a phone, more portable/affordable than a trainer or mirror.” The subscription can make the hardware feel incomplete. [BP1] [BP4] [BP10] |
| Likely moat | **INFERENCE:** dedicated capture/display/audio hardware, strength-specific temporal exercise data, deployed error reports, weekly OTA iteration, and FITURE/BodyPark’s existing motion work. The moat is not the named LLMs. It remains immature because recognition, connection stability, and equipment-aware planning are still being repaired. [BP5] [BP6] [BP7] [BP15] |

### Reconstructed end-to-end experience

| Step | Reconstructed journey | Trust, motivation, and polish detail | Evidence limit |
|---|---|---|---|
| 1. Onboarding | **VERIFIED app surface / REPRODUCED MANUAL setup:** charge/power the device, install the app, create/sign into an account, pair ATOM, connect 2.4 GHz Wi-Fi, and sync. The app exposes a tutorial re-entry point. [BP4] [BP9] | Recoverable tutorial; physical lens cover makes privacy tangible. | Pairing was BodyPark’s most-reported early issue. The reproduced manual says hotel captive portals are unsupported. [BP7] [BP9] |
| 2. Setup/camera | **VERIFIED:** place on floor, rack magnet, or tripod about 1–2 m away; aim vertically; follow exercise-specific orientation and full-/upper-body framing icons; confirm via camera/skeleton view and out-of-frame alerts. [BP3] [BP5] | Skeleton answers “can it see me?”; wide FOV reduces distance; several mounting choices fit different spaces. | **MARKETING/OBSERVATION conflict:** “Smart Tilt & Follow” is marketed, while the reviewer manually tilted and physically moved it horizontally. Automatic follow is **UNKNOWN**. Dark-floor trip risk and crowded-gym occlusion are reviewer observations. [BP3] [BP10] |
| 3. Exercise selection | **VERIFIED surfaces:** choose a library/curated workout, build manually, or use the agent surface; then choose AI, Record, or manual Log behavior. [BP1] [BP5] [BP6] | Explicit non-AI fallbacks acknowledge that analysis is not always the right mode. | **MARKETING/UNKNOWN:** “1,000+” alternately describes library, defined movements, or recognized exercises; validated breadth is unknown. |
| 4. Start set | **VERIFIED:** enter the follow-along view and see an exercise GIF/cover plus orientation/framing. **MARKETING:** BodyPark says start/end detection can be automatic. [BP2] [BP5] | Preview establishes movement and camera contract before effort begins; loading state reduces perceived delay. | Public sources do not show whether bad framing blocks capture or only warns. |
| 5. During set | **VERIFIED surfaces:** display shows rep, set, target/progress, and skeleton; speaker or earbuds provide rep counts, half-rep/out-of-frame/form/rhythm cues. **OBSERVATION:** one reviewer heard and used the cues. [BP1] [BP5] [BP10] | Redundant glance/audio/overlay channels minimize touching the phone; half-rep cues make at least one failure mode legible. | No public low-confidence policy, cue-throttling rule, or crowded-person handling. The reviewer’s good count experience was one slow, controlled style. |
| 6. End set | **VERIFIED surface:** completion feedback leads into rest timer and a short spoken/UI summary with what went well and what to improve. [BP4] [BP5] | Correction arrives when a lifter can safely act on it before the next set; set celebrations add closure. | Summary quality and biomechanical validity are not independently tested. |
| 7. Review/correct | **VERIFIED surfaces:** review recorded/local video and set feedback; use Record or Log mode when AI is inappropriate; submit product/exercise feedback. [BP5] [BP12] | Video gives the user independent evidence rather than only a verdict. | **UNKNOWN:** no public flow shows editing an AI count, changing exercise classification, rejecting a form flag, or marking analysis invalid. A direct recognition-error flag was still forthcoming on July 10. [BP7] |
| 8. Workout summary | **VERIFIED surface:** the app produces a history item and report with exercises, sets/reps, movement-quality presentation, and optional video. [BP4] [BP5] | Layered summary supports a quick read and deeper replay. | **UNKNOWN:** which advanced metrics are live for back squat, Pro-only, or Preview is ambiguous. |
| 9. Longitudinal progress | **VERIFIED:** history and RPE surfaces. **MARKETING:** report trends, video comparisons, and six-dimension views. [BP1] [BP2] [BP5] | A standardized comparison could make progress visible beyond load. | **INFERENCE:** camera geometry may make image-derived comparisons unstable; plan and metric validity are unpublished. |
| 10. Return | **VERIFIED:** active-workout/device/battery/update reminders. **MARKETING:** saved/generated adaptive plans and short “One Set” sessions as a return system. [BP2] [BP5] | **INFERENCE:** appliance presence plus small sessions can create a daily-return loop. | **OBSERVATION:** the breadth made the app feel dense enough that the reviewer said regular use was needed to get the most from it. [BP10] |

### Motion-analysis credibility audit

| Question | Finding |
|---|---|
| What is actually measured? | **VERIFIED:** monocular RGB frames, image-space keypoints/trajectories, timing, recognized motion phases, device state, and optionally wearable heart-rate/activity context. Weight, sets, reps, and RPE can also be manually entered. [BP3] [BP5] [BP9] |
| What appears inferred? | Exercise identity; rep boundaries; depth, posture, alignment, and tempo labels; lumbar/pelvic interpretation; ROM/displacement/velocity; bar path; movement quality; plan changes. Center of gravity, force, power, muscle heat maps, and injury protection are especially indirect because no depth camera, force plate, bar sensor, or EMG is listed. |
| Is accuracy evidence published? | **No adequate evidence found. MARKETING:** 96% AP/precision/recognition. No dataset, definition, demographics, camera distribution, test split, per-exercise confusion matrix, rep error, coach agreement, or external validation is published. The FAQ calls it pose AP; another page calls it recognition across 1,000+ movements. Those are not equivalent. [BP1] [BP2] [BP3] |
| Is broad support demonstrated? | Only partially. Release notes repeatedly add/fix recognized exercises, and the new temporal engine initially upgraded 50—including back squat. Library breadth is not evidence of equal analysis depth. [BP5] [BP6] [BP8] |
| Does it communicate uncertainty? | Operationally, somewhat: orientation/framing icons, skeleton, partial-body logic, out-of-frame alerts, half-rep cues, weak-network retry. Epistemically, no public confidence label, provisional/final distinction, “could not assess” state, or invalid-result policy was found. [BP5] |
| Can users correct wrong results? | **UNKNOWN:** manual Log and Record modes exist, but AI-result editing/reclassification is not shown. Feedback submission is not result correction. Direct error flagging was still planned. [BP5] [BP7] |
| Does it separate count from quality? | Interface-level separation exists—count during the set, quality cues/reports around it—but no public counted-reps versus clean-reps contract. Some exercise definitions appear to fold completeness into count. Squat semantics are unpublished. [BP4] [BP8] |
| What happens on zero or a partial rep? | Half-rep audio exists. Zero-rep finalization, add-rep recovery, explain-why-not-counted, and history behavior are **UNKNOWN**. [BP5] |
| What happens under occlusion or poor framing? | Guidance and out-of-frame alerts exist. **OBSERVATION:** the product needs a clear, unobstructed view, and crowded gyms are difficult. Whether degraded evidence suspends counting, lowers confidence, or silently continues is **UNKNOWN**. [BP5] [BP10] |
| Is feedback biomechanically meaningful? | Depth, posture, alignment, tempo, and bar path can be meaningful if correctly detected. Public cue definitions, personalization rules, view dependencies, and coach agreement are absent. A generic back-straightening cue is not proof of valid lumbar mechanics. |
| Are safety claims supported? | No. “Spinal protection,” injury prevention, and “lab-grade” language are marketing. The terms say the AI is not medical advice and lacks knowledge of pain, injury, and health limitations. [BP2] [BP13] |
| Is privacy clear? | No. The tech page says movement data remains on-device, while the privacy policy describes collected movement/history data and optional cloud workout video; release notes mention video upload. Local pose inference and optional cloud sync may coexist, but the public copy does not clearly reconcile them. [BP3] [BP5] [BP12] |

### What BodyPark earns—and does not earn

The independent sample is extremely thin: one ten-day reviewer without ground truth or a disclosed exercise matrix, plus five US App Store ratings at access. Tech for Travel’s site-wide policy says it may earn affiliate commission, but it does not establish whether this specific unit was supplied, compensated, or affiliate-linked. Treat the review as limited usability evidence only. [BP4] [BP10] [BP11]

**Earned product credibility**

- It is newly but genuinely shipped, with nearly 2,000 backer units reported and weekly device/app updates through July 24. [BP6] [BP14]
- A hands-on reviewer used it during a ten-day trip and observed accurate counts for his slow, controlled dumbbell/barbell sets plus subjectively useful live prompts. [BP10]
- The release history exposes real operational learning: orientation/framing guidance, partial-body handling, half-rep cues, connection recovery, AI/Record modes, local video, and dozens of recognition fixes. [BP5] [BP6]
- BodyPark publicly acknowledged connection stability, recognition accuracy, and equipment-aware planning as live problems. [BP7]

**Not earned**

- A general back-squat rep-count accuracy estimate.
- A validated clean-rep or biomechanical quality model.
- The claim that 96% pose AP implies 96% exercise recognition or correct coaching.
- Force, power, center-of-gravity, VBT, muscle activation, or injury-prevention credibility.
- Evidence that automatic planning improves outcomes or respects constraints reliably.
- Evidence that users can repair incorrect AI records.

---

## 3. Flex AI Workout Trainer

> **Current operating status:** BetaKit reported on 2026-07-20, citing CEO Amin Niri, that Flex AI laid off its team and ended active operations in March 2026 after an attempted sale failed and funding was exhausted. The app remained online during wind-down. Flex should be treated as a product and technical case study, not as a healthy ongoing competitor. [F11]

### Product model

| Dimension | Evidence-based teardown |
|---|---|
| Target user | **VERIFIED positioning:** iPhone lifters from beginner to advanced pursuing strength, hypertrophy, or consistency. **OBSERVATION:** positive reviews emphasize custom routines, prior-load recall, rest timing, Watch logging, progress, and community—suggesting the established logger was at least as important as form AI. [F1] [F2] |
| Core job to be done | **INFERENCE:** replace several gym tools and part of a trainer: decide what to do, remember performance, reduce logging friction, review form, progress loads, and sustain motivation. This is broader than our squat-first job. |
| Hardware and sensing | **VERIFIED:** iPhone plus optional Apple Watch; no dedicated sensor. Watch surfaces log load/reps and show heart rate/rest context. **MARKETING:** standard phone camera, custom models, 30+ “biomechanical points,” and on-device real-time analysis. The privacy policy allows uploaded video/form-feedback storage for up to two years and service-provider AI processing, so all product pathways should not be assumed local. [F1] [F3] [F6] [F10] |
| Workout flow | **VERIFIED:** accept a generated workout, use premade/custom routines, import a routine from an image, swap exercises, see prior performance, log on phone/Watch, use rest timers, and review progress. **UNKNOWN:** whether camera analysis is seamlessly embedded in ordinary logging or a separate form-check mode. [F1] [F3] |
| Form-analysis approach | **VERIFIED as technical lineage, not shipped efficacy:** the patent describes an exercise-specific rep detector followed by separate error models producing per-frame probabilities and rep-level feedback. A Flex-affiliated ECCV paper presents Fitness-AQA for back squat, barbell row, and overhead press using task-specific image/video representations and barbell/object signals rather than relying only on generic pose. **UNKNOWN:** whether the 2025–2026 app ships those models. [F7] [F8] |
| Real-time vs post-set | **MARKETING:** “real-time” and “instant” correction. **VERIFIED observable demo:** playback, rep navigation, individual positive/corrective messages, error list, and aggregate score. **WEAK OBSERVATION:** a May 2026 commercial comparison published by GainFrame’s founder also described Flex as post-set, but disclosed no Flex test method. **Conclusion:** the official demo evidences post-set rep review; in-set corrective coaching remains unverified. [F1] [F4] [F9] |
| Planning and progression | **VERIFIED surface:** Lex accepts natural-language constraints; generated cards expose workout duration/exercises/sets; routines are editable. **MARKETING:** history/recovery/goal-aware workout generation, auto-progression, and deloading. **OBSERVATION:** one older user said the progression first lowballed then overshot load, but that predates the current AI release. [F1] [F2] [F3] |
| History and progress | **VERIFIED:** prior sets, load/rep/estimated-1RM graphs, PRs, volume, calories, recovery, bodyweight, steps, streaks, badges, challenges, year recap, progress photos, leaderboards, and social workout cards. Public evidence does not establish longitudinal form-quality trends. [F1] [F3] |
| Monetization and positioning | **VERIFIED as of access:** freemium; App Store IAPs include Premium at $12.99/month or $83.99/year, Plus at $19.99/month or $119.99/year, and family prices. **INFERENCE:** an all-in-one “AI personal trainer” meant to make human-coach-like guidance broadly affordable. The wind-down makes purchase continuity and support material risks. [F1] [F11] |
| Likely moat | **INFERENCE:** proprietary in-the-wild exercise data, exercise/error-specific models, a granted US patent, relevant published research, accumulated workout histories, and social graph. **Strategic limit:** those assets and nearly one million historical users did not produce a sustainable company. Technical differentiation is not sufficient commercial moat. [F5] [F7] [F8] [F11] [F13] |

### Reconstructed end-to-end experience

| Step | Reconstructed journey | Trust, motivation, and polish detail | Evidence limit |
|---|---|---|---|
| 1. Onboarding | **VERIFIED fields / INFERENCE flow:** create an account/profile and provide age, gender, height, weight, and goals; schedule/equipment/preferences likely feed generation. [F10] | **INFERENCE:** natural-language Lex can lower the burden of configuring a plan. **OBSERVATION:** a Product Hunt commenter described the onboarding/design as straightforward. [F12] | **UNKNOWN:** exact screen order and mandatory fields. **OBSERVATION:** a 2025 App Store user reported losing access after login links failed. [F2] |
| 2. Setup/camera | **VERIFIED:** the form feature uses an iPhone camera. **INFERENCE:** public examples are predominantly side views and require the phone to be propped for a full lift. [F4] | **INFERENCE:** no extra hardware makes the form check portable. | **UNKNOWN:** no strong public evidence of distance, height, lighting, clothing, orientation, full-body gate, or recovery guidance. |
| 3. Exercise selection | **VERIFIED logging surfaces:** accept a Lex-generated workout, choose a premade/custom routine, scan a routine, or swap movements. **MARKETING:** public form materials name squat, deadlift, bench, rows, overhead press, and “more.” [F1] [F3] [F4] | **VERIFIED surface / INFERENCE benefit:** generated cards show duration, exercises, and set counts; swaps can help in a busy gym. | **UNKNOWN:** exact current computer-vision-supported set; broad logging breadth is not form-analysis breadth. |
| 4. Start set | **VERIFIED logging flow:** tap Start Workout, open an exercise, see targets/prior performance, and log through phone or Watch. **INFERENCE:** the separate form feature initiates camera capture. [F1] [F3] [F4] | **INFERENCE:** prior performance removes memory work; Watch keeps the phone out of the hand. | **UNKNOWN:** integration between logging and camera mode. |
| 5. During set | **VERIFIED Watch surface:** load/reps, heart rate, rest state, and prior set. **MARKETING:** Flex says the phone gives instant form feedback. [F1] [F3] [F4] | **INFERENCE:** one-tap logging and wrist glance preserve flow. | **UNKNOWN:** public evidence verifies neither spoken coaching nor an in-set correction UI. |
| 6. End set | **VERIFIED observable outcome:** the demo shows footage segmented/navigable by rep with generated messages. **INFERENCE:** this follows set completion and processing; the patent describes a compatible architecture but does not prove shipped sequencing. [F4] [F8] | **INFERENCE:** rest is the right cognitive moment for technique review. | **UNKNOWN:** processing latency and automatic/manual rep-boundary behavior. |
| 7. Review/correct | **VERIFIED observable UI:** playback with overlay; previous/pause/next rep controls; one positive or corrective message at a time; deeper error list; overall form score. [F4] | **INFERENCE:** rep anchoring makes feedback inspectable; praise plus one correction is less punitive than a fault dump. | **UNKNOWN:** no public edit for a false rep boundary, wrong label, or aggregate score. **VERIFIED separately:** logged load/reps are editable, but that is not camera-result correction. [F1] [F2] |
| 8. Workout summary | **VERIFIED surface:** exercises/sets, duration, volume, calories, PR achievements, and a shareable social card. [F1] [F3] | **INFERENCE:** the summary is legible and motivating; personal-record emphasis creates closure. | **OBSERVATION/INFERENCE:** one user complained about material calorie error; derived metrics can look precise without calibration. [F2] |
| 9. Longitudinal progress | **VERIFIED:** prior-set recall; load, reps, estimated 1RM, volume, recovery, bodyweight, steps, streaks, challenges, and leaderboards. [F1] [F3] | **INFERENCE:** inline history supports the next decision; yearly recap and streaks make accumulated effort visible. | **UNKNOWN:** no demonstrated stable form-quality trend or uncertainty around estimated metrics. |
| 10. Return | **VERIFIED surfaces:** reminders, streaks, community, recovery view, and Lex-generated next-workout/progression surfaces. [F1] [F2] [F3] | **INFERENCE:** multiple return hooks reduce “what should I do?” friction. | **VERIFIED operating risk:** active support and product continuity are uncertain because operations ended. [F11] |

### Motion-analysis credibility audit

| Question | Finding |
|---|---|
| What is actually measured? | RGB camera frames and time; user-entered load/reps; Watch interactions and heart rate. Everything else—joint location, angle, bar path, rep phase, error label, form score, recovery, calories—is derived. “Weight distribution” is not directly measurable from monocular RGB without a force proxy. |
| What appears inferred? | Exercise/rep segmentation, per-frame error probabilities, joint/body-region and barbell relationships, depth, knee motion, spinal/torso posture, lockout, symmetry, overall score, programming readiness, and recovery. |
| Is technical evidence published? | Better than BodyPark, but narrow. The ECCV paper uses real-world footage and expert labels for three exercises. For back squat it reports F1 0.5263 for knees inward, 0.8468 for knees forward, and 0.8694 for shallow squat for the listed best methods. Some visible/static errors were much easier than subtle motion errors. [F7] |
| Does that validate the product? | No. The paper does not establish that those models shipped, and publishes no current product precision/recall by exercise/error/device/view, latency, calibration, demographic analysis, motion-capture comparison, or production failure rates. The patent describes an architecture, not accuracy. [F7] [F8] |
| Are beta outcome claims adequate? | No. **MARKETING:** 84% discovered unknown form problems, 70% improved within 14 days, and injury-risk indicators decreased. No sample size, protocol, comparator, outcome definition, statistics, or independent audit is published. [F6] |
| Does it communicate uncertainty? | No public confidence interval, low-confidence state, inability-to-assess result, or explanation of uncertainty was found. Categorical messages and an overall percentage imply more certainty than the evidence supports. |
| Can users correct incorrect results? | Logged routines/load/reps are editable. Camera rep-boundary, form-label, and score correction are **UNKNOWN**. The privacy-policy right to correct personal data or request human review is a legal right, not a workout correction feature. [F10] |
| Does it separate rep count from quality? | The patent’s conceptual architecture does: exercise-specific rep detection and separate error models. The demo anchors errors to reps. The public product does not clearly communicate counted reps versus quality-qualified reps or provide separate corrections. [F8] |
| What happens on zero reps, occlusion, or poor framing? | **UNKNOWN** in the shipped UI. The paper itself explains that gym camera angle, equipment occlusion, lighting, clothing, and unusual poses challenge generic pose systems. A vendor-selected testimonial says a sweatshirt caused curve/angle misreads. No visible framing gate, occlusion warning, zero-rep recovery, or “cannot assess” state was found. [F4] [F7] |
| Is feedback biomechanically meaningful? | Squat depth, knee movement, torso position, lockout, neck, and bar path can be specific and actionable. Overall percentages, inch-level offsets from an uncalibrated view, injury prevention, and performance promises are weakly grounded. |
| Is “real-time” credible? | The company and App Store say yes. The official visible interaction shows post-set playback. A commercially interested GainFrame article agrees but supplies no Flex testing method, so it is weak corroboration only. Until direct device evidence resolves the conflict, only post-set rep review should be treated as verified. [F1] [F4] [F9] |
| Is privacy/locality clear? | Not fully. The company says on-device CV; the privacy policy permits uploaded video/form-feedback retention and service-provider AI processing. Local form inference may coexist with uploaded/cloud features, but the exact boundary is not public. [F6] [F10] |

### What Flex earns—and does not earn

**Earned product credibility**

- It built a polished, long-running logging, history, Watch, and social experience used and reviewed at meaningful scale. [F1] [F2]
- It visibly reduces common gym friction: prior-set recall, rest timer, exercise swaps, custom routines, routine image import, plate calculator, and Watch logging. [F3]
- Its public form-review interaction is concrete: rep navigation, playback, positive/corrective cue, deeper error list, and aggregate result. [F4]
- The patent and ECCV paper show real technical work and a more exercise-specific approach than generic “draw a skeleton, apply angles” marketing. [F7] [F8]

**Not earned**

- Proof that the current production models match the paper or patent.
- A blanket expert-level accuracy claim across supported exercises and errors.
- Proof of in-set real-time correction.
- A trustworthy aggregate form percentage or inch-level monocular measurement.
- Evidence that auto-progression/deloading is appropriate or safe.
- A result-correction and uncertainty model.
- Evidence that broad feature depth produced a sustainable business; the opposite operating outcome is now documented. [F11]

---

## 4. Repository-grounded feature comparison

Competitor cells use the evidence labels defined above. Every conclusion about our app points to a repository source, type, or document.

| Category | Our current native app | BodyPark ATOM | Flex AI |
|---|---|---|---|
| Setup guidance | **REPO:** four live checks with pending/pass/fail and actionable fixes; deliberate arm; weak override nested and marked low confidence. No first-run placement tutorial. `SetupGate`, `SetupGateSignalWindow`, `TrainerRootView`. [R13] [R16] [R27] | **VERIFIED:** pairing/tutorial, exercise GIF, orientation/full-body icons, skeleton, out-of-frame guidance. Pairing/network remain early pain points. [BP5] [BP7] [BP9] | **UNKNOWN:** no strong public camera setup tutorial/gate evidence. Profile/goal onboarding is much broader than camera onboarding. |
| Camera positioning | **REPO:** rear camera, portrait 720p/30 FPS target, side-view/full-body/stability/confidence checks and overlay. No prescribed hip height/distance visual; landscape absent. `TrainerLivePoseCamera`, `PoseSetupEvidence`. [R14] [R22] | **VERIFIED:** 160° camera, floor/magnet/tripod, 1–2 m claim, vertical aim, orientation/framing icons. Horizontal aim is physical; crowded placement is weak. [BP3] [BP5] [BP10] | **VERIFIED camera / INFERENCE view / UNKNOWN guidance:** form check uses the iPhone camera; examples are mostly side view, while required distance, height, angle, full-body state, and failure recovery are not documented. [F4] |
| Rep counting | **REPO:** conservative streaming state machine plus canonical full-sequence replay. One physical 8/8 observation only; broader accuracy unknown. `SquatAnalyzer`, M2 task evidence. [R8] [R26] | **VERIFIED capability; OBSERVATION only for performance:** automatic live count, no errors noticed by one slow/controlled reviewer. New engine still rolling out by exercise. [BP8] [BP10] | **VERIFIED technical/logging surfaces / UNKNOWN shipped accuracy:** patent/demo organize results by rep and Watch can log reps; camera-count performance and manual-vs-automatic semantics are unpublished. [F1] [F4] [F8] |
| Provisional vs finalized | **REPO:** explicit live provisional count and canonical batch-final count; differences disclosed. `SetAnalysisSummary`, `TrainerRootView`. [R13] [R17] | **UNKNOWN:** no public provisional/final distinction. | **UNKNOWN:** no public provisional/final distinction. |
| Form assessment | **REPO:** counted/clean contract and per-rep assessment types exist, but depth/lockout/tempo are all `notAssessed`; UI says unavailable. `SquatCleanRepAssessment`, `SetAnalysisSummary`. [R17] [R26] | **VERIFIED surface / MARKETING validity:** depth/posture/alignment/tempo cues exist; lumbar/force/power claims are unvalidated. [BP2] [BP10] | **VERIFIED surface / UNKNOWN validity:** visible rep-level positive/corrective feedback and score. Relevant research exists, but current shipped accuracy and model lineage are unverified. [F4] [F7] |
| Real-time coaching | **REPO:** none beyond setup state and provisional count; intentionally conservative. Product spec allows rare validated cues later. [R4] [R13] | **VERIFIED:** live spoken cues/reminders, plus between-set summary. [BP4] [BP5] [BP10] | **MARKETING:** live/instant. The official demo verifies post-set playback; in-set correction is unverified. A commercially interested comparison is weak corroboration only. [F4] [F9] |
| Audio feedback | **REPO:** absent; only countdown haptics in `TrainerSessionCues`. [R15] | **VERIFIED:** speaker/earbuds, rep/form/half-rep/status cues. **OBSERVATION:** hard to hear in crowded gym. [BP1] [BP5] [BP10] | **VERIFIED patent option / UNKNOWN shipped behavior:** the patent permits audio, but no shipped spoken form coaching was verified; Watch/visual interaction is evidenced. [F1] [F8] |
| Confidence and uncertainty | **REPO:** setup unknowns remain unknown; override produces low confidence; clean can be unavailable; delivery loss fails closed. Raw per-rep count confidence exists but is not calibrated or displayed. [R16] [R17] [R19] [R26] | **VERIFIED operational signals / UNKNOWN result semantics:** skeleton/framing/out-of-frame/half-rep/network exist; no confidence, unavailable, or invalid-result state found. [BP5] | **UNKNOWN:** no public confidence/inability-to-assess state found; the visible overall percentage can imply false precision. [F4] |
| Corrections | **REPO:** edit load/count/clean; immutable analyzer original plus ordered correction provenance; discard rolls back in-memory reviewed set. UI/atomic multi-field behavior still needs physical verification. `QuickSession`, `SetCorrection`, design review. [R9] [R18] [R29] | **VERIFIED fallbacks / UNKNOWN AI correction:** manual Log/Record and feedback entry exist; editing/reclassifying AI results is unknown, and direct recognition-error flagging was forthcoming. [BP5] [BP7] | **VERIFIED log editing / UNKNOWN camera correction:** logged routine/load/reps are editable; camera boundary/form-label/score correction is not publicly shown. [F1] [F2] |
| Zero-rep recovery | **REPO:** finalized zero can reach review and count can be corrected; zero-rep active discard is immediate, detected-rep discard confirms; processing retry/discard exists. Physical verification open. `ActiveSetCapture`, `TrainerRootView`. [R13] [R17] [R28] | **VERIFIED partial signal / UNKNOWN recovery:** half-rep cue exists; zero-result finalization and add-rep behavior are not documented. [BP5] | **UNKNOWN:** no public zero-rep/framing recovery flow. |
| Session summaries | **REPO:** per-set review plus transient corrected session summary; missing trends stay unavailable. `SessionSummary`, `TrainerRootView`. [R13] [R21] | Between-set summary and final report are **VERIFIED** surfaces; advanced contents partly marketing/Preview. [BP1] [BP4] [BP5] | **VERIFIED:** duration, volume, calories, PRs, exercise/set summary, share card. |
| Workout history | **REPO:** absent; M2.13 not started. [R8] | **VERIFIED:** history and redesigned history screens. [BP4] [BP5] | **VERIFIED:** prior sets, graphs, year recap, photos, social history. [F1] [F3] |
| Progression | **REPO:** absent. Corrected load only carries within the active quick session. `QuickSession`. [R18] | Adaptive plans are **MARKETING**; plan adherence to equipment/preferences is a first-party known issue. [BP2] [BP7] | Auto-progression/deload are **MARKETING** surfaces; appropriateness unvalidated. Older user evidence reports under- then over-prescription. [F2] |
| Personalization | **REPO:** personal standing calibration, most-usable leg, within-session load carry. No profile, preferences, or plan. `SquatAnalyzer`, `QuickSession`. [R18] [R26] | **VERIFIED inputs/surfaces; MARKETING efficacy:** goals, equipment, history, RPE, limitations, and coach personas are surfaced or claimed; quality is unknown. [BP2] [BP5] | **VERIFIED inputs/surfaces; UNKNOWN quality:** goals, history, recovery, equipment, schedule, and natural-language personalization. [F1] [F3] [F10] |
| Exercise breadth | **REPO:** exactly Back Squat supported; planned variants hidden in `ExerciseCatalog`. [R23] | **MARKETING breadth / VERIFIED staged rollout:** 1,000+ library claim; recognition quality varies and the new engine initially covers 50. [BP5] [BP8] | **VERIFIED broad logging / UNKNOWN CV breadth:** custom exercise library exists; exact form-supported set is unknown, while public materials name major compound lifts. [F1] [F4] |
| Portability | **REPO:** one iPhone, local, no account/network. Requires stable placement, clear portrait view, and enough space. [R2] [R4] [R14] | **VERIFIED hardware / OBSERVATION tradeoff:** 155 g and mountable, but adds charging, Wi-Fi, floor/tripod placement, and trip/occlusion risk. [BP9] [BP10] | **VERIFIED hardware surface / INFERENCE:** iPhone plus optional Watch, iOS only; camera placement consumes the phone during form analysis. [F1] [F4] |
| Apple Watch/wearable integration | **REPO:** none; explicitly deferred. [R4] | **VERIFIED compatibility / partly MARKETING integration:** Apple Watch app and Watch HR sync are surfaced; wider wearable support is partly roadmap. [BP1] [BP4] | **VERIFIED:** Watch logging/rest/HR surface, with user praise and some sync complaints. [F1] [F2] |
| Social/motivational systems | **REPO:** no feed, streaks, badges, leaderboards, challenges, or social summary. Motivation is large count, set completion, and Next Set continuity. [R4] [R13] | **VERIFIED surfaces / UNKNOWN peer layer:** progress bars, audio effects, celebrations, short sessions, reminders, and highlight sharing; no verified peer community. [BP2] [BP5] | **VERIFIED surfaces:** feed, likes/comments, streaks, badges, challenges, photos, peer-group leaderboards, and share cards. [F1] [F3] |
| Performance metrics | **REPO:** UI exposes load, count, clean provenance/status, per-rep status, and session totals. Timing/confidence exist internally but are not presented. No ROM, velocity, bar path, volume, or trend. [R13] [R17] | **VERIFIED RPE / MARKETING or Preview analysis:** ROM, displacement, velocity, power, stability, six dimensions, and muscle maps are claimed; range/bar path/VBT are marked Preview and mostly unvalidated. [BP1] | **VERIFIED surface / derived-estimate caveat:** load, reps, tempo, rest, volume, PR achievements, estimated 1RM, calories, HR, recovery, steps, bodyweight, and form score. [F1] [F3] |
| Evidence quality | **REPO:** strongest methodological honesty and domain semantics, but very narrow empirical coverage: one physical 8/8 production set, one rough seven-rep bakeoff clip, one device/portrait feasibility run, no clean gates. [R8] [R10] [R11] [R12] | Low for accuracy; moderate for shipped UX. One hands-on reviewer, tiny App Store sample, manual/release notes, and first-party admissions; no technical validation. | Better technical provenance via patent/ECCV paper, but no proof of current production model or accuracy; no uncertainty model; company is winding down. [F7] [F8] [F11] |

### Comparative diagnosis

Our app lags in the complete product loop: setup pedagogy, hands-free operation, post-set evidence, persistent history, next-session continuity, and any actual form insight. It also lacks the breadth and motivational surface that makes Flex feel like a daily gym tool.

It may already be differentiated in a more important early-stage dimension: **result integrity**. BodyPark and Flex publicly present confident answers; neither exposes provisional/final semantics, clean unavailable, a low-confidence finalized result, a correction provenance model, or fail-closed event retention. Our app’s challenge is to turn that invisible architecture into a visible, useful experience—without letting honesty become a substitute for actual physical accuracy.

---

## 5. What we should take

These are candidate recommendations only. They do not change locked scope or existing task status. The current real-device validation pass should complete as a baseline before product behavior changes; its observations can supply evidence for the candidates below.

### Adopt soon

| Candidate | User problem solved | Competitor inspiration | Current repository gap | Likely implementation surface | Physical evidence required | Complexity | Sequence |
|---|---|---|---|---|---|---|---|
| 1. A visual back-squat camera-placement contract | Lifters do not know the correct side, distance, height, body/bar visibility, or whether rack/plates invalidate the view. | BodyPark’s exercise-specific orientation/full-body preview and visible skeleton. | Four checks exist, but no pre-set silhouette/diagram, explicit distance/height, or bar/rack visibility contract. [R13] [R16] [R22] [R27] | `TrainerRootView.cameraPreview`, setup copy/rows, `PoseSetupEvidenceExtractor`; possibly a squat-specific placement model in TrainerCore. | Multiple body sizes, phone heights/distances, rack geometries, plate sizes, clothing, lighting, near/far side, and clutter; test whether guidance predicts usable counts rather than merely looking green. | **Medium** | **After** current pass |
| 2. Continuous in-set tracking-health and out-of-frame recovery | A set can begin valid and become unusable after walkout, plate/rack occlusion, another person, or phone movement. The user currently sees a count but no active evidence-health state. | BodyPark’s out-of-frame/partial-body alerts; its skeleton as “I see you” state. | Setup confidence is front-loaded; runtime event loss fails closed, but ordinary inference gaps/capture drops are not clearly surfaced or translated into a recoverable set state. [R19] [R25] [R26] | `TrainerPoseObservationPipeline`, `ActiveSetPoseIngestion`, `TrainerSetupGateController`, `ActiveSetCapture`, live banner/review confidence in `TrainerRootView`. | Annotated mid-rep exits, rack/plate/self-occlusion, phone bumps, capture drops, background people, re-entry; measure false alerts, correct suspension/resume, and effect on final count. | **Large** | **After** current pass |
| 3. Explain incomplete candidates without silently changing the count | A lifter needs to understand “why did that rep not count?” and recover from zero/missed reps. | BodyPark’s half-rep cue; Flex’s rep-anchored review. | Users can edit the final count, but the analyzer does not expose aborted candidate reasons or an evidence timeline. Zero-rep recovery is mostly a correction/discard path. [R13] [R28] [R26] | `SquatAnalyzer` event/result model, `SetRepSummary` or a new non-counted-candidate summary, TrainerRuntime mapper, review UI. Preserve provisional/final and user correction provenance. | Labeled partials, shallow-but-complete reps, pauses at bottom, walkout/rerack, good mornings, small leg movements, bounces, failed ascent, and long occlusion. Confirm explanations agree with count semantics and do not coach form prematurely. | **Medium** | **After** current pass |
| 4. Sparse hands-free status and rep audio | The phone is several feet away; the lifter should not glance at it to know recording started, a rep registered, tracking was lost, or the set stopped. | BodyPark’s dedicated speaker/earbud loop; Flex’s Watch goal of removing phone interaction. | `TrainerSessionCues` only produces countdown haptics; product spec contemplates conservative predefined cues. [R4] [R15] | `TrainerSessionCues`, capture/count events from TrainerRuntime, user preference and interruption policy in TrainerApp. Start with state/rep confirmation—not form coaching. | End-to-end cue latency versus rep completion, noisy-gym audibility, headphones, VoiceOver/audio-session interaction, duplicate/late cues, false rep cost, distraction under heavy load, and user control. | **Medium** | **After** current pass and count stress testing |
| 5. One evidence-backed between-set takeaway | Users need one thing to try next set, not a dense report or live lecture. | BodyPark’s rest-interval summary; Flex’s one-cue-at-a-time, praise-plus-correction review. | Review has a “form takeaway unavailable” state because all clean criteria are unassessed. [R13] [R17] [R26] | One validated criterion at a time in `SquatAnalyzer`; `TrainerSetAnalysisMapper`; `SetAnalysisSummary`; review card and later optional audio. Keep clean count separate from cue. | Expert-labeled positive/negative sets across users and setups; per-rep agreement, false-positive budget, camera sensitivity, user comprehension, and evidence that the cue is actionable. Start with the single best-validated criterion, not a score. | **Large** | **After** current pass and after a form-gate evidence milestone |
| 6. Back-squat-only “analysis unavailable” recovery | A failed camera analysis should not erase the fact that a squat set happened or force a fabricated result. | BodyPark’s separate AI, Record, and Log modes. | Runtime supports retry/discard and corrections after a result, but no bounded manual-set recovery when analysis cannot finalize. Generic logging is intentionally out of scope. [R4] [R13] [R18] [R19] | A back-squat-only unavailable-analysis result in TrainerCore; manual count/load entry with explicit user provenance; review/summary/persistence treatment. No generic exercise logger. | Real failed-finalization and zero-count scenarios; verify users understand “logged by you, not analyzed,” cannot create fake clean evidence accidentally, and can discard safely. | **Medium** | **After** current pass |
| 7. Local squat history with next-session continuity | Today’s corrected result is now stored locally, but the next workout still has no prior-load lookup or visible history. | Flex’s inline prior performance/return loop; BodyPark’s history. | M2.13a persists corrected structured set evidence without pose streams or video bytes, but physical restart acceptance and all history UI remain open. [R8] [R18] [R21] | Complete physical save/relaunch/correction/discard durability, then surface last load and a small squat-only history from the existing boundary. | Relaunch/crash/background lifecycle on device; correction/discard durability; unit handling; low-confidence/unavailable interpretation; confirm prior load helps rather than anchoring unsafe progression. | **Medium** | **After** physical M2.13 acceptance |

### Explore later

1. **Rep-synchronized local video review and standardized side-by-side comparison.** Valuable for self-correction and for auditing the analyzer, but it needs a deliberate file-retention/privacy model, synchronization, storage limits, and standardized camera geometry. Do not store video or per-frame pose inside structured set records. Inspiration: both competitors.

2. **Apple Watch as a remote/status surface.** It could arm/stop a set, show tracking state, provide haptics, and capture heart rate without making HR a form signal. It should follow a trustworthy phone-camera loop, not precede it. Inspiration: Flex’s low-friction Watch experience.

3. **Validated longitudinal form trends.** A depth/tempo/lockout trend is only meaningful after the metric is repeatable across camera height, distance, device, clothing, load, and occlusion. Inspiration: both competitors’ progress presentation; avoid their implied precision.

4. **User-selectable coaching tone and cue modality.** Calm versus energetic language may improve adherence, but only after cue correctness, frequency, and timing are proven. Inspiration: BodyPark coaching personas.

5. **Landscape or alternate placement modes.** These may improve rack framing, but each geometry reopens validation and should be treated as a separate capture contract.

6. **Additional squat variants, then other exercises.** Reuse the interface only after back squat meets defined count and form gates. Exercise-library breadth is not a moat if each movement is shallowly supported.

7. **Programming support.** A conservative, local next-session suggestion could eventually use durable trusted history, but it requires its own evidence and safety evaluation. It should not begin as a general-purpose LLM planner.

8. **Dedicated capture hardware.** Only explore if phone placement remains the dominant validated retention problem and the squat product demonstrates repeat value. BodyPark shows the interaction benefit and the added pairing, network, charging, subscription, and manufacturing burden.

### Deliberately avoid

1. **Aggregate “form scores” or percent-perfect results.** They collapse several uncertain judgments into a falsely precise number and obscure which evidence failed.

2. **Injury-prevention, spinal-protection, or “lab-grade” positioning.** A monocular consumer camera and unvalidated heuristics do not support those claims.

3. **Force, power, center-of-gravity, muscle heat maps, or VBT claims from phone video without calibration and external validation.**

4. **Automatic exercise recognition and a 1,000-exercise library.** Explicit Back Squat selection is currently a feature, not a limitation.

5. **Conversational workout planning, auto-progression, and deloading now.** These create a second high-risk inference system before the first one is trustworthy.

6. **Social feed, public leaderboards, streak pressure, routine scanning, and highlight generation.** They expand moderation, persistence, identity, and product surface without improving squat truth.

7. **Accounts, cloud sync, or a subscription wall in v1.** They contradict the locked local-first quick-start direction and add failure modes before repeat value exists.

8. **Frequent live biomechanical coaching.** Loaded squats demand low interruption and a very low false-positive rate. Prefer setup/status cues and one post-set correction until evidence supports more.

9. **“Perfect rep” celebrations on ambiguous evidence.** Celebrate completion and consistency, not an uncalibrated verdict.

10. **Treating a patent, proprietary dataset, press release, or one successful set as accuracy proof.**

---

## 6. Highest-value conclusions

### 1. Five most consequential product gaps

1. **No broad physical truth yet.** Production counting has one narrow 8/8 observation, one device/orientation, and no representative lifter/load/rack/occlusion set. The app cannot credibly claim reliable squat analysis until this changes. [R8] [R10] [R12]

2. **No actual form product.** Counted-versus-clean semantics are excellent, but every clean criterion is unavailable. The central coaching value proposition is therefore not yet delivered. [R17] [R26]

3. **Capture health is clearer before the set than during it.** Setup can be green, then degrade under walkout, plate/rack occlusion, clothing, fatigue, phone movement, or gym traffic without a sufficiently legible user recovery state. [R19] [R22] [R25]

4. **No durable value or return loop.** Corrected sets and summaries disappear; prior load and validated progress are unavailable next session. Both competitors make accumulated history central. [R8] [R18] [R21]

5. **The lifter is still too dependent on the distant phone and an abstract result.** There is no audio/status loop, no video evidence, no explanation of incomplete candidates, and no physically verified correction journey. [R10] [R13] [R15]

### 2. Three areas where our app may have a stronger foundation

1. **Evidence provenance and uncertainty.** Provisional/finalized, counted/clean, unavailable/zero, analyzer/user evidence, and standard/overridden capture are distinct states rather than copy layered over one score. [R16] [R17] [R18] [R28] [R29]

2. **Trust-preserving correction.** Immutable analyzer output plus ordered user corrections can explain how the current result came to exist. Neither competitor publicly demonstrates equivalent auditability. [R18] [R29]

3. **Narrow, fail-closed architecture.** App-owned pose types isolate the SDK; UI does not own analysis; retention is bounded; Stop has an exact boundary; delivery loss invalidates rather than inventing evidence; unsupported exercises stay hidden. [R19] [R20] [R23] [R24] [R30] [R31] [R32]

These are stronger foundations, not proof of a stronger product. They matter only if physical evidence and a usable return loop are built on top.

### 3. Single competitor behavior to copy first

**Copy BodyPark’s “make camera eligibility visible before and during the set” behavior: an exercise-specific side/full-body placement preview, visible tracking state, and an explicit out-of-frame recovery path.**

This should be the first post-validation-pass product change because it improves the input to every downstream count and form decision without making a new biomechanical claim. It fits the existing `SetupGate`, `PoseSetupEvidence`, runtime event pipeline, low-confidence result, and fail-closed semantics.

### 4. Single tempting feature to explicitly postpone

**Postpone Flex-style conversational workout planning and automatic progression.**

It requires durable history, broader exercise support, readiness/recovery interpretation, recommendation safety, and ongoing content/support operations. Flex demonstrates how attractive the all-in-one surface is—and how technical differentiation plus broad adoption can still fail to create sustainable economics. Our near-term advantage is trustworthy squat evidence, not an AI persona.

### 5. Proposed next-three-milestone roadmap

This is a research proposal, not an approved renumbering or status change to existing milestone files.

#### Proposed milestone A — Close the physical truth loop

**Outcome:** a documented back-squat capture/count baseline on real devices in realistic conditions.

- Complete the current physical UI pass without changing its baseline behavior.
- Run a labeled matrix across lifters, loads, rack/plate occlusion, clothing, lighting, camera height/distance, near/far side, tempo, fatigue, partials, pauses, walkout/rerack, and gym traffic.
- Verify Stop/finalization, zero-rep, retry/discard, correction, rollback, low-confidence, multi-set summary, and Done.
- Define separate acceptance evidence for full-sequence count, false positives, missed reps, capture invalidation, and user recovery.
- Exit only with explicit known-good and known-unsupported setup envelopes. No form claims.

#### Proposed milestone B — Trustworthy post-set squat coaching

**Outcome:** one validated movement-quality conclusion, tied to the exact rep and presented conservatively.

- Add continuous in-set tracking health and invalid/unavailable semantics.
- Validate one clean criterion at a time—whichever has the best label agreement and camera robustness, not whichever markets best.
- Show rep-anchored evidence, one positive observation, and one prioritized next-set cue; keep clean count separate from counted reps.
- Add bounded status/rep audio only after latency and false-count testing; post-set form audio only after the cue itself is validated.
- Preserve correction provenance and allow an explicit “analysis unavailable / log manually” recovery for Back Squat only.

#### Proposed milestone C — Local continuity and repeat value

**Outcome:** the app remembers trustworthy squat work and makes the next session easier without becoming a planner.

- Persist corrected set results, originals/provenance, capture confidence, and validated assessment locally.
- Add squat-only history, previous load, prior count/clean evidence, and low-confidence/unavailable labels.
- Provide a simple return action such as “Repeat Back Squat” with last corrected load—not an automatic load prescription.
- Explore rep-synchronized local video as a separately retained artifact with clear deletion/storage behavior.
- Gate any trend on measurement stability; remain one exercise, local-first, and account-free.

### 6. Ten concrete questions for the next physical-device testing session

1. **Placement comprehension:** Without reading the repository, can a lifter place the phone so head, bar, hips, knees, and feet are all visibly usable, and can they explain which side the app expects?

2. **Gate truth:** Across two phone heights and two distances, do the four setup checks turn green only when the resulting pose is actually usable through walkout and the bottom position—not merely while standing still?

3. **Arm-and-walk-away clarity:** After entering load and tapping `Arm set`, does the lifter know whether to move the phone, move into frame, wait, or tap again? Can the weak-setup option be found without looking like an equal primary action?

4. **Countdown safety:** Does five seconds leave enough time to establish stance and brace without rushing? At countdown end, does a last-moment framing failure reset or override in a way the lifter understands?

5. **Counting boundary:** For a set containing normal, intentionally shallow-but-complete, partial, paused, and aborted reps, which motions become provisional reps, which survive finalization, and are any walkout/rerack or small leg movements falsely counted?

6. **Occlusion and recovery:** What happens when a plate or rack upright hides the far hip/knee, the lifter briefly leaves frame, clothing hides contours, or another person crosses behind? Does the app recover cleanly, reset calibration, or create a plausible but wrong final count?

7. **Stop integrity:** On tapping Stop, does the camera disappear immediately, does processing feel intentional, and does the final review include the last completed rep without including the walk back to the phone?

8. **Failure and zero-rep recovery:** Can the tester successfully exercise processing retry/discard, a true zero-rep set, a missed all-reps set, immediate zero-rep discard, and detected-rep discard confirmation without accidentally saving or losing evidence?

9. **Correction trust:** Can the tester edit load/count/clean, dismiss the keyboard, understand validation errors, identify user-entered versus analyzer evidence, see provisional/final differences, and verify corrected load carries to Next Set while discard rolls it back?

10. **Session closure:** After normal, corrected, zero/failed, discarded, and low-confidence sets, does End Workout show only the right rows/totals/provenance, avoid claiming form trends, and return via Done without stale state?

---

## Public source register

All public sources were accessed **2026-07-26**. “Current page” means no publication date was displayed and the surface can change.

### BodyPark ATOM

| ID | Source | Publication/update date | Evidence role |
|---|---|---|---|
| BP1 | [Official product, pricing, membership, and FAQ][BP1] | Current page | Hardware, price, tiers, 34-point/96% claims, reports, Preview labels |
| BP2 | [Official ATOM experience/features page][BP2] | Current page | Workflow, coaching, planning, performance and safety marketing |
| BP3 | [Official DeepBody/hardware technical page][BP3] | Current page | Camera, edge-processing, keypoint, latency, privacy claims |
| BP4 | [Apple App Store listing, releases, and reviews][BP4] | Current version 1.9.0 shown as Jul 18; 2026 inferred from current-page chronology | Shipped app surfaces, pricing, compatibility, small review sample |
| BP5 | [Official detailed release notes][BP5] | Entries through 2026-07-10 | Framing, half-rep, summary, modes, video, recognition fixes |
| BP6 | [Official OTA/app update log][BP6] | Latest observed 2.9.381, 2026-07-24 | Current shipping cadence and AI/Record mode |
| BP7 | [Official “One Month In, No Slowing Down”][BP7] | 2026-07-10 | First-party complaints/priorities and planned error flagging |
| BP8 | [Official next-generation DeepBody engine note][BP8] | 2026-07-03 | Old false-positive admission, temporal engine, first 50 exercises |
| BP9 | [BPKA1 device manual reproduction][BP9] | 2026-05-03 | Pairing, placement, network constraints, device operation |
| BP10 | [Tech for Travel hands-on review, Tom Payne][BP10] | 2026-07-20 | Ten-day usability observation; quiet/crowded gym tradeoffs |
| BP11 | [Tech for Travel disclosure][BP11] | Current policy | Affiliate-evidence qualification |
| BP12 | [BodyPark/FITURE privacy policy][BP12] | Effective 2026-05-09 | Movement/video/cloud data handling |
| BP13 | [BodyPark/FITURE terms][BP13] | Effective 2025-12-01 | Non-medical scope and user responsibility |
| BP14 | [BodyPark-provided availability release][BP14] | 2026-07-09 | Shipment/general-availability status |
| BP15 | [Official BodyPark brand/history page][BP15] | Current page | Company/technology-history moat claims |
| BP16 | [Muscle & Fitness partner advertorial][BP16] | Indexed around 2025-12; page undated | Explicitly excluded as independent validation |

### Flex AI Workout Trainer

| ID | Source | Publication/update date | Evidence role |
|---|---|---|---|
| F1 | [Apple App Store listing and release history][F1] | Current version 3.1 shown as Apr 9; 2026 inferred from chronology after dated Nov 2025 releases | Product surface, pricing, compatibility, releases |
| F2 | [Apple App Store reviews][F2] | Individual dates displayed, 2022–2026 | User experience, complaints, logging/progression observations |
| F3 | [Official Flex homepage][F3] | Current page | Lex, progression, social, Watch, history, utilities |
| F4 | [Official form-feedback page/demonstration][F4] | Current page | Real-time marketing, rep-level review UI, selected testimonials |
| F5 | [Official technical/product history article][F5] | 2025-05-30 | Dataset/history and beta claims |
| F6 | [Flex-provided launch press release][F6] | 2025-12-10 | 30+ points, on-device, dataset and outcome marketing |
| F7 | [Parmar, Gharat, and Rhodin, ECCV paper][F7] | ECCV 2022; arXiv first submitted 2022-02-28 | Primary technical evidence and Fitness-AQA results |
| F8 | [WO2020252599A1 patent-family publication][F8] | Published 2020-12-24; this WIPO record is ceased | Rep-detector/error-model architecture, not current legal status or efficacy |
| F9 | [GainFrame commercial comparison article][F9] | 2026-05-27 | Weak observation that form check is post-set; written by GainFrame’s founder to market GainFrame, with no Flex test method disclosed |
| F10 | [Flex privacy policy][F10] | Last updated 2025-10 | Profile fields, video/form-feedback retention, AI processing |
| F11 | [BetaKit shutdown report with CEO statement][F11] | 2026-07-20 | Active-operations and wind-down status |
| F12 | [Flex AI Product Hunt launch/discussion][F12] | Launched approximately 2025-11; page uses relative dates | Maker explanation, onboarding/design observation |
| F13 | [US Patent 12,640,249 record][F13] | Granted 2026-05-26 | US grant status; a grant is not evidence of product accuracy |

## Repository evidence register

| ID | Repository source | What it supports |
|---|---|---|
| R1 | [`README.md`][R1] | Product positioning and reference setup guidance |
| R2 | [`ios/README.md`][R2] | Native workspace and target state |
| R3 | [`native_rebuild_agent_handoff.md`][R3] | Source-of-truth current state, locked decisions, open physical work |
| R4 | [`rebuild_product_spec.md`][R4] | Quick-start/local-first/squat-first scope, counted vs clean, conservative cues |
| R5 | [`pose_bakeoff_plan.md`][R5] | Bakeoff method and evidence bar |
| R6 | [`decision_log.md`][R6] | Locked architecture/product decisions |
| R7 | [`M1_pose_bakeoff_tasks.md`][R7] | Milestone 1 evidence and task state |
| R8 | [`M2_back_squat_vertical_slice_tasks.md`][R8] | Implemented/pending vertical-slice work and physical evidence limits |
| R9 | [`2026-07-11_post_m2_11_roadmap_review.md`][R9] | Review/correction atomicity and roadmap recommendations |
| R10 | [`2026-07-24_native_verification_harness.md`][R10] | What contract tests prove and what still requires device/physical evidence |
| R11 | [`2026-07-09_engine_selection.md`][R11] | MediaPipe selection and bakeoff limitations |
| R12 | [`live_camera_viability/README.md`][R12] | Real-device FPS/latency/pose presence and occlusion observations |
| R13 | [`TrainerRootView.swift`][R13] | Entire SwiftUI workout journey and current presentation |
| R14 | [`TrainerLivePoseCamera.swift`][R14] | Rear camera, MediaPipe, portrait capture and live stream |
| R15 | [`TrainerSessionCues.swift`][R15] | Countdown haptics and absence of audio coaching |
| R16 | [`SetupGate.swift`][R16] | Four setup checks and weak-setup override semantics |
| R17 | [`SetAnalysisSummary.swift`][R17] | Final counted/clean/unavailable and per-rep summary semantics |
| R18 | [`QuickSession.swift`][R18] | In-memory session, immutable originals, correction application, load carry |
| R19 | [`ActiveSetPoseIngestion.swift`][R19] | Bounded retention and fail-closed delivery loss |
| R20 | [`TrainerPoseObservationPipeline.swift`][R20] | UI-independent pose fan-out |
| R21 | [`SessionSummary.swift`][R21] | Corrected/non-discarded transient summary semantics |
| R22 | [`PoseSetupEvidence.swift`][R22] | Full-body, likely-side-view, visible-side, and confidence evidence |
| R23 | [`ExerciseCatalog.swift`][R23] | One supported exercise and hidden planned variants |
| R24 | [`PoseFrame.swift`][R24] | App-owned 2D pose frame |
| R25 | [`TrainerSetupGateController.swift`][R25] | Core Motion stability, exact stop boundary, controller behavior |
| R26 | [`SquatAnalyzer.swift`][R26] | Production count state machine, calibration, and unassessed clean criteria |
| R27 | [`SetupGateSignalWindow.swift`][R27] | Bounded optional setup-evidence window |
| R28 | [`ActiveSetCapture.swift`][R28] | Capture phases, provisional/final count, zero-rep and discard semantics |
| R29 | [`SetCorrection.swift`][R29] | Typed correction values and validation |
| R30 | [`TrainerRuntime.swift`][R30] | Runtime composition boundary |
| R31 | [`PoseLandmark.swift`][R31] | App-owned landmark identities and confidence |
| R32 | [`LivePoseStream.swift`][R32] | Live event, sequence, and inference-latency contract |
| R33 | [`StartSetArming.swift`][R33] | Deliberate arm-before-countdown state |
| R34 | [`PreSetCountdown.swift`][R34] | Five-second countdown domain behavior |

[BP1]: https://www.bodypark.fit/products/bodypark-atom
[BP2]: https://www.bodypark.fit/atom
[BP3]: https://www.bodypark.fit/tech
[BP4]: https://apps.apple.com/us/app/bodypark-atom-ai-trainer/id6756965693
[BP5]: https://www.bodypark.fit/news?webId=01e8e174e00a404587300903432e9f82
[BP6]: https://www.bodypark.fit/logs
[BP7]: https://www.bodypark.fit/news?webId=2cca9fd659534b1fbd0af6ff526f4565
[BP8]: https://www.bodypark.fit/news?webId=3a5b97c578b54ed1b66853b9ef3e6486
[BP9]: https://manuals.plus/bodypark/bpka1-atom-ai-fitness-companion-device-manual
[BP10]: https://techfortravel.co.uk/tech-review-bodypark-atom-review-ai-coaching-for-travel-workouts/
[BP11]: https://techfortravel.co.uk/privacy/
[BP12]: https://shopify.bodypark.fit/pages/privacy
[BP13]: https://shopify.bodypark.fit/pages/terms
[BP14]: https://www.prnewswire.com/news-releases/bodypark-atom-the-most-backed-kickstarter-ai-fitness-companion-is-now-in-stock-and-available-for-purchase-302820808.html
[BP15]: https://www.bodypark.fit/brand
[BP16]: https://www.muscleandfitness.com/features/from-our-partners/is-bodypark-atom-worth-buying-a-deep-review-buying-guide-for-the-worlds-first-ai-fitness-companion/

[F1]: https://apps.apple.com/us/app/flex-ai-workout-trainer-log/id1446354547
[F2]: https://apps.apple.com/us/app/1446354547?platform=iphone&see-all=reviews
[F3]: https://www.flexfitnessapp.com/
[F4]: https://www.flexfitnessapp.com/feedback/
[F5]: https://flexfitnessapp.com/blog/the-journey-behind-the-innovation/
[F6]: https://www.accessnewswire.com/newsroom/en/biotechnology/flex-ai-launches-first-commercial-real-time-exercise-form-analysis-platform-after-sev-1116154
[F7]: https://www.ecva.net/papers/eccv_2022/papers_ECCV/papers/136980104.pdf
[F8]: https://patents.google.com/patent/WO2020252599A1/en
[F9]: https://gainframe.app/blog/best-ai-personal-trainer-apps/
[F10]: https://flexfitnessapp.com/privacy-policy/
[F11]: https://betakit.com/personal-training-app-flex-ai-is-shutting-down/
[F12]: https://www.producthunt.com/products/flex-ai-your-ai-personal-trainer
[F13]: https://patents.justia.com/patent/12640249

[R1]: ../../README.md
[R2]: ../../ios/README.md
[R3]: ../native_rebuild_agent_handoff.md
[R4]: ../rebuild_product_spec.md
[R5]: ../pose_bakeoff_plan.md
[R6]: ../decision_log.md
[R7]: ../tasks/M1_pose_bakeoff_tasks.md
[R8]: ../tasks/M2_back_squat_vertical_slice_tasks.md
[R9]: ../design_reviews/2026-07-11_post_m2_11_roadmap_review.md
[R10]: ../design_reviews/2026-07-24_native_verification_harness.md
[R11]: ../bakeoff_results/2026-07-09_engine_selection.md
[R12]: ../bakeoff_results/2026-05-25_live_camera_viability/README.md
[R13]: ../../ios/TrainerApp/Sources/TrainerRootView.swift
[R14]: ../../ios/TrainerApp/Sources/TrainerLivePoseCamera.swift
[R15]: ../../ios/TrainerApp/Sources/TrainerSessionCues.swift
[R16]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/SetupGate.swift
[R17]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/SetAnalysisSummary.swift
[R18]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/QuickSession.swift
[R19]: ../../ios/Packages/TrainerRuntime/Sources/TrainerRuntime/ActiveSetPoseIngestion.swift
[R20]: ../../ios/Packages/TrainerRuntime/Sources/TrainerRuntime/TrainerPoseObservationPipeline.swift
[R21]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/SessionSummary.swift
[R22]: ../../ios/Packages/PoseCore/Sources/PoseCore/PoseSetupEvidence.swift
[R23]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/ExerciseCatalog.swift
[R24]: ../../ios/Packages/PoseCore/Sources/PoseCore/PoseFrame.swift
[R25]: ../../ios/TrainerApp/Sources/TrainerSetupGateController.swift
[R26]: ../../ios/Packages/SquatAnalysis/Sources/SquatAnalysis/SquatAnalyzer.swift
[R27]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/SetupGateSignalWindow.swift
[R28]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/ActiveSetCapture.swift
[R29]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/SetCorrection.swift
[R30]: ../../ios/Packages/TrainerRuntime/Sources/TrainerRuntime/TrainerRuntime.swift
[R31]: ../../ios/Packages/PoseCore/Sources/PoseCore/PoseLandmark.swift
[R32]: ../../ios/Packages/PoseCore/Sources/PoseCore/LivePoseStream.swift
[R33]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/StartSetArming.swift
[R34]: ../../ios/Packages/TrainerCore/Sources/TrainerCore/PreSetCountdown.swift

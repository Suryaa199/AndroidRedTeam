---
title: "Appendix E: Troubleshooting"
description: "Every common error, its cause, and its fix -- consolidated from all chapters and labs"
---

> **Usage:** When something goes wrong, come here first. This appendix consolidates every error pattern from across the book and labs into a single searchable reference. Errors are organized by the phase of the workflow where they occur: setup, decode/build, patching, installation, runtime, and injection.

---

## Phase 1: Environment Setup

### Java

| Error | Cause | Fix |
|-------|-------|-----|
| `command not found: java` | Java not installed or not on PATH | Install: `brew install openjdk@21` (macOS), `sudo apt install openjdk-21-jdk` (Linux) |
| `UnsupportedClassVersionError` | Java version too old for patch-tool | Install Java 17 or higher. Verify with `java --version` |
| `Error: could not find or load main class` | Wrong working directory or corrupt JAR | Run from project root where `patch-tool.jar` lives |
| `Unable to access jarfile patch-tool.jar` | Not in project root, or JAR missing | `cd` to project root. Verify JAR exists with `ls -la patch-tool.jar` |

### Android SDK

| Error | Cause | Fix |
|-------|-------|-----|
| `command not found: adb` | platform-tools not on PATH | Add `export PATH="$PATH:$ANDROID_HOME/platform-tools"` to shell profile |
| `command not found: zipalign` | build-tools not on PATH | Add `export PATH="$PATH:$ANDROID_HOME/build-tools/36.0.0"` to shell profile |
| `ANDROID_HOME is not set` | Environment variable missing | Add `export ANDROID_HOME=~/Library/Android/sdk` (macOS) or `export ANDROID_HOME=~/Android/Sdk` (Linux) |
| `No build-tools found` | SDK build-tools not installed | Install via Android Studio SDK Manager or `sdkmanager "build-tools;36.0.0"` |

### Emulator

| Error | Cause | Fix |
|-------|-------|-----|
| `emulator: ERROR: No AVD specified` | AVD not created | Create with Android Studio AVD Manager or `avdmanager create avd` |
| `emulator: ERROR: x86_64 emulation currently requires hardware acceleration` | KVM not enabled (Linux) or HAXM not installed (Intel Mac) | Linux: `sudo apt install qemu-kvm`. Intel Mac: install HAXM from SDK Manager |
| `adb devices` shows `offline` | Emulator still booting or adb connection stale | Wait 15-30 seconds. If persistent: `adb kill-server && adb start-server` |
| `adb devices` shows `unauthorized` | Authorization dialog not accepted | Check emulator screen for USB debugging prompt. Accept it. |
| Emulator extremely slow | Wrong architecture image (x86 on ARM or vice versa) | Apple Silicon: use `arm64-v8a` image. Intel: use `x86_64` image |
| `PANIC: Broken AVD system path` | System image missing or corrupt | Reinstall system image via SDK Manager |

### apktool

| Error | Cause | Fix |
|-------|-------|-----|
| `command not found: apktool` | Not installed | `brew install apktool` (macOS), manual install (Linux -- see Appendix D) |
| `brut.androlib.AndrolibException` during decode | APK uses newer resource format than apktool supports | Update apktool to 2.9.0+ or 3.0.1+ |
| `Exception in thread "main" brut.androlib.exceptions.InFileNotFoundException` | APK path is wrong | Verify path with `ls -la target.apk` |

---

## Phase 2: Decode and Rebuild

### Decoding

| Error | Cause | Fix |
|-------|-------|-----|
| `Could not decode arsc file` | Resource table uses format apktool doesn't support | Update apktool. If still fails, try `apktool d --no-res target.apk -o decoded/` to skip resource decoding |
| `W: Could not decode attr value` | Non-standard attribute in manifest | Warning only -- usually safe to ignore |
| Only one `smali/` directory (expected multiple) | apktool 2.x behavior vs 3.x | Normal for apktool 2.x. All classes are in `smali/`. With 3.x you get `smali_classes2/`, etc. |
| Decode succeeds but `smali/` is empty | APK is a split APK and `base.apk` was not decoded | Ensure you decoded `base.apk`, not a config split |

### Rebuilding

| Error | Cause | Fix |
|-------|-------|-----|
| `brut.androlib.exceptions.AndrolibException: brut.common.BrutException: could not exec` | aapt/aapt2 binary missing or wrong architecture | Ensure build-tools are installed. On Apple Silicon, use ARM build-tools |
| `error: resource X not found` | Resource reference broken during decode/edit | Did you accidentally edit a resource XML with invalid syntax? Check the error line number |
| `W: error: failed to open directory: res/values-XXX` | Locale directory corruption | Delete the problematic locale directory -- it's usually not needed |
| Build produces APK but it's much smaller than expected | Resources excluded or `--no-res` was used during decode | Re-decode without `--no-res` flag |

### Signing

| Error | Cause | Fix |
|-------|-------|-----|
| `Failed to load signer "signer #1"` | Wrong keystore password or alias | Double-check `--ks-pass` and `--ks-key-alias` values |
| `The specified keystore file does not exist` | Keystore path wrong | Create one: `keytool -genkeypair -v -keystore debug.keystore -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -storepass android -keypass android` |
| `zipalign: error: unsupported` | Attempting to zipalign an already-signed APK | Run zipalign BEFORE apksigner, not after |
| APK signed but `apksigner verify` fails | zipalign and apksigner from different build-tools versions | Use both from the same `build-tools/XX.Y.Z/` directory |

---

## Phase 3: Patching (patch-tool)

| Error | Cause | Fix |
|-------|-------|-----|
| `[-] Failed to decode APK` | apktool not on PATH or APK is corrupt | Verify `apktool --version` works. Try decoding manually first |
| `[-] Application class not found` | Manifest has no `android:name` in `<application>` | patch-tool should handle this by creating one. If it fails, check the APK is valid |
| `[!] No Surface(SurfaceTexture) found` | Target doesn't use Camera2 | Normal for CameraX-only targets. Expected warning, not an error |
| `[!] No onLocationChanged(Location) found` | Target doesn't use legacy LocationManager | Normal for modern targets using FusedLocationProvider |
| `[!] No onSensorChanged(SensorEvent) found` | Target doesn't register a SensorEventListener | Normal -- means liveness is purely visual, no sensor correlation |
| `[-] Error during rebuild` | Modified smali has syntax errors | Check patch-tool output for specific file/line. Manual smali edits may conflict |
| All lines show `[!]` warnings, no `[+]` successes | Wrong target APK or APK already stripped | Verify you're patching the correct APK. Re-pull from device if needed |

---

## Phase 4: Installation

| Error | Cause | Fix |
|-------|-------|-----|
| `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | APK signed with different key than installed version | `adb uninstall <package>` first, then install |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | APK built for ARM but emulator is x86, or vice versa | Use matching architecture. ARM APK needs ARM emulator |
| `INSTALL_FAILED_OLDER_SDK` | APK's `minSdkVersion` higher than emulator's API level | Use emulator with API level >= APK's minimum |
| `INSTALL_FAILED_INVALID_APK` | APK not signed, not aligned, or corrupt | Re-run: `apktool b`, then `zipalign`, then `apksigner sign` |
| `INSTALL_FAILED_VERIFICATION_FAILURE` | Signature scheme issue | Try signing with `--v1-signing-enabled true --v2-signing-enabled true` |
| `INSTALL_PARSE_FAILED_NO_CERTIFICATES` | APK unsigned | Run `apksigner sign` on the APK |
| `pm grant` returns `Unknown permission` | App doesn't declare that permission in its manifest | Harmless -- skip that permission |
| `appops set` returns error | API level too old for that appops command, or wrong package name | Verify package name. `MANAGE_EXTERNAL_STORAGE` requires API 30+ |

---

## Phase 5: Runtime and App Behavior

### App Won't Launch

| Symptom | Cause | Fix |
|---------|-------|-----|
| App crashes immediately (no UI) | Signature verification killing the process | Find and neutralize signature check (Ch 15, Technique 2) |
| Splash screen appears then crashes | DEX integrity check or delayed signature check | Check logcat: `adb logcat \| grep -iE "integrity\|signature\|tamper"` |
| "App not installed" toast | Installation didn't complete | Re-run `adb install -r patched.apk` |
| Black screen then crash | Missing dependency or resource error from rebuild | Check logcat for `ClassNotFoundException` or `ResourceNotFoundException` |
| `java.lang.VerifyError` in logcat | Smali patch introduced a type conflict | Review manual smali edits. Register type mismatch at a branch merge point. See Ch 13 |

### App Launches But Behaves Wrong

| Symptom | Cause | Fix |
|---------|-------|-----|
| Security warning dialog on launch | Installer verification triggered | Neutralize installer check (Ch 15) or nop the dialog |
| App launches but features are grayed out | Integrity check silently blocking functionality | Grep for integrity checks that set feature flags rather than crashing |
| Network calls fail with SSL errors | Certificate pinning active | Patch `network_security_config.xml` and nop `CertificatePinner` calls (Ch 15) |
| App works but crashes after 30-60 seconds | Delayed integrity check or server-side attestation failure | Check logcat for the exception. May need to nop a periodic check |
| "Mock location detected" message | App detected mock location despite patches | Check patch output for `isFromMockProvider`/`isMock`. May use non-standard detection |
| Camera preview shows real camera, not injected frames | FrameInterceptor not armed | Push frames to `/sdcard/poc_frames/` and force-stop + relaunch the app |

---

## Phase 6: Injection Issues

### Camera Injection

| Symptom | Cause | Fix |
|---------|-------|-----|
| No `FRAME_DELIVERED` in logcat | Payload directory empty or wrong path | `adb shell ls /sdcard/poc_frames/` -- verify PNGs exist |
| `FRAME_DELIVERED` but no `FRAME_CONSUMED` | App doesn't call `toBitmap()` on this code path | Check recon -- may use `getPlanes()` or `getImage()` instead. Hooks should cover all paths |
| `FRAME_DELIVERED` but ML Kit finds no face | Frame quality too low, face too small, or using gray test frames | Use real face frames (Option A) or ensure face fills 60%+ of the 640x480 frame |
| `FrameStore: 0 files loaded` | Directory exists but contains no PNGs | Verify filenames end in `.png` (lowercase). FrameStore scans for PNG specifically |
| Frame delivery rate very low (< 5 fps) | Emulator limitation | Normal on emulators. Physical devices deliver at full camera frame rate |
| Camera preview shows injected frames but ML Kit bounding box flickers | Frame sequence too short, causing visible looping | Add more frames (45-75 for smooth looping at 15 fps) |
| `intercept swapped ImageProxy` but app still shows live camera | App has two camera instances -- preview and analysis are separate | The analysis pipeline is hooked (ML Kit sees your frames), but the preview may still show real camera. This is normal -- the SDK processes your frames |
| QR code not decoded | QR too small in 640x480 frame, or resolution mismatch | Regenerate QR code at larger size. Ensure it fills significant portion of the frame |

### Location Injection

| Symptom | Cause | Fix |
|---------|-------|-----|
| No `LOCATION_DELIVERED` in logcat | App hasn't queried location yet | Navigate to the location/geofence screen in the app |
| Coordinates delivered but geofence fails | Coordinates outside the expected radius | Re-check recon for exact geofence center and radius. Tighten coordinates |
| `LOCATION_CALLBACK_HIT` is zero but `LOCATION_DELIVERED` > 0 | App uses `getLastLocation()` not continuous callbacks | Normal -- different API path, still hooked |
| Location delivered but map shows wrong position | Config JSON has lat/lng swapped | Double-check: latitude is the first value (e.g., 40.7580 for NYC), longitude second (-73.9855) |
| `JSONException` when loading location config | Malformed JSON | Validate with `python3 -m json.tool /sdcard/poc_location/config.json` |

### Sensor Injection

| Symptom | Cause | Fix |
|---------|-------|-----|
| No `SENSOR_DELIVERED` in logcat | App has no `SensorEventListener` | Verify recon -- `onSensorChanged` may not exist in this target |
| `SENSOR_DELIVERED` but `SENSOR_LISTENER_HIT` is zero | Wrong sensor type -- app listens for gyroscope but you only inject accelerometer | Check which `TYPE_*` constants appear in recon. Configure all required types |
| Liveness fails despite frame injection | Sensor data doesn't match visual motion | Match sensor config to camera frames. Head tilt left = corresponding accelerometer shift |
| Sensor values look wrong in logcat | Config values incorrect | Gravity magnitude should be ~9.81. Check that `sqrt(accelX^2 + accelY^2 + accelZ^2) ≈ 9.81` |

---

## Phase 7: Anti-Tamper Evasion

| Symptom | Cause | Fix |
|---------|-------|-----|
| App crashes immediately after your smali edit | Nop'd the wrong branch or broke method structure | Verify `.locals` count >= highest register used. Check you didn't nop past a required instruction |
| Forced return `true` but app still fails | Multiple call sites -- you patched one but another still runs the real check | `grep -rn "verifySignature\|checkIntegrity"` to find ALL call sites |
| Nop'd the branch but app now has a blank screen | Failure path shows UI (error fragment) rather than crashing | Trace the control flow more carefully. The "success" path may need to be explicitly taken |
| Certificate pinning bypassed but API calls return 401/403 | Server rejects requests without valid client certificate or attestation token | Server-side attestation -- client-side patching alone cannot fix this |
| App works after evasion but crashes after patch-tool runs | patch-tool modified a class that conflicts with your evasion edits | Check if your manually patched method was also targeted by the patch-tool. Resolve the conflict |
| `VerifyError` after smali edits | Register type conflict at a merge point | Use different registers for different types. Do not reuse a register for both int and object across branches |

---

## Phase 8: Asset Modification

| Symptom | Cause | Fix |
|---------|-------|-----|
| `JSONException` at runtime after editing config | Invalid JSON syntax (missing comma, bracket, or quote) | Validate: `python3 -m json.tool decoded/assets/config.json` |
| `NullPointerException` after removing a JSON key | App expected the key to exist | Don't remove keys -- change their values instead |
| ML model replacement causes crash | Replacement model has different input/output tensor shapes | Inspect original model's tensor shapes and match them exactly |
| Firebase Remote Config edits have no effect | App successfully fetched server-side values that override defaults | Block Firebase connectivity or edit the fetched config cache |
| Edited XML resource causes build failure | XML syntax error (unclosed tag, invalid character) | Check apktool error output for the specific line number |
| Asset edit survives rebuild but not patch-tool | patch-tool unexpectedly modified the asset directory | Verify after patch-tool: `diff decoded/assets/ work/assets/` to check for changes |

---

## General Debugging Workflow

When something goes wrong and you don't know which phase the problem is in:

```bash
# Step 1: Check logcat for the smoking gun
adb logcat -d | grep -iE "exception|error|fatal|crash|killed|tamper|integrity|signature" | tail -20

# Step 2: Check if the app is even running
adb shell ps | grep <package>

# Step 3: Check if hooks are active
adb logcat -d -s HookEngine | tail -5

# Step 4: Check if payloads are on device
adb shell ls -la /sdcard/poc_frames/
adb shell ls -la /sdcard/poc_location/
adb shell ls -la /sdcard/poc_sensor/

# Step 5: Check permissions
adb shell dumpsys package <package> | grep -A 20 "granted=true"

# Step 6: Get the full crash trace
adb logcat -d | grep -A 30 "FATAL EXCEPTION" | head -40
```

### The 5-Minute Rule

If you have been debugging the same issue for more than 5 minutes without progress:

1. **Re-read the error message.** The answer is almost always in the message itself. Android error messages are specific.
2. **Check the patch-tool output.** Did the hook you expected actually fire? A `[!]` where you expected a `[+]` means your recon was wrong.
3. **Re-run the Lab 0 health check.** Environment issues masquerade as patching failures. Rule them out.
4. **Start from a clean state.** `adb uninstall`, `adb install` fresh, push payloads again, relaunch. Stale state causes 30% of debugging time.
5. **Check this appendix.** The error you're seeing is probably listed above with its fix.

# Rebuilding a modified APK after static analysis

Use this when an investigation (often via REA) concludes with a request to
ship a patched APK: permission stripping, manifest hardening, ABI shrinking,
or resource edits. It assumes the original APK has been decoded with apktool.

## Prerequisites

- apktool (3.x) + aapt2 on PATH (build-tools). Install apktool as a JAR if no
  package manager access: download the release jar and run `java -jar apktool.jar`.
- JDK 17+ (apktool 3.x). Java 25 works.
- apksigner + zipalign (build-tools) for signing.
- A keystore (generate once with keytool; reuse across rebuilds).

## Workflow

1. Decode:
   `java -jar apktool.jar d <apk> -o <dir>`

2. Edit decoded files:
   - `AndroidManifest.xml` (permissions, usesCleartextTraffic, component flags).
   - `res/xml/network_security_config.xml` (cleartextTrafficPermitted).
   - Remove ABI dirs under `lib/` to shrink size (keep the ABIs you need to
     support; arm64-v8a alone breaks x86 emulators and older devices).

3. Rebuild:
   `export PATH=<build-tools>:$PATH`
   `java -jar apktool.jar b <dir> -o <out.apk> --no-crunch`
   `--no-crunch` disables PNG crunching, which avoids failures on malformed or
   obfuscated PNG resources that aapt2 refuses to compile.

4. If the build still fails on specific resources (e.g. PNG signature errors),
   apktool caches intermediate artifacts under `<dir>/build/`. A subsequent
   build may report "AndroidManifest.xml and resources have not changed" and
   succeed by reusing the cached `resources.zip`. Delete `<dir>/build/` only
   when you want a clean rebuild; otherwise reuse the cache.

5. Sign:
   `apksigner sign --ks <keystore> --ks-key-alias <alias> \
     --ks-pass pass:<pw> --key-pass pass:<pw> --out <signed.apk> <out.apk>`

6. Verify:
   `apksigner verify -v <signed.apk>` (expect v1/v2/v3 true).

## Caveats for packed (iJiami/Bangcle/360) APKs

- Only manifest/resources/native-libs can be changed this way; the real
  application code is encrypted in assets and is not touched. Ad/tracker init
  calls inside the payload still run, though removed permissions (AD_ID,
  SYSTEM_ALERT_WINDOW, etc.) make those calls fail.
- The packer may verify the APK signature at runtime; a re-signed APK can
  fail to launch. There is no static way to know — test on a device.
- Do not claim this produces an "ad-free" APK; it is surface hardening only.
  Full modification requires unpacking the packer via a runtime DEX dump.

## Runtime unpacking reality (iJiami / Bangcle / 360)

A runtime DEX dump is the only path to the real code, but these packers
actively defeat the common automations. Set expectations before attempting:

- Anti-instrumentation: Frida-based dumpers (frida-dexdump, etc.) trigger the
  packer's anti-Frida, which SIGSEGVs the injected agent. Do not treat a
  clean Frida session as evidence the dump succeeded; verify a DEX magic
  (the bytes `dex`, newline, `03`) in the output.
- /proc/PID/mem is not readable while the process runs detached. It returns
  EIO until the process is ptrace-attached; attach first (e.g. `strace -p
  <pid>` in the background), then dump with dd. Detach (kill strace) when done.
- Even with the whole dalvik-main-space dumped, iJiami v4 keeps the DEX
  transformed in memory: no standard DEX magic appears, so naive carving fails.
  Heap dumps (am dumpheap) likewise contain no standard DEX.
- BlackDex and similar tools are interactive UI apps; they cannot be driven
  headlessly and require a human to select the target and trigger the dump.
- If no working dump method is available in the session, stop and report the
  limitation rather than shipping a "reliable workflow" built from failed
  attempts. Only the surface-level manifest/resource hardening above is
  automatable.
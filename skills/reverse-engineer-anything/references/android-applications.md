# Android application artifacts

Use the connected server's advertised Android tools. Repository main and npm
4.1.0 include this family. A skill installation alone cannot add it to an
older server.

Start with `inspect_android_package` on the caller's APK path for package
identity, manifest declarations, coverage, and inline Evidence. Use
`search_android_classes` to find candidates, `inspect_android_class` for one
class's members, `inspect_android_method` for decompilation, and
`trace_android_references` for incoming static references. Each call takes its
own APK path and explicit selectors; do not open a native session first.
Choose an `overload_index` from the class inventory when methods are ambiguous
instead of guessing.

The provider requires a separately supplied headless JADX MCP JAR 0.7.1 and
Java 17 or newer. `REA_JADX_MCP_JAR` selects the absolute JAR path; `JAVA_HOME`
can select Java. REA setup does not install or configure that JAR, and doctor
provider scopes cover Hopper/Ghidra rather than JADX. Use existing tools and
report missing prerequisites for the Android task specifically.

When the MCP server does not pick up `REA_JADX_MCP_JAR` (Android tools report
`provider_missing` / "jar not configured"), invoke the `rea` CLI directly with
the same variable exported; it spawns its own JVM and returns the same Evidence:
`REA_JADX_MCP_JAR=/abs/path/jadx-headless-mcp-0.7.1-all.jar rea inspect-android-package <apk>`.
Download/verify the JAR per the SHA-256 above rather than pointing at an
unverified copy. Keep the JAR in a persistent location (not a session
scratchpad that may be pruned) so later sessions can reuse it.

If Android tools report `capability_unavailable` / `jar not configured`, obtain
the JAR yourself (REA will not download it): fetch
`jadx-headless-mcp-0.7.1-all.jar` from the 1013503897/jadx-headless-mcp
v0.7.1 release, verify SHA-256
`6e5eacf500b64292bfb73c49797c1958f6ee44646e43e868039ae7feb573ff75`, then
export `REA_JADX_MCP_JAR` to its absolute path.

A class inventory of only a handful of classes (e.g. `s.h.e.l.l.S`,
`com.ying.shadow`, plus `ijiami.dat` / `IJMDal.Data` in assets) indicates an
iJiami-packed APK. Do not report that as "no app code"; state that the real
DEX is encrypted/packed and that static extraction requires unpacking or a
runtime DEX dump, and that any streaming endpoints, ads, or tracker SDKs live
in that payload. Runtime-dump caveats (anti-Frida, ptrace-attached
/proc/PID/mem, transformed-in-memory DEX, interactive-only BlackDex) are in
apk-rebuild.md "Runtime unpacking reality".

Manifest entries and decompiled text are static observations, not execution or
policy enforcement. Incoming references are recovered static relationships;
reflection, dynamic loading, and unresolved calls remain unknown. Preserve
artifact digests, locations, diagnostics, and incomplete coverage. For archive
members rather than code analysis, use `open_binary` and `inspect_artifact`.

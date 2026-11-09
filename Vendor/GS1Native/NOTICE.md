# Provenance

The upstream algorithm and public replay fixture are from **ctqvva/JugglucoNG**,
commit `11e6e29db7d9055c8fd2e96261812e16f2095f3d`, read on 2026-10-31.
The repository includes GNU GPL version 3 in `LICENSE.txt`; an unchanged copy
is retained in [`LICENSE.txt`](LICENSE.txt). Upstream source files and their
SHA-256 hashes are recorded in
[`Provenance/source-manifest.json`](Provenance/source-manifest.json).

The exact V1.1.5G sources first appear in commit
`23d21eb7aa195685fd5c794e9bd06fa0da9213e4` (2026-07-09, author ctqvva,
“Sibionics koltin v4”), followed by parity commit
`90a452ee5b1ca72d2b1dc030154d40034083033b` (2026-07-10).
Their own documentation describes a managed port of a recovered vendor
pipeline. This is community reverse engineering, not an official Sibionics SDK.
The public repository's license statement is evidence of its publication terms,
not an independently verified chain of rights in the manufacturer's algorithm.

The Kotlin compatibility port was modified on 2026-10-31. It preserves the
algorithm expressions. Only Java I/O imports,
System.arraycopy, Integer.compareUnsigned and unsigned Long decimal formatting
were replaced with equivalent common Kotlin implementations. The two required
observation data classes were extracted unchanged from SibionicsAlgorithm.kt.
Local compatibility, façade and build files use the same GPL-3.0 terms. The
mechanical changes are recorded in
[`Provenance/mechanical-port.diff`](Provenance/mechanical-port.diff).

The 2026-11-09 rebuild uses the same five Kotlin source files. The release build
maps source paths to the source tree and disables light debug information.
The iOS library is distributed with its complete build source in
[`Source/`](Source/) and its recipe in [`rebuild.py`](rebuild.py).

The framework embeds the Kotlin/Native 2.4.21 runtime. Its readable license
notices are under [`licenses/kotlin-native-2.4.21/`](licenses/kotlin-native-2.4.21/).
The runtime source is available at the
[JetBrains v2.4.21 tag](https://github.com/JetBrains/kotlin/tree/v2.4.21/kotlin-native/runtime)
and in the
[source archive](https://codeload.github.com/JetBrains/kotlin/tar.gz/refs/tags/v2.4.21).

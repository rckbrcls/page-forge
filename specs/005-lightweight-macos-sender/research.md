# Research: Lightweight macOS Book Sender

## Decision 1: Platform and concurrency

**Decision**: Target macOS 26.0 with the latest stable Xcode 26 SDK and use Swift
6 language mode with complete concurrency checking. Keep visual state in a
`@MainActor @Observable AppModel`; run the ordered batch in a `PipelineActor`;
publish minimal changes through `AsyncStream<PipelineEvent>`.

**Rationale**: macOS 26 provides the current Liquid Glass control APIs while the
window background uses an adaptive behind-window AppKit material. Actors isolate
mutable pipeline state, and Swift cancellation is cooperatively checked between
stages and inside streaming callbacks.

**Alternatives considered**: macOS 14 would require compatibility branches and
could not use the complete macOS 26 visual contract; macOS 27 and Xcode 27 remain
beta; a `TaskGroup` would violate sequential ordering; indiscriminate detached
tasks would weaken isolation and cancellation.

Sources: [Observation](https://developer.apple.com/documentation/observation),
[Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass),
[NSVisualEffectView](https://developer.apple.com/documentation/appkit/nsvisualeffectview),
[Swift concurrency](https://developer.apple.com/documentation/swift/concurrency),
[Task cancellation](https://developer.apple.com/documentation/swift/task/cancel%28%29).

## Decision 2: Single window and global shortcut

**Decision**: Use one `WindowGroup` with a root that switches only between
`DeliverySetupView` and `SendBookView`. Remove new-window commands and route a
configurable KeyboardShortcuts `3.0.1` callback through an AppKit window
coordinator that activates and reuses the main window.

**Rationale**: Closing the window can leave the app alive for the shortcut while
the coordinator prevents duplicate windows and batches. KeyboardShortcuts is a
source-only Swift package with a SwiftUI recorder, persistence, and conflict
handling without Accessibility permission.

**Alternatives considered**: `Window` exits when its main singleton closes;
direct Carbon registration would duplicate recorder, persistence, and conflict
behavior; `CGEventTap` adds unnecessary permissions; Raycast or a helper is
outside the product.

Sources: [SwiftUI Window](https://developer.apple.com/documentation/swiftui/window),
[NSApplication activation](https://developer.apple.com/documentation/appkit/nsapplication/activate%28%29),
[macOS 26 release notes](https://developer.apple.com/documentation/macos-release-notes/macos-26-release-notes),
[KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts).

## Decision 3: Credential and preference storage

**Decision**: Store only the SMTP app password in a generic-password Data
Protection Keychain item using `kSecUseDataProtectionKeychain = true`,
`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, and no synchronization. Store
non-secret setup and shortcut preferences in `UserDefaults`.

**Rationale**: Security.framework is the native encrypted secret boundary. The
secret can be loaded transiently on a non-main executor for validation or send
and must never enter presentation models, errors, logs, or snapshots.

**Alternatives considered**: `UserDefaults`, plist files, custom encryption, and
iCloud-synchronized Keychain items do not meet the local-secret contract.

Sources: [Keychain Services](https://developer.apple.com/documentation/security/keychain-services/),
[Adding a password](https://developer.apple.com/documentation/security/adding-a-password-to-the-keychain),
[Data Protection Keychain](https://developer.apple.com/documentation/security/ksecusedataprotectionkeychain).

## Decision 4: Sandbox, intake, and temporary lifecycle

**Decision**: Enable App Sandbox with only user-selected read-only file access
and outgoing network client access. Both multi-select `fileImporter` and
drag-and-drop converge on `BookIntakeService`. Each accepted URL is accessed
under balanced security scope, copied by streaming to
`temporaryDirectory/BookSender/<batch-id>/<item-id>/`, then released. No
security-scoped bookmark or queue survives the session.

**Rationale**: A private stable snapshot permits lengthy processing without
holding kernel security-scope resources and guarantees that the source remains
immutable. UUID paths, `.partial` files, validated promotion, marker-bounded
cleanup, and an age-limited launch sweep prevent collision and unsafe deletion.

**Alternatives considered**: paths as strings lose access; persistent bookmarks
contradict the temporary batch; read-write entitlement is unnecessary; writing
beside the source risks the original.

Sources: [Multiple file importer](https://developer.apple.com/documentation/swiftui/view/fileimporter%28ispresented%3Aallowedcontenttypes%3Aallowsmultipleselection%3Aoncompletion%3A%29),
[Security-scoped URLs](https://developer.apple.com/documentation/foundation/url/startaccessingsecurityscopedresource%28%29),
[App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox),
[Temporary directory](https://developer.apple.com/documentation/foundation/filemanager/temporarydirectory).

## Decision 5: Safe EPUB ZIP and XML processing

**Decision**: Use ZIPFoundation `0.9.x`, pinned exactly at implementation time,
behind a strict streaming adapter. Preflight the central directory before
extracting; reject unsafe paths, links, duplicates, invalid names and methods;
enforce entry, size, ratio, total, time, and memory limits; rebuild to `.partial`
with `mimetype` first and uncompressed; reopen and revalidate before promotion.
Parse bounded XML with Foundation `XMLParser`, namespaces enabled, entity
resolution disabled, DTD/entity declarations rejected, and explicit depth,
element, attribute, and text limits.

**Rationale**: EPUB is an untrusted OCF ZIP container with precise ordering and
compression rules. ZIPFoundation provides in-process entry streaming without a
runtime executable. XMLParser is sufficient when wrapped by strict input and
delegate limits.

**Alternatives considered**: `Process`, `/usr/bin/zip`, `/usr/bin/unzip`,
Calibre, and installed EPUBCheck are forbidden; Foundation Compression and Apple
Archive do not directly provide the required interoperable ZIP container;
extract-all-before-validation is unsafe.

Sources: [EPUB 3.3 OCF ZIP requirements](https://www.w3.org/TR/epub-33/#sec-zip-container-zipreqs),
[ZIPFoundation](https://github.com/weichsel/ZIPFoundation),
[XML external entities](https://developer.apple.com/documentation/foundation/xmlparser/shouldresolveexternalentities),
[XML entity policy](https://developer.apple.com/documentation/foundation/xmlparser/externalentityresolvingpolicy-swift.property).

## Decision 6: SMTP implementation

**Decision**: Implement a narrow SMTP state machine over exact compatible
versions of swift-nio and swift-nio-ssl. Support implicit TLS, STARTTLS followed
by a second EHLO, TLS 1.2+, full certificate and hostname verification,
multiline replies, AUTH PLAIN and LOGIN only within TLS, sanitized headers,
streamed MIME/base64, dot-stuffing, stage timeouts, channel cancellation, and an
internal `dataTransmissionStarted` boundary.

**Rationale**: NIOSSL can add TLS to an existing channel for STARTTLS and exposes
the channel/state boundaries needed to distinguish cancellation from
`delivery_unknown`. Network.framework does not offer a comparably direct,
documented plaintext-to-TLS upgrade on the same connection.

**Alternatives considered**: Network.framework alone does not satisfy STARTTLS;
CFStream/Secure Transport is legacy; adopting a general SMTP package would hide
the precise DATA/cancellation state; curl, Python, OpenSSL, mail tools, helpers,
and services violate the native boundary.

Sources: [Choosing a networking API](https://developer.apple.com/documentation/technotes/tn3151-choosing-the-right-networking-api),
[SwiftNIO](https://github.com/apple/swift-nio),
[SwiftNIO SSL](https://github.com/apple/swift-nio-ssl),
[SMTP](https://www.rfc-editor.org/rfc/rfc5321.html),
[STARTTLS](https://www.rfc-editor.org/rfc/rfc3207.html),
[SMTP AUTH](https://www.rfc-editor.org/rfc/rfc4954.html),
[MIME](https://www.rfc-editor.org/rfc/rfc2045.html).

## Decision 7: Testing boundaries

**Decision**: Use Swift Testing for parameterized domain, pipeline, archive,
XML, filesystem, credential, and SMTP contracts; use XCTest/XCUITest for
interface automation and performance. Use NIOEmbedded for deterministic SMTP
state-machine tests.

**Rationale**: Swift Testing supports concurrency-aware parameterized fixtures;
XCTest remains the Apple UI and performance path. The split keeps core rules
fast and deterministic while separately proving native behavior.

**Alternatives considered**: UI-only testing cannot prove untrusted-input or
protocol boundaries; replacing every test with XCTest loses useful
parameterization but adds no coverage.

Sources: [Swift Testing](https://developer.apple.com/documentation/testing),
[Parameterized testing](https://developer.apple.com/documentation/testing/parameterizedtesting),
[XCTest](https://developer.apple.com/documentation/xctest/).

## Decision 8: Migration rather than in-place cleanup

**Decision**: Build the clean `BookSender` targets alongside the current source,
port rules and fixtures, switch project/release references atomically, and then
delete Raycast/Node, Calibre/conversion, subprocess EPUB, obsolete PageForge,
legacy, and generated surfaces. Replace the legacy update channel with a
Book Sender-specific Sparkle, appcast, installer, GitHub Release, and Pages
channel.

**Rationale**: The TypeScript engine currently contains the broadest audit,
repair, malicious-fixture, and SMTP behavioral baseline, while the old Swift tree
contains reusable design, Keychain, intake, and temporary-file patterns mixed
with forbidden Calibre and subprocess behavior. Early deletion would discard the
oracle before native parity can be measured.

**Alternatives considered**: deleting first loses test evidence; renaming the
existing Swift tree in place risks retaining forbidden dependencies and extra
screens; preserving two products violates the constitution.

## Dependency acceptance conditions

At implementation time, every package version must be exact in
`Package.resolved`, source-only for this product, license-reviewed, and
compatible with the selected Swift 6/Xcode toolchain. No package may add a
processing helper, executable download, telemetry, remote processing, or another
product. Sparkle may embed only the installer services required to update the
application itself.

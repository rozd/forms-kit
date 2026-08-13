// Internal shim consumed by FormsKit's view files via a plain, unconditional
// `import FormsKitSwiftUI` — the form the skipstone bridge generator can
// mirror into the generated *_Bridge.swift files (it cannot evaluate `#if`
// conditions, so a conditional import in the view files themselves would not
// survive into the bridges). The conditional lives here instead, where the
// compiler's real flags decide it:
//
// - Skip bridge builds (the Android cross-compile and the Robolectric host
//   build, both compiled with -DSKIP_BRIDGE): re-export SkipSwiftUI, whose
//   SkipUIBridging / SkipUI machinery the generated bridges reference.
// - Every other build (Apple platforms, SKIP_ZERO): re-export real SwiftUI.
#if SKIP_BRIDGE
@_exported import SkipSwiftUI
#else
@_exported import SwiftUI
#endif

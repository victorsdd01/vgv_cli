// Picks the database backend for the current platform: SQLite through FFI on
// mobile/desktop, SQLite compiled to WebAssembly in the browser.
export 'unsupported.dart'
    if (dart.library.ffi) 'native.dart'
    if (dart.library.js_interop) 'web.dart';

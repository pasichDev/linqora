package version

// App is the current LinqoraHost release version.
// GoReleaser injects the real tag via: -ldflags "-X LinqoraHost/internal/version.App={{.Version}}"
var App = "0.5.0-pre"

// API is the WebSocket protocol version.
// Increment when message types or data shapes change in a breaking way.
const API = 1

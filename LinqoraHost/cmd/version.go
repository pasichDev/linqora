package main

import "LinqoraHost/internal/version"

// AppVersion and APIVersion are re-exported from internal/version for use by
// GoReleaser ldflags and CLI output.
// GoReleaser injects: -ldflags "-X LinqoraHost/internal/version.App={{.Version}}"
var AppVersion = version.App

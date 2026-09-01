# Media testing

Coder mounts `/media/audiobooks` and `/media/ebooks` only when `media_mount_mode=read-only`. Terraform
enforces `read_only=true`; no writable real-library option exists. `verify-media` checks flags without names.

`/workspace-test-media` is a per-container tmpfs with `nosuid,nodev,noexec`, UID 1000. It contains
`audiobooks`, `ebooks`, `downloads`, `library`, and `evidence` and disappears with the container.

`list-media-samples` normally emits opaque hashes and sizes. `--paths` is only for a private interactive
terminal. Seed commands make real byte copies mode 0600 and reject traversal, escapes, directories, and
hardlinks. `reset-test-media` refuses roots outside approved scratch locations. Never upload fixtures or names.

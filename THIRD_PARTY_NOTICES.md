# Third-party code

The root MIT license covers project-owned code. It does not grant rights to
OpenAI trademarks, official application icons or Detective Conan characters.
The official shortcut icon is acquired from the user's local installation;
it is excluded from the GitHub source and distribution archives.

`vendor/codex-dynamic-skin` contains unmodified runtime files from:

- Repository: https://github.com/CCDawn/Codex-Dynamic-Skin
- Commit: `5a0e74043b63ed9518ab37cdcf6865340a57006c`
- Runtime version: `1.7.3`
- License: MIT, preserved in `vendor/codex-dynamic-skin/LICENSE`
- File hashes: `vendor/codex-dynamic-skin/provenance.json`

Only the Windows discovery helpers, shared renderer, local media loader and their
validation dependencies are included. The upstream installer, updater, manager,
presets and promotional artwork are not included or executed.

The launcher sets `DREAMSKIN_COMPAT_PROFILE=0` before starting the engine, keeping
the optional remote selector profile disabled. Runtime files are pinned, not
downloaded or replaced automatically. The application itself still needs its
normal network connection for Codex functionality.

Generated Detective Conan wallpaper and derived camera-motion videos are bundled
under `media/`. Their prompt and generation method are documented in
`media/ASSETS.md` and `docs/ASSET_BUILD.md`. They are not official licensed promotional
assets. Personal media can also be selected locally.

FFmpeg was used only during local asset generation and is not bundled or invoked
by the runtime. The native executable is compiled from `src/Launcher.cs` using
the Windows .NET Framework compiler. Its internal window coordination module in
`src/WindowGate.cs` is compiled into the same executable.

# Building and releasing the Dux Shell assembly

The installed Dux Shell (formerly Dank Material Shell) is upstream
`duxlabs-dev/dux-shell` `master` plus the topics in `manifest.toml`, published
to `colonelpanic8/dux-shell` branch `assembled`. Read `AGENTS.md` for the model
and invariants.

## Locations

| Item | Location |
| --- | --- |
| Topic development checkout | `~/projects/dank-material-shell` (`origin` = upstream, `fork` = colonelpanic8/dux-shell) |
| Published artifact | `colonelpanic8/dux-shell` branch `assembled`, tags `dux-shell-assembled-*` |
| Flake input | `dank-material-shell` in `/srv/dotfiles/nixos/flake.nix` |
| NixOS module | `/srv/dotfiles/nixos/dank-material-shell.nix` |

The fork's old `dotfiles` branch is retired; do not commit to it.

## Changing a topic

Work on the topic branch in a worktree of the development checkout, cut from
upstream `master`, one concern per branch. Push it to `fork`, then
`fork-assembler update mine:<topic>`. New topics go in with
`fork-assembler add mine:<topic>`.

## Release

Release eagerly; validate afterwards and fix forward.

1. `fork-assembler update` (all pins) or `fork-assembler update ENTRY...`.
2. `fork-assembler build`, resolving any stopped conflict and running
   `fork-assembler continue`.
3. `fork-assembler build --locked` must report the lock's tree reproduced.
4. Commit `manifest.toml`, `manifest.lock.json`, `resolutions/`, and
   `patches/` with explicit paths, and push.
5. `just publish` pushes the build worktree to `assembled` and tags it.
6. In `/srv/dotfiles/nixos`: `nix flake update dank-material-shell`, then
   `just switch`.
7. Validate: `nix build .#checks.x86_64-linux.dms-workspaces --no-link` from
   `/srv/dotfiles/nixos`, and `systemctl --user restart dms.service` if the
   shell is running.
8. Commit `nixos/flake.lock` in the dotfiles repository with an explicit path.

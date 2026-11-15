# Herdr app

Configuration for [Herdr app](https://herdr.dev) — the desktop app, not the
`herdr` terminal TUI. They are separate products with separate homes:

| | Path |
| --- | --- |
| Herdr app home | `~/.config/herdr-app` |
| `herdr` CLI (TUI) home | `~/.herdr` |

## What's here

```
herdr-app/
├── layouts/
│   └── mine.json          # clone of the built-in `main` layout
└── mods/
    └── session-status/    # status block under the Files panel
        ├── main.js
        └── mod.json
```

## The `session-status` mod

A card pinned under the Files panel on the right, showing what the current
Pi session has loaded:

```
Session                    ●
  mcp 1
   ─ github
  ext 1
   ─ herdr-agent-state
```

### Colour rules

| State | Colour | When |
| --- | --- | --- |
| Registered and usable | green (`ansi2`) | MCP command exists or resolves on `PATH` |
| Registered but unusable | red (`blocked`) | `enabled: false`, no `command`, or the command is missing |
| Nothing | — | the group is not drawn at all |

Empty groups (`skills`, `git` outside a repository) are omitted rather than
showing a placeholder.

### Where the data comes from

| Row | Source |
| --- | --- |
| `mcp` | `~/.pi/agent/mcp.json` → `mcpServers`, filtered by availability |
| `skills` | directories under `~/.pi/agent/skills/` |
| `ext` | `*.ts` / `*.js` files under `~/.pi/agent/extensions/` |
| `git` | `git rev-parse --abbrev-ref HEAD` in the active space's folder |

### Availability check

All `command` values are tested in **one** PowerShell call:

```powershell
$r=@()
$r+=@(if(Test-Path -LiteralPath '<cmd>'){'ok'}elseif(Get-Command '<cmd>' -EA SilentlyContinue){'ok'}else{'dead'})
...
$r|ConvertTo-Json -Compress
```

Probing each server separately spawns one process per server and does not
finish within the timeout once there are more than a few — the whole refresh
then silently fails and the panel goes blank. Keep it batched.

### Height

Layout nodes only accept `{px}` or `{weight}`, so a node cannot size itself to
its content. The mod measures instead and pushes the result:

```js
const want = 34 + groups * 24 + rows * 19 + 8;
if (this.lastH !== want) run("layout.resize", { id: "session-panel", px: want });
```

Header 34 px, each group heading 24 px, each row 19 px, padding 8 px, clamped
to 70–420 px. The resolved value is stored by the app in
`layouts/.state/mine.json`.

### Redraws

`cx.notify()` redraws the whole window, so the mod only calls it when the
collected data actually changed.

## Install

Herdr's own layouts and mods are read-only and are replaced on every start.
Clone the layout and bring your own mod, or the next launch undoes it:

```sh
herdr-app do layout.clone '{"name":"main","as":"mine"}'
```

Then copy the files from this directory:

```sh
cp -r herdr-app/mods/session-status  ~/.config/herdr-app/mods/
cp    herdr-app/layouts/mine.json    ~/.config/herdr-app/layouts/
```

Point the layout's `status` node back at the shipped mod if you cloned it from
a version that still had this patch, and make sure `panel` contains the extra
`session-panel` block:

```json
{
  "id": "session-panel",
  "type": "block",
  "content": { "mod": "session-status" },
  "size": { "px": 148 },
  "min": 70,
  "max": 420
}
```

Switch to it:

```sh
herdr-app do layout.switch '{"name":"mine"}'
```

A mod is reloaded in place when its files are saved; run
`herdr-app check ~/.config/herdr-app/mods/session-status` after editing to see
what is wrong before it reaches the window.

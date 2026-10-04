# Services Manager — Omarchy Bar Widget

A lightweight, modern, and native [Omarchy](https://omarchy.org/) status bar widget and control panel to manage and toggle background system services (Docker, PostgreSQL, UFW Firewall, etc.) and arbitrary background commands (Node dev servers, Python servers, background scripts) directly from your desktop bar.

Designed for developers who want to toggle system services and local dev servers effortlessly on demand with clean background process lifecycle management.

---

## Requirements & Prerequisites

Before installing the widget, ensure your system has:

1. **Omarchy Linux** with Quickshell status bar (`omarchy plugin` / `omarchy bar` CLI available).
2. **systemd** with standard user permissions / Polkit (`omarchy.polkit` agent is standard on Omarchy).
3. **Nerd Font** (standard on Omarchy, used for service glyphs).

---

<p align="center">
  <img width="1144" height="500" alt="Services Manager Panel 1" src="https://imglink.cc/cdn/2HaNbYulrn.png" />
</p>

---

## Installation

### Option 1: Using `omarchy plugin` (Recommended)

```bash
omarchy plugin add https://github.com/Rizmi/omarchy-services-plugin.git --enable
```

### Option 2: Manual Installation

1. Clone the repository into your Omarchy plugins directory:
   ```bash
   git clone https://github.com/Rizmi/omarchy-services-plugin.git \
     ~/.config/omarchy/plugins/io.github.rizmi.services
   ```

2. Validate and enable the plugin on your status bar:
   ```bash
   omarchy plugin validate ~/.config/omarchy/plugins/io.github.rizmi.services
   omarchy plugin enable io.github.rizmi.services --section right
   ```

3. Reload the shell if necessary:
   ```bash
   omarchy restart shell
   ```

---

## Removal

```bash
omarchy plugin disable io.github.rizmi.services
rm -rf ~/.config/omarchy/plugins/io.github.rizmi.services
omarchy restart shell
```

---

## Configuration & Customizing Services

The plugin reads its list of services directly from **`services.json`**.

Users can add, remove, or modify services at any time by editing `services.json` (either in the plugin folder or as a user override at `~/.config/omarchy/services.json`). The plugin automatically detects changes and hot-reloads instantly upon saving!

**Override precedence:** if `~/.config/omarchy/services.json` exists and is non-empty, it is used and the plugin folder's `services.json` is ignored entirely. The override is the recommended place for your personal service list — it survives `omarchy plugin update`, while edits to the plugin folder are overwritten on update.

---

### Running Custom Commands & Dev Servers (Node, Python, etc.)

You can turn ON and OFF **any command or server** directly from your status bar. When turned on, the command runs in the background. When turned off, it is cleanly killed (including all child processes).

Simply add an entry with `"command"` to your `services.json`:

```json
[
  {
    "id": "node-dev",
    "name": "Node Frontend",
    "command": "npm run dev",
    "cwd": "~/Projects/my-web-app",
    "icon": "󰎙",
    "description": "Vite dev server on :5173"
  },
  {
    "id": "python-api",
    "name": "FastAPI Server",
    "command": "python3 -m uvicorn main:app --reload --port 8000",
    "cwd": "~/Projects/backend-api",
    "icon": "󰌠",
    "description": "FastAPI on port 8000"
  },
  {
    "id": "http-docs",
    "name": "Docs Server",
    "command": "python3 -m http.server 8080",
    "cwd": "~/Documents/docs",
    "icon": "󰌠"
  },
  {
    "id": "compose-stack",
    "name": "App Stack",
    "command": "docker compose up",
    "stop": "docker compose down",
    "cwd": "~/Projects/fullstack-app",
    "icon": "󰣆"
  }
]
```

> [!TIP]
> **Process Tree Cleanup:** Background commands run in an isolated systemd user cgroup. When turned off, all child processes (e.g. `node`, `vite`, `python` worker processes) are killed cleanly, preventing orphaned background processes from holding onto ports.

---

### Adding Systemd Services

You can manage system-level or user-level systemd services alongside custom commands:

```json
[
  {
    "id": "docker",
    "name": "Docker",
    "unit": "docker.service",
    "stopUnits": ["docker.service", "docker.socket", "containerd.service"],
    "icon": "󰣆",
    "description": "Container runtime engine"
  },
  {
    "id": "postgresql",
    "name": "PostgreSQL",
    "unit": "postgresql.service",
    "icon": "󰆼",
    "description": "Relational database server"
  },
  {
    "id": "sunshine",
    "name": "Sunshine",
    "unit": "app-dev.lizardbyte.app.Sunshine.service",
    "scope": "user",
    "icon": "󰌋",
    "description": "Self-hosted game stream host"
  },
  {
    "id": "ufw",
    "name": "UFW Firewall",
    "unit": "ufw.service",
    "icon": "󰒃",
    "description": "Netfilter firewall manager"
  }
]
```

---

### Service Schema Properties:

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `string` | Yes | Unique identifier (e.g. `"node-app"`, `"docker"`) |
| `name` | `string` | No | Display title shown in the card header (defaults to `id`) |
| `command` | `string` | For commands | Shell command to run in the background (e.g. `"npm run dev"`, `"python3 -m http.server 8000"`). Also accepts `start` / `startCommand`. |
| `cwd` | `string` | No | Working directory to execute the command in (supports `~`, e.g. `"~/Projects/my-app"`). Also accepts `workingDirectory` / `dir`. |
| `stop` | `string` | No | Optional custom stop command (e.g. `"docker compose down"`). If omitted, the process and its entire process tree are cleanly terminated automatically. Also accepts `stopCommand`. |
| `env` | `object` / `array` | No | Environment variables to pass to the process (e.g. `{"PORT": "3000", "NODE_ENV": "development"}`) |
| `unit` | `string` | For systemd | systemd unit name (e.g. `"docker.service"`). For commands, automatically generated if omitted. |
| `scope` | `string` | No | `"system"` (default for systemd) or `"user"` (default for custom commands) |
| `startUnits` | `array` | No | List of units to start together (for systemd services) |
| `stopUnits` | `array` | No | List of extra units/sockets to stop together (e.g. `["docker.service", "docker.socket"]`) |
| `icon` | `string` | No | Nerd Font icon glyph (e.g. `"󰎙"`, `"󰌠"`). Auto-detected for Python, Node/JS, Rust, Go, Docker, etc., if omitted. |
| `description` | `string` | No | Subtitle / description (defaults to the command or unit name) |

---

## Features & Controls

- **Top Bar Indicator**:
  - Highlights with active accent color when any service is running; dims when all services are stopped.
  - Dynamic tooltip showing real-time states of all managed services.
- **Interactive Control Panel**:
  - Individual toggle switches with instant optimistic UI feedback.
  - Multi-unit shutdown support (stops `docker.service` and `docker.socket` together).
  - Batch "Start All" and "Stop All" actions.
  - Animated refresh button with spin feedback.
- **Keyboard Navigation** (when panel is open):
  - `1`, `2`, `3`, etc. → Toggle service by its numbered shortcut
  - `S` → Start All / Stop All
  - `R` → Force refresh statuses
  - `Esc` → Close panel

---

## License

MIT License © 2026 Omarchy Community

# Services Manager — Omarchy Bar Widget

A lightweight, modern, and native [Omarchy](https://omarchy.org/) status bar widget and control panel to manage and toggle background system services (Docker, PostgreSQL, UFW Firewall, Redis, Ollama, etc.) directly from your desktop bar.

Designed for developers who prefer to keep heavy system services disabled at boot and toggle them effortlessly on demand.

---

## Requirements & Prerequisites

Before installing the widget, ensure your system has:

1. **Omarchy Linux** with Quickshell status bar (`omarchy plugin` / `omarchy bar` CLI available).
2. **systemd** with standard user permissions / Polkit (`omarchy.polkit` agent is standard on Omarchy).
3. **Nerd Font** (standard on Omarchy, used for service glyphs).

---

<p align="center">
  <img width="332" height="464" alt="Services Manager Panel 1" src="https://imglink.cc/cdn/gktHBU-kGh.png" />
  &nbsp;&nbsp;
  <img width="332" height="464" alt="Services Manager Panel 2" src="https://imglink.cc/cdn/iKrO6pJ9yR.png />
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

### Default `services.json`:

```json
[
  {
    "id": "docker",
    "name": "Docker",
    "unit": "docker.service",
    "stopUnits": ["docker.service", "docker.socket"],
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
    "id": "ufw",
    "name": "UFW Firewall",
    "unit": "ufw.service",
    "icon": "󰒃",
    "description": "Netfilter firewall manager"
  }
]
```

### Adding Popular Services

You can add any systemd service to `services.json`, including user-scope services:

```json
[
  {
    "id": "sunshine",
    "name": "Sunshine",
    "unit": "app-dev.lizardbyte.app.Sunshine.service",
    "scope": "user",
    "icon": "󰌋",
    "description": "Self-hosted game stream host"
  },
  {
    "id": "redis",
    "name": "Redis",
    "unit": "redis.service",
    "icon": "󰌠",
    "description": "In-memory cache store"
  },
  {
    "id": "ollama",
    "name": "Ollama AI",
    "unit": "ollama.service",
    "icon": "󰚩",
    "description": "Local LLM runner"
  },
  {
    "id": "mongodb",
    "name": "MongoDB",
    "unit": "mongodb.service",
    "icon": "󰆼",
    "description": "NoSQL document database"
  },
  {
    "id": "mariadb",
    "name": "MariaDB",
    "unit": "mariadb.service",
    "icon": "󰆼",
    "description": "SQL relational database"
  },
  {
    "id": "nginx",
    "name": "Nginx",
    "unit": "nginx.service",
    "icon": "󰒋",
    "description": "Web server & reverse proxy"
  }
]
```

### Service Schema Properties:

| Field | Type | Required | Description |
|---|---|---|---|
| `id` | `string` | Yes | Unique identifier (e.g. `"redis"`) |
| `name` | `string` | Yes | Display title shown in the card header |
| `unit` | `string` | Yes | systemd unit name (e.g. `"redis.service"`) |
| `scope` | `string` | No | `"system"` (default) or `"user"` for user-level services. User-scope units are checked and toggled via `systemctl --user` (e.g. `app-dev.lizardbyte.app.Sunshine.service`) |
| `icon` | `string` | No | Nerd Font icon glyph (e.g. `"󰌠"`) |
| `description` | `string` | No | Subtitle / description |
| `stopUnits` | `array` | No | List of extra units/sockets to stop together |

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

import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var settings: ({})

  property var servicesDef: []

  readonly property string localServicesFile: {
    var raw = Qt.resolvedUrl("services.json").toString()
    return raw.replace(/^file:\/\//, "")
  }

  readonly property string userServicesFile: {
    var custom = settings ? settings["customConfigFile"] : undefined
    return custom ? String(custom) : (Quickshell.env("HOME") + "/.config/omarchy/services.json")
  }

  // Watch the plugin's own services.json
  property FileView localConfigFileView: FileView {
    path: root.localServicesFile
    watchChanges: true
    printErrors: false
    onFileChanged: root.reloadConfig()
    onLoaded: root.reloadConfig()
    onLoadFailed: root.reloadConfig()
  }

  // Watch user override ~/.config/omarchy/services.json if present
  property FileView userConfigFileView: FileView {
    path: root.userServicesFile
    watchChanges: true
    printErrors: false
    onFileChanged: root.reloadConfig()
    onLoaded: root.reloadConfig()
    onLoadFailed: root.reloadConfig()
  }

  function reloadConfig() {
    var userText = String(userConfigFileView.text() || "").trim()
    if (userText) {
      root.loadServicesConfig(userText)
      return
    }
    var localText = String(localConfigFileView.text() || "").trim()
    if (localText) {
      root.loadServicesConfig(localText)
      return
    }
    root.loadServicesConfig("")
  }

  property var services: []
  property var statusMap: ({})
  property var activeMap: ({})
  property var busyMap: ({})
  property int runningCount: 0
  property bool refreshing: checkProcess.running
  property string lastError: ""
  property string actionMessage: ""

  readonly property string summaryText: {
    if (servicesDef.length === 0) return "No services configured"
    if (runningCount === 0) return "All services stopped"
    if (runningCount === 1) {
      for (var i = 0; i < servicesDef.length; i++) {
        var s = servicesDef[i]
        if (activeMap[s.id]) return s.name + " running"
      }
    }
    return runningCount + " of " + servicesDef.length + " running"
  }

  function sanitizeUnitId(rawId) {
    return String(rawId || "").replace(/[^a-zA-Z0-9_.-]/g, "_")
  }

  function expandPath(pathStr) {
    if (!pathStr) return ""
    var p = String(pathStr).trim()
    var home = Quickshell.env("HOME") || ""
    if (p === "~") return home
    if (p.indexOf("~/") === 0) return home + p.substring(1)
    return p
  }

  function getDefaultCommandIcon(cmd, id) {
    var s = (String(cmd || "") + " " + String(id || "")).toLowerCase()
    if (s.indexOf("python") !== -1 || s.indexOf("py ") !== -1 || s.indexOf(".py") !== -1 || s.indexOf("uvicorn") !== -1 || s.indexOf("gunicorn") !== -1 || s.indexOf("flask") !== -1 || s.indexOf("django") !== -1 || s.indexOf("fastapi") !== -1) {
      return "󰌠"
    }
    if (s.indexOf("node") !== -1 || s.indexOf("npm") !== -1 || s.indexOf("yarn") !== -1 || s.indexOf("pnpm") !== -1 || s.indexOf("bun") !== -1 || s.indexOf("vite") !== -1 || s.indexOf("next") !== -1 || s.indexOf("express") !== -1) {
      return "󰎙"
    }
    if (s.indexOf("cargo") !== -1 || s.indexOf("rust") !== -1) {
      return "󱘗"
    }
    if (s.indexOf("go ") !== -1 || s.indexOf("golang") !== -1) {
      return "󰟓"
    }
    if (s.indexOf("ruby") !== -1 || s.indexOf("rails") !== -1) {
      return "󰴭"
    }
    if (s.indexOf("docker") !== -1 || s.indexOf("compose") !== -1) {
      return "󰣆"
    }
    if (s.indexOf("php") !== -1 || s.indexOf("artisan") !== -1) {
      return "󰌟"
    }
    return "󰒋"
  }

  function loadServicesConfig(rawText) {
    var text = String(rawText || "").trim()
    var cleanList = []
    if (text) {
      var parsed = null
      try {
        parsed = JSON.parse(text)
      } catch (e1) {
        try {
          var cleaned = text
            .replace(/\/\*[\s\S]*?\*\//g, "")
            .replace(/\/\/.*$/gm, "")
            .replace(/,(\s*[}\]])/g, "$1")
          parsed = JSON.parse(cleaned)
        } catch (e2) {
          console.warn("io.github.rizmi.services: failed to parse services.json:", e2)
        }
      }

      var list = Array.isArray(parsed) ? parsed : (parsed && Array.isArray(parsed.services) ? parsed.services : null)
      if (list && list.length > 0) {
        for (var i = 0; i < list.length; i++) {
          var item = list[i]
          if (!item || !item.id) continue

          var rawCmd = item.command || item.start || item.startCommand
          var isCmd = Boolean(item.type === "command" || rawCmd)
          var rawUnit = item.unit ? String(item.unit) : ""

          if (!rawUnit && !isCmd) continue

          var idStr = String(item.id)
          var unitStr = rawUnit || ("omarchy-cmd-" + sanitizeUnitId(idStr) + ".service")
          var cmdStr = rawCmd ? String(rawCmd) : ""
          var stopCmdStr = item.stop || item.stopCommand ? String(item.stop || item.stopCommand) : ""
          var cwdStr = expandPath(item.cwd || item.workingDirectory || item.dir || "")
          var scopeStr = isCmd ? "user" : (item.scope === "user" ? "user" : "system")

          var startUnits = Array.isArray(item.startUnits) ? item.startUnits : (item.startUnits ? [String(item.startUnits)] : [])
          var stopUnits = Array.isArray(item.stopUnits) ? item.stopUnits : (item.stopUnits ? [String(item.stopUnits)] : [])

          var iconStr = item.icon ? String(item.icon) : (isCmd ? getDefaultCommandIcon(cmdStr, idStr) : "󰒋")
          var descStr = item.description ? String(item.description) : (isCmd ? (cmdStr || unitStr) : unitStr)

          cleanList.push({
            id: idStr,
            name: String(item.name || item.id),
            unit: unitStr,
            isCommand: isCmd,
            command: cmdStr,
            stopCommand: stopCmdStr,
            cwd: cwdStr,
            env: item.env || null,
            scope: scopeStr,
            startUnits: startUnits,
            stopUnits: stopUnits,
            icon: iconStr,
            description: descStr
          })
        }
      }
    }
    root.servicesDef = cleanList
    root.updateServicesList()
    root.refresh()
  }

  function updateServicesList() {
    var list = []
    var count = 0
    for (var i = 0; i < servicesDef.length; i++) {
      var def = servicesDef[i]
      var isAct = !!activeMap[def.id]
      var isBsy = !!busyMap[def.id]
      var rawSt = statusMap[def.id] || "inactive"
      if (isAct) count++

      var displayStatus = "Stopped"
      if (isBsy) {
        displayStatus = isAct ? "Stopping..." : "Starting..."
      } else if (rawSt === "active") {
        displayStatus = "Running"
      } else if (rawSt === "activating") {
        displayStatus = "Starting..."
      } else if (rawSt === "deactivating") {
        displayStatus = "Stopping..."
      } else if (rawSt === "failed") {
        displayStatus = "Failed"
      } else {
        displayStatus = "Stopped"
      }

      list.push({
        id: def.id,
        name: def.name,
        unit: def.unit,
        isCommand: !!def.isCommand,
        command: def.command || "",
        cwd: def.cwd || "",
        icon: def.icon,
        description: def.description,
        active: isAct,
        busy: isBsy,
        status: rawSt,
        statusLabel: displayStatus
      })
    }
    root.runningCount = count
    root.services = list
  }

  property var checkQueue: []

  function refresh() {
    if (checkProcess.running || servicesDef.length === 0) return
    var sysUnits = []
    var sysIds = []
    var usrUnits = []
    var usrIds = []
    for (var i = 0; i < servicesDef.length; i++) {
      var def = servicesDef[i]
      if (def.scope === "user") {
        usrUnits.push(def.unit)
        usrIds.push(def.id)
      } else {
        sysUnits.push(def.unit)
        sysIds.push(def.id)
      }
    }
    root.checkQueue = []
    if (sysUnits.length > 0) root.checkQueue.push({ scope: "system", units: sysUnits, ids: sysIds })
    if (usrUnits.length > 0) root.checkQueue.push({ scope: "user", units: usrUnits, ids: usrIds })
    runNextCheck()
  }

  function runNextCheck() {
    if (checkQueue.length === 0) return
    var job = checkQueue.shift()
    currentCheckJob = job
    var cmd = ["systemctl"]
    if (job.scope === "user") cmd.push("--user")
    cmd.push("is-active")
    for (var i = 0; i < job.units.length; i++) {
      cmd.push(job.units[i])
    }
    checkProcess.command = cmd
    checkProcess.running = true
  }

  function toggleService(serviceId) {
    if (busyMap[serviceId]) return
    var def = null
    for (var i = 0; i < servicesDef.length; i++) {
      if (servicesDef[i].id === serviceId) {
        def = servicesDef[i]
        break
      }
    }
    if (!def) return

    var currentActive = !!activeMap[serviceId]
    var targetActive = !currentActive

    var newBusy = Object.assign({}, busyMap)
    newBusy[serviceId] = true
    busyMap = newBusy
    updateServicesList()

    actionMessage = (targetActive ? "Starting " : "Stopping ") + def.name + "..."
    actionTimer.restart()

    queueServiceCommand(def, targetActive ? "start" : "stop", serviceId)
  }

  function startAll() {
    for (var i = 0; i < servicesDef.length; i++) {
      var s = servicesDef[i]
      if (!activeMap[s.id]) {
        toggleService(s.id)
      }
    }
  }

  function stopAll() {
    for (var i = 0; i < servicesDef.length; i++) {
      var s = servicesDef[i]
      if (activeMap[s.id]) {
        toggleService(s.id)
      }
    }
  }

  function queueServiceCommand(def, action, serviceId) {
    var units = [def.unit]
    if (!def.isCommand) {
      if (action === "start" && def.startUnits && def.startUnits.length > 0) {
        units = def.startUnits
      } else if (action === "stop" && def.stopUnits && def.stopUnits.length > 0) {
        units = def.stopUnits
      }
    }
    var proc = controlProcessComponent.createObject(root, {
      serviceDef: def,
      units: units,
      action: action,
      serviceId: serviceId,
      scope: def.scope === "user" ? "user" : "system",
      isCommand: !!def.isCommand
    })
    proc.start()
  }

  Component {
    id: controlProcessComponent
    Item {
      id: procItem
      property var serviceDef: null
      property var units: []
      property string action: ""
      property string serviceId: ""
      property string scope: "system"
      property bool isCommand: false

      function start() {
        if (procItem.isCommand && procItem.serviceDef) {
          var def = procItem.serviceDef
          if (procItem.action === "start") {
            var bashScript =
              'unit="$1"\n' +
              'cmd="$2"\n' +
              'shift 2\n' +
              'systemctl --user stop "$unit" 2>/dev/null || true\n' +
              'systemctl --user reset-failed "$unit" 2>/dev/null || true\n' +
              'exec systemd-run --user --unit="$unit" --property=TimeoutStopSec=5s "$@" bash -lc "$cmd"\n'

            var cmdArgs = ["bash", "-c", bashScript, "--", def.unit, def.command]

            if (def.cwd) {
              cmdArgs.push("--working-directory=" + def.cwd)
            }

            if (def.env) {
              if (Array.isArray(def.env)) {
                for (var e = 0; e < def.env.length; e++) {
                  cmdArgs.push("-E" + String(def.env[e]))
                }
              } else if (typeof def.env === "object") {
                var envKeys = Object.keys(def.env)
                for (var k = 0; k < envKeys.length; k++) {
                  var key = envKeys[k]
                  cmdArgs.push("-E" + key + "=" + String(def.env[key]))
                }
              }
            }

            process.command = cmdArgs
            process.running = true
            return
          } else {
            // Stop command service
            if (def.stopCommand) {
              var stopScript =
                'unit="$1"\n' +
                'stopCmd="$2"\n' +
                'cwd="$3"\n' +
                'if [ -n "$cwd" ] && [ -d "$cwd" ]; then cd "$cwd" || true; fi\n' +
                'if [ -n "$stopCmd" ]; then\n' +
                '  bash -lc "$stopCmd" || true\n' +
                'fi\n' +
                'systemctl --user stop "$unit" 2>/dev/null || true\n' +
                'systemctl --user reset-failed "$unit" 2>/dev/null || true\n'

              process.command = ["bash", "-c", stopScript, "--", def.unit, def.stopCommand, def.cwd || ""]
              process.running = true
              return
            } else {
              var plainStopScript =
                'unit="$1"\n' +
                'systemctl --user stop "$unit" 2>/dev/null || true\n' +
                'systemctl --user reset-failed "$unit" 2>/dev/null || true\n'

              process.command = ["bash", "-c", plainStopScript, "--", def.unit]
              process.running = true
              return
            }
          }
        }

        // Standard systemd service
        var cmd = ["systemctl"]
        if (procItem.scope === "user") cmd.push("--user")
        cmd.push(action)
        for (var i = 0; i < units.length; i++) {
          cmd.push(units[i])
        }
        process.command = cmd
        process.running = true
      }

      Process {
        id: process
        running: false
        stderr: StdioCollector { id: procStderr; waitForEnd: true }
        onExited: function(exitCode) {
          var newBusy = Object.assign({}, root.busyMap)
          newBusy[procItem.serviceId] = false
          root.busyMap = newBusy

          var serviceName = procItem.serviceDef ? procItem.serviceDef.name : procItem.serviceId

          if (exitCode !== 0) {
            var err = String(procStderr.text || ("Failed to " + procItem.action + " " + serviceName)).trim()
            root.lastError = err.length > 80 ? err.substring(0, 77) + "..." : err
            root.actionMessage = root.lastError
            actionTimer.restart()
          } else {
            root.lastError = ""
            root.actionMessage = (procItem.action === "start" ? "Started " : "Stopped ") + serviceName
            actionTimer.restart()
          }

          root.refresh()
          if (procItem.isCommand) {
            postCheckTimer.restart()
          }
          procItem.destroy()
        }
      }
    }
  }

  property var currentCheckJob: null

  Process {
    id: checkProcess
    running: false
    stdout: StdioCollector { id: checkStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var lines = String(checkStdout.text || "").trim().split("\n")
      var newStatus = Object.assign({}, root.statusMap)
      var newActive = Object.assign({}, root.activeMap)
      var job = currentCheckJob

      for (var i = 0; i < job.ids.length; i++) {
        var rawLine = (i < lines.length ? lines[i].trim() : "inactive")
        newStatus[job.ids[i]] = rawLine
        newActive[job.ids[i]] = (rawLine === "active")
      }

      statusMap = newStatus
      activeMap = newActive
      updateServicesList()
      runNextCheck()
    }
  }

  Timer {
    id: postCheckTimer
    interval: 600
    repeat: false
    onTriggered: root.refresh()
  }

  Timer {
    id: actionTimer
    interval: 3000
    repeat: false
    onTriggered: {
      root.actionMessage = ""
      root.lastError = ""
    }
  }

  Timer {
    id: backgroundRefreshTimer
    interval: {
      var sec = settings ? parseInt(settings["refreshIntervalSec"], 10) : 8
      if (!isFinite(sec) || sec < 2) sec = 8
      return sec * 1000
    }
    repeat: true
    running: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    reloadConfig()
  }
}

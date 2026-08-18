import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: root

  property var settings: ({})

  readonly property var defaultServicesDef: [
    {
      id: "docker",
      name: "Docker",
      unit: "docker.service",
      stopUnits: ["docker.service", "docker.socket"],
      icon: "󰣆",
      description: "Container runtime engine"
    },
    {
      id: "postgresql",
      name: "PostgreSQL",
      unit: "postgresql.service",
      icon: "󰆼",
      description: "Relational database server"
    },
    {
      id: "ufw",
      name: "UFW Firewall",
      unit: "ufw.service",
      icon: "󰒃",
      description: "Netfilter firewall manager"
    }
  ]

  property var servicesDef: defaultServicesDef

  readonly property string customConfigFile: {
    var custom = settings ? settings["customConfigFile"] : undefined
    return custom ? String(custom) : (Quickshell.env("HOME") + "/.config/omarchy/services.json")
  }

  property FileView configFileView: FileView {
    path: root.customConfigFile
    watchChanges: true
    printErrors: false
    onFileChanged: root.loadServicesConfig(text())
    onLoaded: root.loadServicesConfig(text())
    onLoadFailed: root.loadServicesConfig("")
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
    if (runningCount === 0) return "All services stopped"
    if (runningCount === 1) {
      for (var i = 0; i < servicesDef.length; i++) {
        var s = servicesDef[i]
        if (activeMap[s.id]) return s.name + " running"
      }
    }
    return runningCount + " of " + servicesDef.length + " running"
  }

  readonly property string tooltipText: {
    var parts = []
    for (var i = 0; i < servicesDef.length; i++) {
      var s = servicesDef[i]
      var st = statusMap[s.id] || "inactive"
      var cap = st.charAt(0).toUpperCase() + st.slice(1)
      parts.push(s.name + ": " + cap)
    }
    return "Services — " + (parts.length > 0 ? parts.join(" · ") : "No services configured")
  }

  function loadServicesConfig(rawText) {
    var text = String(rawText || "").trim()
    if (!text) {
      root.servicesDef = root.defaultServicesDef
      root.updateServicesList()
      root.refresh()
      return
    }
    try {
      var parsed = JSON.parse(text)
      var list = Array.isArray(parsed) ? parsed : (parsed && Array.isArray(parsed.services) ? parsed.services : null)
      if (list && list.length > 0) {
        var cleanList = []
        for (var i = 0; i < list.length; i++) {
          var item = list[i]
          if (item && item.id && item.unit) {
            cleanList.push({
              id: String(item.id),
              name: String(item.name || item.id),
              unit: String(item.unit),
              stopUnits: Array.isArray(item.stopUnits) ? item.stopUnits : (item.stopUnits ? [String(item.stopUnits)] : []),
              icon: String(item.icon || "󰒋"),
              description: String(item.description || item.unit)
            })
          }
        }
        if (cleanList.length > 0) {
          root.servicesDef = cleanList
          root.updateServicesList()
          root.refresh()
          return
        }
      }
    } catch (e) {
      console.warn("io.github.rizmi.services: failed to parse services.json:", e)
    }
    root.servicesDef = root.defaultServicesDef
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

  function refresh() {
    if (checkProcess.running || servicesDef.length === 0) return
    var cmd = ["systemctl", "is-active"]
    for (var i = 0; i < servicesDef.length; i++) {
      cmd.push(servicesDef[i].unit)
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
    if (action === "stop" && def.stopUnits && def.stopUnits.length > 0) {
      units = def.stopUnits
    }
    var proc = controlProcessComponent.createObject(root, {
      units: units,
      action: action,
      serviceId: serviceId
    })
    proc.start()
  }

  Component {
    id: controlProcessComponent
    Item {
      id: procItem
      property var units: []
      property string action: ""
      property string serviceId: ""

      function start() {
        var cmd = ["systemctl", action]
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

          if (exitCode !== 0) {
            var err = String(procStderr.text || ("Failed to " + procItem.action + " " + procItem.serviceId)).trim()
            root.lastError = err.length > 80 ? err.substring(0, 77) + "..." : err
            root.actionMessage = root.lastError
            actionTimer.restart()
          } else {
            root.lastError = ""
            root.actionMessage = (procItem.action === "start" ? "Started " : "Stopped ") + procItem.serviceId
            actionTimer.restart()
          }

          root.refresh()
          procItem.destroy()
        }
      }
    }
  }

  Process {
    id: checkProcess
    running: false
    stdout: StdioCollector { id: checkStdout; waitForEnd: true }
    onExited: function(exitCode) {
      var lines = String(checkStdout.text || "").trim().split("\n")
      var newStatus = {}
      var newActive = {}

      for (var i = 0; i < servicesDef.length; i++) {
        var s = servicesDef[i]
        var rawLine = (i < lines.length ? lines[i].trim() : "inactive")
        newStatus[s.id] = rawLine
        newActive[s.id] = (rawLine === "active")
      }

      statusMap = newStatus
      activeMap = newActive
      updateServicesList()
    }
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
    id: pollTimer
    interval: 8000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    updateServicesList()
    refresh()
  }
}

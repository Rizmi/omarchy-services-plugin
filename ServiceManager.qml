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

  readonly property string tooltipText: {
    if (servicesDef.length === 0) return "No services configured"
    var r = runningCount
    var s = servicesDef.length - r
    if (r === 0) return s + " stopped"
    if (s === 0) return r + " running"
    return r + " running · " + s + " stopped"
  }

  function loadServicesConfig(rawText) {
    var text = String(rawText || "").trim()
    var cleanList = []
    if (text) {
      try {
        var parsed = JSON.parse(text)
        var list = Array.isArray(parsed) ? parsed : (parsed && Array.isArray(parsed.services) ? parsed.services : null)
        if (list && list.length > 0) {
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
        }
      } catch (e) {
        console.warn("io.github.rizmi.services: failed to parse services.json:", e)
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

  function intSettingLocal(name, fallback, min, max) {
    var v = settings ? settings[name] : undefined
    var n = parseInt(String(v === undefined || v === null ? fallback : v), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  Timer {
    id: pollTimer
    interval: root.intSettingLocal("refreshIntervalSec", 8, 2, 60) * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: {
    reloadConfig()
  }
}

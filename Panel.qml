import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.rizmi.services"
  ipcTarget: "io.github.rizmi.services"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property ServiceManager serviceManager: hostWidget ? hostWidget.serviceManager : null

  function triggerRefresh() {
    if (serviceManager) serviceManager.refresh()
    spinAnimation.restart()
  }

  onOpenedChanged: {
    if (opened && serviceManager) {
      serviceManager.refresh()
      Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.triggerRefresh(); return "ok" }
    function status(): string { return serviceManager ? serviceManager.summaryText : "" }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(480))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTextKey: function(t) {
        if (!serviceManager) return
        if (t === "r" || t === "R") {
          root.triggerRefresh()
        } else if (t === "s" || t === "S") {
          if (serviceManager.runningCount > 0) serviceManager.stopAll()
          else serviceManager.startAll()
        } else {
          var idx = parseInt(t, 10) - 1
          if (idx >= 0 && idx < serviceManager.services.length) {
            serviceManager.toggleService(serviceManager.services[idx].id)
          }
        }
      }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: Style.space(12)

        PanelHero {
          id: hero
          width: parent.width
          title: "Services"
          meta: serviceManager ? serviceManager.summaryText : "Checking status..."
          foreground: root.foreground
          fontFamily: root.fontFamily
          iconOpacity: serviceManager && serviceManager.runningCount > 0 ? 1.0 : 0.6
          iconComponent: Component {
            Text {
              text: "󱌢"
              color: serviceManager && serviceManager.runningCount > 0 ? root.foreground : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
            }
          }
          trailingControl: Component {
            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.cornerRadius
              color: refreshMouse.containsMouse ? Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.15) : "transparent"

              Text {
                id: refreshIcon
                anchors.centerIn: parent
                text: "󰑐"
                color: refreshMouse.containsMouse ? root.foreground : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.body

                NumberAnimation {
                  id: spinAnimation
                  target: refreshIcon
                  property: "rotation"
                  from: 0
                  to: 360
                  duration: 500
                  easing.type: Easing.OutCubic
                }
              }

              MouseArea {
                id: refreshMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.triggerRefresh()
              }

              PanelToolTip {
                visible: refreshMouse.containsMouse
                text: "Refresh status [R]"
                fontFamily: hero.fontFamily
              }
            }
          }
        }

        // Action / Error message
        Text {
          visible: serviceManager && (serviceManager.actionMessage !== "" || serviceManager.lastError !== "")
          width: parent.width
          text: serviceManager ? (serviceManager.actionMessage !== "" ? serviceManager.actionMessage : serviceManager.lastError) : ""
          color: serviceManager && serviceManager.lastError !== "" && serviceManager.actionMessage === "" ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
          wrapMode: Text.WordWrap
        }

        PanelSeparator { foreground: root.foreground }

        // Services list
        Column {
          width: parent.width
          spacing: Style.space(8)

          PanelSectionHeader {
            text: "BACKGROUND SERVICES"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Repeater {
            model: serviceManager ? serviceManager.services : []

            delegate: BorderSurface {
              id: serviceCard
              required property var modelData
              required property int index

              width: parent.width
              implicitHeight: Style.space(56)
              radius: Style.cornerRadius
              color: Style.controlFill(false, cardMouse.containsMouse, root.foreground, Color.accent)
              borderSpec: Border.controlSpec(cardMouse.containsMouse ? "hover-cursor" : "normal", root.foreground, Color.accent)

              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Style.space(12)
                anchors.rightMargin: Style.space(12)
                spacing: Style.space(12)

                // Service Icon Badge
                Rectangle {
                  width: Style.space(34)
                  height: Style.space(34)
                  radius: Style.cornerRadius
                  color: serviceCard.modelData.active
                    ? Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.15)
                    : Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, 0.06)
                  Layout.alignment: Qt.AlignVCenter

                  Text {
                    anchors.centerIn: parent
                    text: serviceCard.modelData.icon
                    color: serviceCard.modelData.active ? (Color.accent || root.foreground) : root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.subtitle
                  }
                }

                // Service info
                Column {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  spacing: Style.space(2)

                  Row {
                    spacing: Style.space(6)
                    Text {
                      text: serviceCard.modelData.name
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                    }
                    Text {
                      text: "[" + (serviceCard.index + 1) + "]"
                      color: root.dim
                      opacity: 0.6
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      anchors.verticalCenter: parent.verticalCenter
                    }
                  }

                  Text {
                    text: serviceCard.modelData.statusLabel + " · " + serviceCard.modelData.unit
                    color: serviceCard.modelData.active ? root.foreground : root.dim
                    opacity: serviceCard.modelData.active ? 0.9 : 0.7
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width
                  }
                }

                // Toggle switch
                ToggleSwitch {
                  id: serviceSwitch
                  checked: serviceCard.modelData.active
                  busy: serviceCard.modelData.busy
                  interactive: !serviceCard.modelData.busy
                  foreground: root.foreground
                  accent: Color.accent
                  Layout.alignment: Qt.AlignVCenter
                  onToggled: if (serviceManager) serviceManager.toggleService(serviceCard.modelData.id)

                  PanelToolTip {
                    visible: serviceSwitch.containsMouse
                    text: serviceCard.modelData.active ? ("Stop " + serviceCard.modelData.name) : ("Start " + serviceCard.modelData.name)
                    fontFamily: root.fontFamily
                  }
                }
              }

              MouseArea {
                id: cardMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  if (serviceManager && !serviceCard.modelData.busy) {
                    serviceManager.toggleService(serviceCard.modelData.id)
                  }
                }
              }
            }
          }
        }

        PanelSeparator { foreground: root.foreground }

        // Bottom Actions
        RowLayout {
          width: parent.width
          spacing: Style.space(8)

          Button {
            text: "Start All"
            iconText: "󰐥"
            Layout.fillWidth: true
            enabled: serviceManager ? serviceManager.runningCount < serviceManager.services.length : false
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: if (serviceManager) serviceManager.startAll()
          }

          Button {
            text: "Stop All"
            iconText: "󰓛"
            Layout.fillWidth: true
            enabled: serviceManager ? serviceManager.runningCount > 0 : false
            foreground: root.foreground
            fontFamily: root.fontFamily
            onClicked: if (serviceManager) serviceManager.stopAll()
          }
        }
      }
    }
  }
}

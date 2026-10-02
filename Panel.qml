import QtQuick
import QtQuick.Controls
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Catalog.js" as Catalog

Panel {
  id: root
  moduleName: "kelvincushman.gestures"
  ipcTarget: "kelvincushman.gestures"
  manageIpc: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string helper: String(Qt.resolvedUrl("bin/gestures")).replace(/^file:\/\//, "")

  property bool enabled: false
  property bool drag3fg: false
  property var rules: []
  property string error: ""
  property bool loaded: false
  property var pending: null

  // The bar sizes each widget slot from the root item's implicit size.
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function run(args) {
    if (helperProcess.running) { pending = args; return }
    helperProcess.command = ["bash", helper].concat(args)
    helperProcess.running = true
  }

  function refresh() { run(["status"]) }

  function commit(next) {
    rules = next
    run(["save"].concat(Catalog.serialize(next)))
  }

  // Changing fingers or action can leave the direction invalid; snap it to the
  // first direction that still works rather than saving a rule the loader skips.
  function updateRule(index, key, value) {
    var next = rules.map(function(r) { return Object.assign({}, r) })
    next[index][key] = value
    var allowed = Catalog.directionsFor(next[index].fingers, next[index].action)
    if (!allowed.some(function(d) { return d.value === next[index].direction }) && allowed.length > 0)
      next[index].direction = allowed[0].value
    commit(next)
  }

  function addRule() {
    commit(rules.concat([{ fingers: "4", direction: "up", action: "menu" }]))
  }

  function removeRule(index) {
    commit(rules.filter(function(_, i) { return i !== index }))
  }

  onOpenedChanged: if (opened) {
    refresh()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  Component.onCompleted: refresh()

  Process {
    id: helperProcess
    running: false
    command: []
    stdout: StdioCollector { id: helperStdout; waitForEnd: true }
    stderr: StdioCollector { id: helperStderr; waitForEnd: true }
    onExited: function(exitCode) {
      var verb = command[2]
      if (exitCode !== 0) {
        root.error = String(helperStderr.text || "Gesture helper failed").trim()
      } else {
        root.error = ""
        if (verb === "status") {
          try {
            var state = JSON.parse(helperStdout.text)
            root.enabled = state.enabled
            root.drag3fg = state.drag3fg
            root.rules = Catalog.parse(state.rules)
            root.loaded = true
          } catch (e) {
            root.error = "Could not read gesture state"
          }
        } else if (verb === "enable" || verb === "disable") {
          root.enabled = verb === "enable"
        }
      }
      if (root.pending) {
        var next = root.pending
        root.pending = null
        root.run(next)
      }
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { root.refresh(); return "ok" }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\u{F073E}"
    dimmed: !root.enabled
    onPressed: function(buttonCode) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(560))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(620))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            id: hero
            width: parent.width
            title: "Gestures"
            meta: root.enabled ? "Touchpad gestures on" : "Touchpad gestures off"
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconOpacity: root.enabled ? 1.0 : 0.5
            iconComponent: Component {
              Item {
                implicitWidth: Style.font.display
                implicitHeight: Style.font.display

                Text {
                  anchors.centerIn: parent
                  text: "\u{F073E}"
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.display
                }
              }
            }
            trailingControl: Component {
              ToggleSwitch {
                checked: root.enabled
                busy: helperProcess.running
                foreground: hero.foreground
                onToggled: root.run([root.enabled ? "disable" : "enable"])
              }
            }
          }

          Note {
            visible: root.error !== ""
            text: root.error
            color: root.urgent
          }

          Note {
            visible: root.loaded && !root.enabled
            text: "Turning gestures on adds a loader line to ~/.config/hypr/hyprland.lua (a backup is saved first)."
          }

          Note {
            visible: root.drag3fg
            text: "Three-finger drag is on in your input settings, so 3-finger swipes will drag instead. Use 4 fingers, or turn off drag_3fg in ~/.config/hypr/input.lua."
            color: root.urgent
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: "GESTURES"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Note {
            visible: root.loaded && root.rules.length === 0
            text: "No gestures yet. Add one, or start from the iOS-like preset."
          }

          Repeater {
            model: root.rules

            Column {
              id: ruleItem
              required property var modelData
              required property int index
              readonly property string problem: Catalog.problem(modelData, root.rules.slice(0, index))
              width: column.width
              spacing: Style.space(4)

              Row {
                spacing: Style.space(6)

                Dropdown {
                  width: Style.space(110)
                  showLabel: false
                  fontFamily: root.fontFamily
                  options: Catalog.fingerOptions
                  value: ruleItem.modelData.fingers
                  onChanged: function(v) { root.updateRule(ruleItem.index, "fingers", v) }
                }

                Dropdown {
                  width: Style.space(140)
                  showLabel: false
                  fontFamily: root.fontFamily
                  options: Catalog.directionsFor(ruleItem.modelData.fingers, ruleItem.modelData.action)
                  value: ruleItem.modelData.direction
                  onChanged: function(v) { root.updateRule(ruleItem.index, "direction", v) }
                }

                Dropdown {
                  width: column.width - Style.space(110 + 140 + 6 * 3) - removeButton.width
                  showLabel: false
                  fontFamily: root.fontFamily
                  options: Catalog.actionOptions
                  value: ruleItem.modelData.action
                  onChanged: function(v) { root.updateRule(ruleItem.index, "action", v) }
                }

                PanelActionButton {
                  id: removeButton
                  anchors.verticalCenter: parent.verticalCenter
                  iconText: "\u{F0156}"
                  tooltipText: "Remove gesture"
                  foreground: root.foreground
                  fontFamily: root.fontFamily
                  onClicked: root.removeRule(ruleItem.index)
                }
              }

              Note {
                visible: ruleItem.problem !== ""
                text: ruleItem.problem
                color: root.urgent
              }
            }
          }

          Row {
            spacing: Style.space(8)

            Button {
              text: "Add gesture"
              iconText: "\u{F0415}"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.addRule()
            }

            Button {
              text: "Use iOS-like preset"
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: root.commit(Catalog.presets.ios)
            }
          }

          Note {
            text: "Two-finger swipes are always scrolling on Linux, so two fingers can only pinch. Changes apply as soon as you make them."
          }
        }
      }
    }
  }

  component Note: Text {
    textFormat: Text.PlainText
    width: column.width
    color: root.dim
    font.family: root.fontFamily
    font.pixelSize: Style.font.bodySmall
    wrapMode: Text.WordWrap
  }
}

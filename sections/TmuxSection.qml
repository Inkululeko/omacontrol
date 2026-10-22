import QtQuick
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  id: page
  property var app: null
  Ui.SettingGroup {
    title: "Keys"

    Ui.TextRow {
      label: "Prefix"
      description: "tmux spelling: C-Space, C-b, M-a."
      placeholder: "C-b"
      value: String(page.app.tmuxValue("prefix", "C-b"))
      onCommitted: function(next) { page.app.setTmux("prefix", next) }
      changed: page.app.isChanged("tmux:prefix")
      onResetRequested: page.app.resetSetting("tmux:prefix")
    }

    Ui.PickerRow {
      label: "Copy mode keys"
      value: String(page.app.tmuxValue("mode-keys", "emacs"))
      options: [
        { value: "vi", label: "Vi" },
        { value: "emacs", label: "Emacs" }
      ]
      onPicked: function(next) { page.app.setTmux("mode-keys", next) }
      changed: page.app.isChanged("tmux:mode-keys")
      onResetRequested: page.app.resetSetting("tmux:mode-keys")
    }

    Ui.ActionRow {
      label: "Every shortcut"
      description: "The full list, as tmux has it."
      buttonText: "Show…"
      onTriggered: page.app.run(["menu", "run", "learn.tmux-keybindings"])
    }
  }

  Ui.SettingGroup {
    title: "Status bar"

    Ui.PickerRow {
      label: "Position"
      value: String(page.app.tmuxValue("status-position", "bottom"))
      options: [
        { value: "top", label: "Top" },
        { value: "bottom", label: "Bottom" }
      ]
      onPicked: function(next) { page.app.setTmux("status-position", next) }
      changed: page.app.isChanged("tmux:status-position")
      onResetRequested: page.app.resetSetting("tmux:status-position")
    }
  }

  Ui.SettingGroup {
    title: "Windows and panes"

    Ui.NumberRow {
      label: "First window number"
      value: Number(page.app.tmuxValue("base-index", 0))
      from: 0
      to: 1
      onCommitted: function(next) { page.app.setTmux("base-index", next) }
      changed: page.app.isChanged("tmux:base-index")
      onResetRequested: page.app.resetSetting("tmux:base-index")
    }

    Ui.NumberRow {
      label: "First pane number"
      value: Number(page.app.tmuxValue("pane-base-index", 0))
      from: 0
      to: 1
      onCommitted: function(next) { page.app.setTmux("pane-base-index", next) }
      changed: page.app.isChanged("tmux:pane-base-index")
      onResetRequested: page.app.resetSetting("tmux:pane-base-index")
    }

    Ui.SwitchRow {
      label: "Renumber when one closes"
      checked: page.app.tmuxValue("renumber-windows", false) === true
      onRequested: function(next) { page.app.setTmux("renumber-windows", next ? "true" : "false") }
      changed: page.app.isChanged("tmux:renumber-windows")
      onResetRequested: page.app.resetSetting("tmux:renumber-windows")
    }
  }

  Ui.SettingGroup {
    title: "Behaviour"

    Ui.SwitchRow {
      label: "Mouse"
      description: "Click to focus a pane, drag to resize, scroll to page back."
      checked: page.app.tmuxValue("mouse", false) === true
      onRequested: function(next) { page.app.setTmux("mouse", next ? "true" : "false") }
      changed: page.app.isChanged("tmux:mouse")
      onResetRequested: page.app.resetSetting("tmux:mouse")
    }

    Ui.NumberRow {
      label: "Scrollback"
      suffix: "lines"
      value: Number(page.app.tmuxValue("history-limit", 2000))
      from: 1000
      to: 100000
      step: 1000
      onCommitted: function(next) { page.app.setTmux("history-limit", next) }
      changed: page.app.isChanged("tmux:history-limit")
      onResetRequested: page.app.resetSetting("tmux:history-limit")
    }

    Ui.NumberRow {
      label: "Escape delay"
      suffix: "ms"
      description: "Low values keep Esc snappy in Vim; zero can break some terminals."
      value: Number(page.app.tmuxValue("escape-time", 500))
      from: 0
      to: 500
      step: 10
      onCommitted: function(next) { page.app.setTmux("escape-time", next) }
      changed: page.app.isChanged("tmux:escape-time")
      onResetRequested: page.app.resetSetting("tmux:escape-time")
    }

    Ui.PickerRow {
      label: "Clipboard"
      description: "Whether tmux hands copied text to the outer terminal."
      value: String(page.app.tmuxValue("set-clipboard", "external"))
      options: [
        { value: "on", label: "On" },
        { value: "external", label: "External only" },
        { value: "off", label: "Off" }
      ]
      onPicked: function(next) { page.app.setTmux("set-clipboard", next) }
      changed: page.app.isChanged("tmux:set-clipboard")
      onResetRequested: page.app.resetSetting("tmux:set-clipboard")
    }
  }

  Ui.SettingGroup {
    title: "Beyond these settings"

    Ui.ActionRow {
      label: "The rest of the config"
      description: "Open tmux.conf for bindings, styling, and plugins."
      buttonText: "Edit…"
      onTriggered: page.app.editConfig("$HOME/.config/tmux/tmux.conf")
    }
  }
}

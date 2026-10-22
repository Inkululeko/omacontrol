import QtQuick
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  id: page
  property var app: null
  Ui.SettingGroup {
    title: "Appearance"

    Ui.PickerRow {
      label: "Theme"
      value: String(page.app.herdrValue("theme.name", "catppuccin"))
      options: [
        { value: "terminal", label: "Terminal palette" },
        { value: "catppuccin", label: "Catppuccin" },
        { value: "tokyo-night", label: "Tokyo Night" },
        { value: "dracula", label: "Dracula" },
        { value: "nord", label: "Nord" },
        { value: "gruvbox", label: "Gruvbox" },
        { value: "one-dark", label: "One Dark" },
        { value: "solarized", label: "Solarized" },
        { value: "kanagawa", label: "Kanagawa" },
        { value: "rose-pine", label: "Rosé Pine" },
        { value: "vesper", label: "Vesper" }
      ]
      onPicked: function(next) { page.app.setHerdr("theme.name", next) }
      changed: page.app.isChanged("herdr:theme.name")
      onResetRequested: page.app.resetSetting("herdr:theme.name")
    }

    Ui.TextRow {
      label: "Accent"
      description: "A colour name, #rrggbb, or rgb(r,g,b)."
      placeholder: "cyan"
      value: String(page.app.herdrValue("ui.accent", "cyan"))
      onCommitted: function(next) { page.app.setHerdr("ui.accent", next) }
      changed: page.app.isChanged("herdr:ui.accent")
      onResetRequested: page.app.resetSetting("herdr:ui.accent")
    }

    Ui.PickerRow {
      label: "Tab bar"
      value: String(page.app.herdrValue("ui.tab_bar_position", "top"))
      options: [
        { value: "top", label: "Top" },
        { value: "bottom", label: "Bottom" }
      ]
      onPicked: function(next) { page.app.setHerdr("ui.tab_bar_position", next) }
      changed: page.app.isChanged("herdr:ui.tab_bar_position")
      onResetRequested: page.app.resetSetting("herdr:ui.tab_bar_position")
    }

    Ui.SwitchRow {
      label: "Hide the tab bar with one tab"
      checked: page.app.herdrValue("ui.hide_tab_bar_when_single_tab", false) === true
      onRequested: function(next) { page.app.setHerdr("ui.hide_tab_bar_when_single_tab", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.hide_tab_bar_when_single_tab")
      onResetRequested: page.app.resetSetting("herdr:ui.hide_tab_bar_when_single_tab")
    }
  }

  Ui.SettingGroup {
    title: "Panes"

    Ui.SwitchRow {
      label: "Borders"
      checked: page.app.herdrValue("ui.pane_borders", true) === true
      onRequested: function(next) { page.app.setHerdr("ui.pane_borders", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.pane_borders")
      onResetRequested: page.app.resetSetting("herdr:ui.pane_borders")
    }

    Ui.SwitchRow {
      label: "Outer border"
      description: "Off gives tmux-style splitters with no frame around the edge."
      checked: page.app.herdrValue("ui.pane_outer_borders", true) === true
      onRequested: function(next) { page.app.setHerdr("ui.pane_outer_borders", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.pane_outer_borders")
      onResetRequested: page.app.resetSetting("herdr:ui.pane_outer_borders")
    }

    Ui.SwitchRow {
      label: "Gaps between panes"
      checked: page.app.herdrValue("ui.pane_gaps", true) === true
      onRequested: function(next) { page.app.setHerdr("ui.pane_gaps", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.pane_gaps")
      onResetRequested: page.app.resetSetting("herdr:ui.pane_gaps")
    }

    Ui.SwitchRow {
      label: "Scrollbars"
      checked: page.app.herdrValue("ui.pane_scrollbars", true) === true
      onRequested: function(next) { page.app.setHerdr("ui.pane_scrollbars", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.pane_scrollbars")
      onResetRequested: page.app.resetSetting("herdr:ui.pane_scrollbars")
    }

    Ui.SwitchRow {
      label: "Agent labels on borders"
      description: "Shown when a pane has no name of its own."
      checked: page.app.herdrValue("ui.show_agent_labels_on_pane_borders", false) === true
      onRequested: function(next) { page.app.setHerdr("ui.show_agent_labels_on_pane_borders", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.show_agent_labels_on_pane_borders")
      onResetRequested: page.app.resetSetting("herdr:ui.show_agent_labels_on_pane_borders")
    }
  }

  Ui.SettingGroup {
    title: "Sidebar"

    Ui.NumberRow {
      label: "Width"
      suffix: "columns"
      value: Number(page.app.herdrValue("ui.sidebar_width", 26))
      from: 12
      to: 60
      onCommitted: function(next) { page.app.setHerdr("ui.sidebar_width", next) }
      changed: page.app.isChanged("herdr:ui.sidebar_width")
      onResetRequested: page.app.resetSetting("herdr:ui.sidebar_width")
    }

    Ui.SwitchRow {
      label: "Start collapsed"
      description: "Takes effect the next time Herdr launches."
      checked: page.app.herdrValue("ui.sidebar_start_collapsed", false) === true
      onRequested: function(next) { page.app.setHerdr("ui.sidebar_start_collapsed", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.sidebar_start_collapsed")
      onResetRequested: page.app.resetSetting("herdr:ui.sidebar_start_collapsed")
    }

    Ui.PickerRow {
      label: "When collapsed"
      value: String(page.app.herdrValue("ui.sidebar_collapsed_mode", "compact"))
      options: [
        { value: "compact", label: "Keep the status rail" },
        { value: "hidden", label: "Hide it completely" }
      ]
      onPicked: function(next) { page.app.setHerdr("ui.sidebar_collapsed_mode", next) }
      changed: page.app.isChanged("herdr:ui.sidebar_collapsed_mode")
      onResetRequested: page.app.resetSetting("herdr:ui.sidebar_collapsed_mode")
    }
  }

  Ui.SettingGroup {
    title: "Behaviour"

    Ui.PickerRow {
      label: "New panes open in"
      value: String(page.app.herdrValue("terminal.new_cwd", "follow"))
      options: [
        { value: "follow", label: "The folder you were in" },
        { value: "home", label: "Your home folder" },
        { value: "current", label: "Herdr's own folder" }
      ]
      onPicked: function(next) { page.app.setHerdr("terminal.new_cwd", next) }
      changed: page.app.isChanged("herdr:terminal.new_cwd")
      onResetRequested: page.app.resetSetting("herdr:terminal.new_cwd")
    }

    Ui.SwitchRow {
      label: "Capture the mouse"
      description: "Off lets the terminal handle clicks, so links stay clickable."
      checked: page.app.herdrValue("ui.mouse_capture", true) === true
      onRequested: function(next) { page.app.setHerdr("ui.mouse_capture", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.mouse_capture")
      onResetRequested: page.app.resetSetting("herdr:ui.mouse_capture")
    }

    Ui.SwitchRow {
      label: "Copy on selection"
      checked: page.app.herdrValue("ui.copy_on_select", true) === true
      onRequested: function(next) { page.app.setHerdr("ui.copy_on_select", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.copy_on_select")
      onResetRequested: page.app.resetSetting("herdr:ui.copy_on_select")
    }

    Ui.NumberRow {
      label: "Scroll step"
      suffix: "lines"
      value: Number(page.app.herdrValue("ui.mouse_scroll_lines", 3))
      from: 1
      to: 10
      onCommitted: function(next) { page.app.setHerdr("ui.mouse_scroll_lines", next) }
      changed: page.app.isChanged("herdr:ui.mouse_scroll_lines")
      onResetRequested: page.app.resetSetting("herdr:ui.mouse_scroll_lines")
    }

    Ui.SwitchRow {
      label: "Confirm before closing"
      checked: page.app.herdrValue("ui.confirm_close", true) === true
      onRequested: function(next) { page.app.setHerdr("ui.confirm_close", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.confirm_close")
      onResetRequested: page.app.resetSetting("herdr:ui.confirm_close")
    }

    Ui.SwitchRow {
      label: "Ask for a tab name"
      checked: page.app.herdrValue("ui.prompt_new_tab_name", true) === true
      onRequested: function(next) { page.app.setHerdr("ui.prompt_new_tab_name", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.prompt_new_tab_name")
      onResetRequested: page.app.resetSetting("herdr:ui.prompt_new_tab_name")
    }

    Ui.SwitchRow {
      label: "Ask for a workspace name"
      checked: page.app.herdrValue("ui.prompt_new_workspace_name", false) === true
      onRequested: function(next) { page.app.setHerdr("ui.prompt_new_workspace_name", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.prompt_new_workspace_name")
      onResetRequested: page.app.resetSetting("herdr:ui.prompt_new_workspace_name")
    }
  }

  Ui.SettingGroup {
    title: "Notifications"

    Ui.PickerRow {
      label: "Pop-ups"
      value: String(page.app.herdrValue("ui.toast.delivery", "off"))
      options: [
        { value: "off", label: "None" },
        { value: "herdr", label: "Inside Herdr" },
        { value: "terminal", label: "Through the terminal" },
        { value: "system", label: "Desktop notifications" }
      ]
      onPicked: function(next) { page.app.setHerdr("ui.toast.delivery", next) }
      changed: page.app.isChanged("herdr:ui.toast.delivery")
      onResetRequested: page.app.resetSetting("herdr:ui.toast.delivery")
    }

    Ui.SwitchRow {
      label: "Sounds"
      description: "Played when an agent changes state in a background workspace."
      checked: page.app.herdrValue("ui.sound.enabled", true) === true
      onRequested: function(next) { page.app.setHerdr("ui.sound.enabled", next ? "true" : "false") }
      changed: page.app.isChanged("herdr:ui.sound.enabled")
      onResetRequested: page.app.resetSetting("herdr:ui.sound.enabled")
    }
  }

  Ui.SettingGroup {
    title: "Keys"

    Ui.TextRow {
      label: "Prefix"
      description: "Every prefix+… shortcut starts with this."
      placeholder: "ctrl+b"
      value: String(page.app.herdrValue("keys.prefix", "ctrl+b"))
      onCommitted: function(next) { page.app.setHerdr("keys.prefix", next) }
      changed: page.app.isChanged("herdr:keys.prefix")
      onResetRequested: page.app.resetSetting("herdr:keys.prefix")
    }

    Ui.ActionRow {
      label: "Every shortcut"
      description: "The full list, as Herdr has it."
      buttonText: "Show…"
      onTriggered: page.app.run(["menu", "run", "learn.herdr-keybindings"])
    }

    Ui.ActionRow {
      label: "The rest of the config"
      description: "Open config.toml for the settings this page does not cover."
      buttonText: "Edit…"
      onTriggered: page.app.editConfig("$HOME/.config/herdr/config.toml")
    }
  }

  Ui.SettingGroup {
    title: "Window title"

    Ui.TextRow {
      label: "Title"
      description: "Tokens: {hostname}, {workspace}, {tab}, {pane}, {terminal_title}."
      placeholder: "{hostname}: {workspace}"
      value: String(page.app.herdrValue("ui.window_title", ""))
      onCommitted: function(next) { page.app.setHerdr("ui.window_title", next) }
      changed: page.app.isChanged("herdr:ui.window_title")
      onResetRequested: page.app.resetSetting("herdr:ui.window_title")
    }
  }
}

import QtQuick
import qs.Commons
import qs.Ui
import "../ui" as Ui

// Injected by the window when the page is loaded: the state every
// row reads, and the calls every control makes.
Ui.SectionBody {
  id: page
  property var app: null

  // The list is read when the page opens and again after a theme is set, not
  // on a timer: a theme changes when someone changes it.
  Component.onCompleted: app.readThemes()

  // Which tile the click claimed is held by the window, not here: applying a
  // theme can rebuild this page, and a mark that dies with the page is a ring
  // that jumps back to the old theme half way through the switch.

  Ui.SettingGroup {
    // The page is called Theme and the pictures are the choice, so a heading
    // over them would say the page's name a second time.
    visible: !searchEmpty

    Ui.PictureGrid {
      items: page.themeTiles
      columns: 2
      onChose: function(name) { app.setTheme(name) }
    }
  }

  readonly property var themeTiles: {
    var out = []
    var list = app.themeList
    for (var i = 0; i < list.length; i++)
      out.push({ source: list[i].preview, title: list[i].name, value: list[i].name,
                 current: app.themePending !== "" ? list[i].name === app.themePending
                                                  : list[i].current === true })
    return out
  }

}

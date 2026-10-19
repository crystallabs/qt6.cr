// QAction::setMenu and menu are templates in Qt 6 (QAction moved to QtGui,
// which doesn't know QMenu), dispatching to the private setMenuObject and
// menuObject.  bindgen can't bind templates, so these instantiate them for
// QMenu.  See `Qt::Action#menu=` and `#menu` in src/qt6/action.cr.
#include <QtGui/QAction>
#include <QtWidgets/QMenu>

void qt6cr_action_set_menu(QAction *action, QMenu *menu) {
  action->setMenu(menu);
}

QMenu *qt6cr_action_menu(const QAction *action) {
  return action->menu();
}

module Qt
  # `QAction::setMenu` and `menu` are templates in Qt 6, which bindgen can't
  # bind, so these call the helpers of `ext/action_helper.hpp`.
  class Action
    # Sets the menu the action shows, like a submenu in a menu bar, and keeps
    # it alive: Qt keeps a pointer to it without taking ownership.
    def menu=(menu : Menu) : Void
      BindgenHelper.keep_alive(menu)
      Qt.qt6cr_action_set_menu(self, menu)
    end

    # Returns the menu the action shows, if any.
    def menu : Menu?
      Qt.qt6cr_action_menu(self)
    end
  end
end

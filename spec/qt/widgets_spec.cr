require "../spec_helper"

describe "widgets" do
  it "build a window with a layout" do
    window = Qt::MainWindow.new
    window.window_title = "spec"
    central = Qt::Widget.new
    layout = Qt::GridLayout.new
    label = Qt::Label.new("name")
    edit = Qt::LineEdit.new
    button = Qt::PushButton.new("ok")
    layout.add_widget(label, 0, 0)
    layout.add_widget(edit, 0, 1)
    layout.add_widget(button, 1, 0, 1, 2)
    central.layout = layout
    window.central_widget = central
    window.resize(300, 200)
    window.show

    window.window_title.should eq("spec")
    window.visible?.should be_true
    window.width.should eq(300)
    layout.count.should eq(3)
    layout.row_count.should eq(2)
    layout.column_count.should eq(2)
    label.parent_widget.should eq(central)
    label.text.should eq("name")
    button.text.should eq("ok")

    window.hide
    window.visible?.should be_false
  end

  it "emit button signals" do
    button = Qt::PushButton.new("toggle")
    button.checkable = true
    clicks = [] of Bool
    toggles = [] of Bool
    button.on_clicked { |checked| clicks << checked }
    button.on_toggled { |checked| toggles << checked }

    button.click
    button.click
    clicks.should eq([true, false])
    toggles.should eq([true, false])
    button.checked?.should be_false
  end

  it "emit check box and slider signals" do
    check_box = Qt::CheckBox.new("check")
    states = [] of Bool
    check_box.on_toggled { |checked| states << checked }
    check_box.checked = true
    check_box.checked?.should be_true
    states.should eq([true])

    slider = Qt::Slider.new
    slider.set_range(0, 10)
    values = [] of Int32
    slider.on_value_changed { |value| values << value }
    slider.value = 7
    slider.value = 70 # Clamped to the range
    slider.value.should eq(10)
    values.should eq([7, 10])
  end

  it "edit text" do
    edit = Qt::LineEdit.new("initial")
    texts = [] of String
    edit.on_text_changed { |text| texts << text }
    edit.text = "changed"
    edit.insert("!")
    edit.text.should eq("changed!")
    texts.should eq(["changed", "changed!"])
    edit.clear
    edit.text.should eq("")
  end

  it "manage tabs and combo boxes" do
    tabs = Qt::TabWidget.new
    tabs.add_tab(Qt::Label.new("one"), "first")
    tabs.add_tab(Qt::Label.new("two"), "second")
    tabs.count.should eq(2)
    tabs.tab_text(1).should eq("second")
    tabs.current_index = 1
    tabs.current_index.should eq(1)

    combo = Qt::ComboBox.new
    combo.add_items(["a", "b", "c"])
    combo.count.should eq(3)
    combo.current_index = 2
    combo.current_text.should eq("c")
  end
end

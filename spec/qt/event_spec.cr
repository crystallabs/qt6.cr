require "../spec_helper"

private class KeyCountingEdit < Qt::LineEdit
  getter presses = [] of Int32

  def key_press_event(event : Qt::KeyEvent) : Void
    @presses << event.key
    superclass.key_press_event(event)
  end
end

private class ClosingWidget < Qt::Widget
  getter closed = false

  def close_event(event : Qt::CloseEvent) : Void
    @closed = true
    superclass.close_event(event)
  end
end

private def press(widget, key : Qt::Key, text : String)
  modifiers = Qt::KeyboardModifiers::NoModifier
  event = Qt::KeyEvent.new(Qt::Event::Type::KeyPress, key.value.to_i32, modifiers, text)
  Qt::Application.send_event(widget, event)
end

describe "events" do
  it "are delivered to widgets" do
    edit = Qt::LineEdit.new
    edit.show
    press(edit, Qt::Key::H, "h")
    press(edit, Qt::Key::I, "i")
    edit.text.should eq("hi")
  end

  it "reach virtual overrides in Crystal subclasses" do
    edit = KeyCountingEdit.new
    edit.show
    press(edit, Qt::Key::A, "a")
    press(edit, Qt::Key::B, "b")
    edit.presses.should eq([Qt::Key::A.value.to_i32, Qt::Key::B.value.to_i32])
    edit.text.should eq("ab")

    widget = ClosingWidget.new
    widget.show
    widget.close.should be_true
    widget.closed.should be_true
    widget.visible?.should be_false
  end
end

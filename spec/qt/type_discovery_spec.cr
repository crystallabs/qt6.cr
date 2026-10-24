require "../spec_helper"

# A pointer result or callback argument is wrapped in the class of the
# object's dynamic type, the most derived class the binding knows.
class DiscoveryLabel < Qt::Label
end

class DiscoveryWidget < Qt::Widget
  getter event_classes = [] of Qt::Event.class

  def event(event : Qt::Event) : Bool
    @event_classes << event.class
    super
  end
end

describe "Type discovery" do
  it "wraps children in their dynamic classes" do
    parent = Qt::Widget.new
    Qt::Label.new("l", parent)
    Qt::PushButton.new("b", parent)
    children = parent.children
    children.map(&.class).should eq([Qt::Label, Qt::PushButton])
    typeof(children.first).should eq(Qt::Object)
  end

  it "wraps abstract results in the concrete class" do
    group = Qt::ButtonGroup.new
    button = Qt::PushButton.new("b")
    group.add_button(button, 3)
    group.button(3).should be_a(Qt::PushButton)
    group.button(3).not_nil!.to_unsafe.should eq(button.to_unsafe)
    group.buttons.map(&.class).should eq([Qt::PushButton])

    view = Qt::ListView.new
    model = Qt::StringListModel.new(["a"])
    view.model = model
    view.model.should be_a(Qt::StringListModel)
    view.model.not_nil!.to_unsafe.should eq(model.to_unsafe)
  end

  it "wraps signal block arguments" do
    group = Qt::ButtonGroup.new
    button = Qt::PushButton.new("b")
    group.add_button(button)
    got = nil.as(Qt::AbstractButton?)
    group.on_button_clicked { |b| got = b }
    button.click
    got.should be_a(Qt::PushButton)
    got.not_nil!.to_unsafe.should eq(button.to_unsafe)
  end

  it "wraps override arguments" do
    widget = DiscoveryWidget.new
    event = Qt::KeyEvent.new(Qt::Event::Type::KeyPress, Qt::Key::A.value.to_i32, Qt::KeyboardModifiers::NoModifier, "a")
    Qt::CoreApplication.send_event(widget, event)
    widget.event_classes.should contain(Qt::KeyEvent)
  end

  it "wraps a Crystal subclass in its wrapper class" do
    parent = Qt::Widget.new
    label = DiscoveryLabel.new("l", parent)
    found = parent.children.first
    found.class.should eq(Qt::Label)
    found.to_unsafe.should eq(label.to_unsafe)
  end

  it "wraps the application in its class" do
    Qt::CoreApplication.instance.class.should eq(Qt::Application)
  end
end

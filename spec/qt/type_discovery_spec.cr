require "../spec_helper"

# A pointer result or callback argument is wrapped in the class of the
# object's dynamic type, the most derived class the binding knows.
class DiscoveryLabel < Qt::Label
end

class NotedLabel < Qt::Label
  property note = ""
end

class NotedButton < Qt::PushButton
  property note = ""
end

class DiscoveryWidget < Qt::Widget
  getter event_classes = [] of Qt::Event.class
  getter events = [] of Qt::Event

  def event(event : Qt::Event) : Bool
    @event_classes << event.class
    @events << event
    super
  end
end

private class PrivateLabel < Qt::Label
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

  it "returns the Crystal subclass instance which constructed the object" do
    parent = Qt::Widget.new
    label = DiscoveryLabel.new("l", parent)
    found = parent.children.first
    found.should be(label)
    found.class.should eq(DiscoveryLabel)
  end

  it "returns an instance of a private Crystal subclass" do
    parent = Qt::Widget.new
    label = PrivateLabel.new("l", parent)
    parent.children.first.should be(label)
  end

  it "returns the very objects constructed from Crystal" do
    parent = Qt::Widget.new
    label = Qt::Label.new("l", parent)
    button = Qt::PushButton.new("b", parent)
    children = parent.children
    children[0].should be(label)
    children[1].should be(button)
  end

  it "keeps the instance variables of a Crystal subclass" do
    parent = Qt::Widget.new
    label = NotedLabel.new("l", parent)
    label.note = "kept"
    parent.children.first.as(NotedLabel).note.should eq("kept")

    layout = Qt::VBoxLayout.new(parent)
    layout.add_widget(label)
    layout.item_at(0).not_nil!.widget.should be(label)

    got = nil.as(Qt::Object?)
    group = Qt::ButtonGroup.new
    button = NotedButton.new("b")
    button.note = "signal"
    group.add_button(button)
    group.on_button_clicked { |b| got = b }
    button.click
    got.should be(button)
    got.as(NotedButton).note.should eq("signal")
  end

  it "returns the Crystal object from to?" do
    parent = Qt::Widget.new
    button = Qt::PushButton.new("b", parent)
    widget = parent.children.first.as(Qt::Widget)
    widget.to?(Qt::Widget).should be(button)
    widget.to?(Qt::PushButton).should be(button)
  end

  it "wraps an object C++ created in a new wrapper each time" do
    a = Qt::CoreApplication.instance.not_nil!
    b = Qt::CoreApplication.instance.not_nil!
    a.should_not be(b)
    a.to_unsafe.should eq(b.to_unsafe)

    widget = DiscoveryWidget.new
    widget.show
    widget.hide
    widget.events.size.should be > 0
    widget.events.each_with_index do |event, i|
      widget.events[(i + 1)..].each { |other| event.should_not be(other) }
    end
  end

  it "wraps the application in its class" do
    Qt::CoreApplication.instance.class.should eq(Qt::Application)
  end
end

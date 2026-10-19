require "../spec_helper"
require "openssl/hmac"

# Records the input events it receives.
private class RecordingWidget < Qt::Widget
  getter wheel_deltas = [] of Int32
  getter event_types = [] of Qt::Event::Type
  getter context_menus = [] of Qt::ContextMenuEvent::Reason
  getter timer_ticks = 0
  property loop : Qt::EventLoop?

  def event(event : Qt::Event) : Bool
    @event_types << event.type
    superclass.event(event)
  end

  def wheel_event(event : Qt::WheelEvent) : Void
    @wheel_deltas << event.angle_delta.y
    event.accept
  end

  def context_menu_event(event : Qt::ContextMenuEvent) : Void
    @context_menus << event.reason
  end

  def timer_event(event : Qt::TimerEvent) : Void
    @timer_ticks += 1
    @loop.try(&.quit) if @timer_ticks == 2
  end
end

describe "input events" do
  it "are delivered to a widget's overrides" do
    widget = RecordingWidget.new
    widget.resize(50, 50)
    widget.set_attribute(Qt::Widget::Attribute::AcceptTouchEvents, true)
    widget.show

    wheel = Qt::WheelEvent.new(Qt::PointF.new(5.0, 5.0), Qt::PointF.new(5.0, 5.0), Qt::Point.new(0, 0), Qt::Point.new(0, 120),
      Qt::MouseButtons::NoButton, Qt::KeyboardModifiers::NoModifier, Qt::ScrollPhase::NoScrollPhase, false)
    wheel.angle_delta.should eq(Qt::Point.new(0, 120))
    wheel.phase.should eq(Qt::ScrollPhase::NoScrollPhase)
    wheel.inverted?.should be_false
    Qt::Application.send_event(widget, wheel).should be_true
    widget.wheel_deltas.should eq([120])

    hover = Qt::HoverEvent.new(Qt::Event::Type::HoverMove, Qt::PointF.new(3.0, 4.0), Qt::PointF.new(13.0, 14.0), Qt::PointF.new(1.0, 1.0))
    hover.old_pos_f.should eq(Qt::PointF.new(1.0, 1.0))
    hover.position.should eq(Qt::PointF.new(3.0, 4.0))
    hover.update_event?.should be_true
    Qt::Application.send_event(widget, hover)
    widget.event_types.should contain(Qt::Event::Type::HoverMove)

    point = Qt::EventPoint.new(1, Qt::EventPoint::State::Pressed, Qt::PointF.new(2.0, 3.0), Qt::PointF.new(12.0, 13.0))
    point.id.should eq(1)
    point.state.should eq(Qt::EventPoint::State::Pressed)
    point.scene_position.should eq(Qt::PointF.new(2.0, 3.0))
    point.global_position.should eq(Qt::PointF.new(12.0, 13.0))
    touch = Qt::TouchEvent.new(Qt::Event::Type::TouchBegin, Qt::PointingDevice.primary_pointing_device, Qt::KeyboardModifiers::NoModifier, [point])
    touch.points.size.should eq(1)
    touch.points.first.id.should eq(1)
    touch.touch_point_states.should eq(Qt::EventPoint::States::Pressed)
    touch.begin_event?.should be_true
    Qt::Application.send_event(widget, touch)
    widget.event_types.should contain(Qt::Event::Type::TouchBegin)

    menu = Qt::ContextMenuEvent.new(Qt::ContextMenuEvent::Reason::Keyboard, Qt::Point.new(1, 1), Qt::Point.new(2, 2))
    menu.pos.should eq(Qt::Point.new(1, 1))
    Qt::Application.send_event(widget, menu)
    widget.context_menus.should eq([Qt::ContextMenuEvent::Reason::Keyboard])

    child = Qt::Object.new
    child_event = Qt::ChildEvent.new(Qt::Event::Type::ChildAdded, child)
    child_event.child.not_nil!.to_unsafe.should eq(child.to_unsafe)
    child_event.added.should be_true
    Qt::WindowStateChangeEvent.new(Qt::WindowStates::WindowMinimized).old_state.should eq(Qt::WindowStates::WindowMinimized)
    {% if Qt::QT_VERSION >= 0x060700 %}
      window = Qt::Window.new
      Qt::ChildWindowEvent.new(Qt::Event::Type::ChildWindowAdded, window).child.not_nil!.to_unsafe.should eq(window.to_unsafe)
    {% end %}
  end

  it "come from input devices" do
    device = Qt::PointingDevice.primary_pointing_device.not_nil!
    device.pointer_type.should eq(Qt::PointingDevice::PointerType::Generic)
    device.type.should eq(Qt::InputDevice::DeviceType::Mouse)
    device.name.should_not be_empty
    Qt::InputDevice.devices.to_a.should_not be_empty
    Qt::PointingDevice.devices.to_a.map(&.to_unsafe).should contain(device.to_unsafe)
    id = Qt::PointingDeviceUniqueId.from_numeric_id(42)
    id.valid?.should be_true
    id.numeric_id.should eq(42)
    Qt::PointingDeviceUniqueId.new.valid?.should be_false

    combination = Qt::KeyCombination.new(Qt::KeyboardModifiers::ControlModifier, Qt::Key::A)
    combination.key.should eq(Qt::Key::A)
    combination.keyboard_modifiers.should eq(Qt::KeyboardModifiers::ControlModifier)
    Qt::KeyCombination.from_combined(combination.to_combined).should eq(combination)
    Qt::KeySequence.new(combination.to_combined).to_string.should_not be_empty

    input_method = Qt::GuiApplication.input_method.not_nil!
    input_method.visible?.should be_false
    input_method.keyboard_rectangle.should be_a(Qt::RectF)
    input_method.locale.should be_a(Qt::Locale)
  end

  it "describe gestures" do
    pan = Qt::PanGesture.new
    pan.gesture_type.should eq(Qt::GestureType::PanGesture)
    pan.offset = Qt::PointF.new(3.0, 4.0)
    pan.offset.should eq(Qt::PointF.new(3.0, 4.0))
    pinch = Qt::PinchGesture.new
    pinch.total_scale_factor = 2.0
    pinch.total_scale_factor.should eq(2.0)
    pinch.change_flags = Qt::PinchGesture::ChangeFlags::ScaleFactorChanged
    pinch.change_flags.should eq(Qt::PinchGesture::ChangeFlags::ScaleFactorChanged)
    swipe = Qt::SwipeGesture.new
    swipe.swipe_angle = 90.0
    swipe.vertical_direction.should eq(Qt::SwipeGesture::SwipeDirection::Up)
    tap = Qt::TapGesture.new
    tap.position = Qt::PointF.new(1.0, 2.0)
    tap.position.should eq(Qt::PointF.new(1.0, 2.0))
    Qt::TapAndHoldGesture.timeout = 600
    Qt::TapAndHoldGesture.timeout.should eq(600)
  end
end

describe Qt::BasicTimer do
  it "ticks a widget's timer_event" do
    widget = RecordingWidget.new
    loop = Qt::EventLoop.new
    widget.loop = loop
    timer = Qt::BasicTimer.new
    timer.active?.should be_false
    timer.start(1, widget)
    timer.active?.should be_true
    timer.timer_id.should be > 0
    loop.exec.should eq(0)
    timer.stop
    timer.active?.should be_false
    widget.timer_ticks.should eq(2)
  end

  {% if Qt::QT_VERSION >= 0x060800 %}
    it "counts in durations as a chrono timer" do
      loop = Qt::EventLoop.new
      timer = Qt::ChronoTimer.new(5.milliseconds)
      timer.interval.should eq(5.milliseconds)
      timer.single_shot = true
      fired = 0
      timer.on_timeout do
        fired += 1
        loop.quit
      end
      timer.start
      timer.active?.should be_true
      timer.remaining_time.should be <= 5.milliseconds
      loop.exec.should eq(0)
      Qt::Application.process_events
      fired.should eq(1)
      timer.active?.should be_false
    end
  {% end %}
end

describe Qt::SignalMapper do
  it "maps a button's click to a string" do
    mapper = Qt::SignalMapper.new
    button = Qt::PushButton.new("one")
    mapper.set_mapping(button, "first")
    mapper.mapping("first").not_nil!.to_unsafe.should eq(button.to_unsafe)
    button.on_clicked { mapper.map(button) }
    received = [] of String
    mapper.on_mapped_string { |text| received << text }
    button.click
    received.should eq(["first"])
    mapper.remove_mappings(button)
    button.click
    received.size.should eq(1)
  end
end

describe Qt::JsonDocument do
  it "parses and serializes objects and arrays" do
    document = Qt::JsonDocument.from_json(%({"name": "qt6", "items": [1, 2.5, {"deep": true}], "none": null}).to_slice)
    document.null?.should be_false
    document.object?.should be_true
    object = document.object
    object.keys.to_a.sort.should eq(["items", "name", "none"])
    object.contains("name").should be_true
    object["name"].to_string.should eq("qt6")
    object.value("none").null?.should be_true
    items = object["items"].to_array
    items.size.should eq(3)
    items.at(0).to_int.should eq(1)
    items.at(1).to_double.should eq(2.5)
    items.at(2).to_object["deep"].to_bool.should be_true
    items.contains(Qt::JsonValue.new(1)).should be_true
    document["name"].to_string.should eq("qt6")

    built = Qt::JsonObject.new
    built.insert("x", Qt::JsonValue.new(1))
    built.insert("s", Qt::JsonValue.new("text"))
    array = Qt::JsonArray.new
    array << Qt::JsonValue.new(true)
    array.append(Qt::JsonValue.new(2.0))
    built.insert("a", Qt::JsonValue.new(array))
    built.size.should eq(3)
    built["a"].to_array.last.to_double.should eq(2.0)
    json = String.new(Qt::JsonDocument.new(built).to_json(Qt::JsonDocument::JsonFormat::Compact))
    json.should eq(%({"a":[true,2],"s":"text","x":1}))
    Qt::JsonDocument.from_json(json.to_slice).object.should eq(built)
    Qt::JsonArray.from_string_list(["a", "b"]).size.should eq(2)
    built.remove("x")
    built.contains("x").should be_false
    built.take("s").to_string.should eq("text")

    error = Qt::JsonParseError.new
    Qt::JsonDocument.from_json("{bad".to_slice, error).null?.should be_true
    error.error.should_not eq(Qt::JsonParseError::ParseError::NoError)
    error.error_string.should_not be_empty
    error.offset.should be > 0
    Qt::JsonValue.new("s").type.should eq(Qt::JsonValue::Type::String)
    Qt::JsonValue.new(Qt::JsonValue::Type::Null).null?.should be_true
    Qt::JsonValue.from_variant(Qt::Variant.new(7)).to_int.should eq(7)
    Qt::JsonValue.new(7).to_variant.to?(Int64).should eq(7)
  end
end

describe Qt::XmlStreamWriter do
  it "writes XML that the reader reads back" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
    writer = Qt::XmlStreamWriter.new(buffer)
    writer.auto_formatting = true
    writer.write_start_document
    writer.write_start_element("root")
    writer.write_attribute("version", "1")
    writer.write_attribute("lang", "en")
    writer.write_text_element("child", "text & more")
    writer.write_empty_element("empty")
    writer.write_comment("note")
    writer.write_end_element
    writer.write_end_document
    writer.has_error?.should be_false
    buffer.close
    xml = String.new(buffer.data)
    xml.should start_with("<?xml")
    xml.should contain(%(<root version="1" lang="en">))
    xml.should contain("text &amp; more")

    buffer.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
    reader = Qt::XmlStreamReader.new(buffer)
    elements = [] of String
    attributes = [] of {String, String}
    text = ""
    until reader.at_end
      token = reader.read_next
      case token
      when Qt::XmlStreamReader::TokenType::StartElement
        elements << reader.name
        if reader.name == "root"
          attributes = reader.attributes.map { |attribute| {attribute.name, attribute.value} }
          reader.attributes.value("version").should eq("1")
          reader.attributes.has_attribute("lang").should be_true
          reader.attributes.size.should eq(2)
        elsif reader.name == "child"
          text = reader.read_element_text
        end
      when Qt::XmlStreamReader::TokenType::Comment
        reader.text.should eq("note")
      end
    end
    reader.has_error?.should be_false
    elements.should eq(["root", "child", "empty"])
    attributes.should eq([{"version", "1"}, {"lang", "en"}])
    text.should eq("text & more")

    broken = Qt::XmlStreamReader.new("<a><b></a>")
    broken.read_next.should eq(Qt::XmlStreamReader::TokenType::StartDocument)
    until broken.at_end
      broken.read_next
    end
    broken.has_error?.should be_true
    broken.error.should eq(Qt::XmlStreamReader::Error::NotWellFormedError)
    broken.error_string.should_not be_empty
  end
end

describe Qt::DataStream do
  it "writes numbers and strings to a buffer and reads them back" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
    stream = Qt::DataStream.new(buffer)
    stream.version = Qt::DataStream::Version::Qt_6_0.to_i
    stream.byte_order = Qt::DataStream::ByteOrder::BigEndian
    stream << 42 << -7_i64 << 2.5 << true << "héllo" << Bytes[1, 2, 3]
    stream << Qt::Point.new(3, 4)
    stream << Qt::Date.new(2024, 2, 29)
    stream.status.should eq(Qt::DataStream::Status::Ok)
    buffer.close
    buffer.data.size.should be > 20

    buffer.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
    reader = Qt::DataStream.new(buffer)
    reader.version = Qt::DataStream::Version::Qt_6_0.to_i
    reader.read(Int32).should eq(42)
    reader.read(Int64).should eq(-7)
    reader.read(Float64).should eq(2.5)
    reader.read(Bool).should be_true
    reader.read(String).should eq("héllo")
    reader.read(Bytes).should eq(Bytes[1, 2, 3])
    reader.skip_raw_data(8).should eq(8) # The point: `>> Point` takes it by non-const reference
    date = Qt::Date.new
    reader >> date
    date.should eq(Qt::Date.new(2024, 2, 29))
    reader.at_end.should be_true
    reader.read(Int32).should eq(0)
    reader.status.should eq(Qt::DataStream::Status::ReadPastEnd)

    from_bytes = Qt::DataStream.new(Bytes[0, 0, 0, 5])
    from_bytes.read(Int32).should eq(5)
  end
end

describe Qt::BitArray do
  it "holds bits" do
    bits = Qt::BitArray.new(8)
    bits.size.should eq(8)
    bits.count(true).should eq(0)
    bits.set_bit(1, true)
    bits.set_bit(6, true)
    bits.test_bit(1).should be_true
    bits.test_bit(2).should be_false
    bits.at(6).should be_true
    bits.count(true).should eq(2)
    bits.toggle_bit(1).should be_true
    bits.test_bit(1).should be_false
    bits.clear_bit(6)
    bits.count(true).should eq(0)
    bits.fill(true)
    bits.count(true).should eq(8)
    other = Qt::BitArray.new(8, false)
    other.set_bit(0, true)
    (bits & other).count(true).should eq(1)
    (bits ^ other).count(true).should eq(7)
    bits.resize(4)
    bits.size.should eq(4)
    Qt::BitArray.new.empty?.should be_true
  end

  it "reads the process environment" do
    environment = Qt::ProcessEnvironment.system_environment
    environment.empty?.should be_false
    environment.contains("PATH").should be_true
    environment.value("PATH").should contain("/")
    environment.keys.to_a.should contain("PATH")
    environment.to_string_list.to_a.any?(&.starts_with?("PATH=")).should be_true
    own = Qt::ProcessEnvironment.new
    own.insert("QT6CR", "spec")
    own.value("QT6CR").should eq("spec")
    own.value("NOPE", "default").should eq("default")
    own.remove("QT6CR")
    own.contains("QT6CR").should be_false
  end

  it "describes calendars, storage and more" do
    calendar = Qt::Calendar.new
    calendar.gregorian?.should be_true
    calendar.name.should eq("Gregorian")
    calendar.days_in_month(2, 2024).should eq(29)
    calendar.is_leap_year(2023).should be_false
    parts = calendar.parts_from_date(Qt::Date.new(2024, 2, 29))
    parts.valid?.should be_true
    {parts.year, parts.month, parts.day}.should eq({2024, 2, 29})
    calendar.date_from_parts(2024, 3, 1).day_of_year.should eq(61)
    Qt::Calendar.available_calendars.to_a.should contain("Gregorian")
    Qt::Calendar.new(Qt::Calendar::System::Julian).days_in_month(2, 1900).should eq(29)
    calendar.month_name(Qt::Locale.new("en_US"), 2).should eq("February")

    storage = Qt::StorageInfo.root
    storage.valid?.should be_true
    storage.ready?.should be_true
    storage.root?.should be_true
    storage.bytes_total.should be > 0
    storage.root_path.should eq("/")
    Qt::StorageInfo.mounted_volumes.to_a.should_not be_empty
    Qt::StorageInfo.new(Qt::Dir.temp_path).valid?.should be_true

    name = "qt6cr.spec"
    category = Qt::LoggingCategory.new(name.to_unsafe)
    String.new(category.category_name).should eq(name)
    category.debug_enabled?.should be_true
    category.set_enabled(Qt::MsgType::QtDebugMsg, false)
    category.is_enabled(Qt::MsgType::QtDebugMsg).should be_false
    Qt::LoggingCategory.default_category.not_nil!.category_name.null?.should be_false

    mac = Qt::MessageAuthenticationCode.hash("message".to_slice, "key".to_slice, Qt::CryptographicHash::Algorithm::Sha256)
    mac.hexstring.should eq(OpenSSL::HMAC.hexdigest(:sha256, "key", "message"))
    code = Qt::MessageAuthenticationCode.new(Qt::CryptographicHash::Algorithm::Sha256, "key".to_slice)
    code.add_data("mess".to_slice)
    code.add_data("age".to_slice)
    code.result.should eq(mac)

    Qt::Library.new("no such library").load.should be_false
    Qt::Library.is_library("foo.dylib").should be_true
    Qt::Library.is_library("foo.txt").should be_false
    Qt::Resource.new(":/no/such/resource").valid?.should be_false
    selector = Qt::FileSelector.new
    selector.all_selectors.to_a.should_not be_empty
    selector.select("/no/such/file").should eq("/no/such/file")

    matches = Qt::RegularExpression.new("\\d+").global_match("a1b22c333")
    matches.valid?.should be_true
    matches.has_next?.should be_true
    matches.map(&.captured).to_a.should eq(["1", "22", "333"])
  end
end

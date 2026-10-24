require "../spec_helper"

# The `const char *` names of the meta-object system are `UInt8*`, read with
# `String.new`.
describe Qt::MetaObject do
  it "describes a class" do
    button = Qt::PushButton.new("ok")
    meta = button.meta_object.not_nil!
    String.new(meta.class_name).should eq("QPushButton")
    String.new(meta.super_class.not_nil!.class_name).should eq("QAbstractButton")
    # `static_meta_object` is a copy of the class's QMetaObject, which
    # `inherits` doesn't compare equal to the one an object refers to.
    widget_meta = Qt::Widget.new.meta_object.not_nil!
    meta.inherits(widget_meta).should be_true
    widget_meta.inherits(meta).should be_false
    String.new(Qt::Widget.static_meta_object.class_name).should eq("QWidget")
    meta.property_count.should be > meta.property_offset
    meta.method_count.should be > 0
    String.new(Qt::MetaObject.normalized_signature("clicked( bool )".to_unsafe)).should eq("clicked(bool)")
    String.new(Qt::MetaObject.normalized_type("const QString &".to_unsafe)).should eq("QString")
  end

  it "reads and writes properties" do
    button = Qt::PushButton.new("ok")
    meta = button.meta_object.not_nil!
    index = meta.index_of_property("text".to_unsafe)
    index.should be >= 0
    property = meta.property(index)
    property.valid?.should be_true
    String.new(property.name).should eq("text")
    String.new(property.type_name).should eq("QString")
    property.meta_type.id.should eq(Qt::MetaType::Type::QString.to_i)
    property.readable?.should be_true
    property.writable?.should be_true
    property.read(button).to(String).should eq("ok")
    property.write(button, Qt.variant("changed")).should be_true
    button.text.should eq("changed")
    String.new(meta.user_property.name).should eq("checked")
    meta.index_of_property("nope".to_unsafe).should eq(-1)
  end

  it "lists methods and invokes them" do
    button = Qt::PushButton.new("ok")
    meta = button.meta_object.not_nil!
    index = meta.index_of_signal("clicked(bool)".to_unsafe)
    index.should be >= 0
    method = meta.method(index)
    method.method_type.should eq(Qt::MetaMethod::MethodType::Signal)
    method.access.should eq(Qt::MetaMethod::Access::Public)
    String.new(method.name).should eq("clicked")
    String.new(method.method_signature).should eq("clicked(bool)")
    method.parameter_count.should eq(1)
    String.new(method.parameter_type_name(0)).should eq("bool")
    method.parameter_names.map { |n| String.new(n) }.should eq(["checked"])
    method.return_meta_type.id.should eq(Qt::MetaType::Type::Void.to_i)
    String.new(method.enclosing_meta_object.not_nil!.class_name).should eq("QAbstractButton")
    meta.method(meta.index_of_slot("click()".to_unsafe)).method_type.should eq(Qt::MetaMethod::MethodType::Slot)
    meta.index_of_method("nope()".to_unsafe).should eq(-1)

    clicked = false
    button.on_clicked { clicked = true }
    Qt::MetaObject.invoke_method(button, "click").should be_true
    clicked.should be_true
    Qt::MetaObject.invoke_method(button, "nope").should be_false
  end

  it "describes enums" do
    meta = Qt::Frame.static_meta_object
    index = meta.index_of_enumerator("Shape".to_unsafe)
    index.should be >= 0
    shape = meta.enumerator(index)
    shape.valid?.should be_true
    String.new(shape.name).should eq("Shape")
    String.new(shape.scope).should eq("QFrame")
    shape.flag?.should be_false
    shape.key_count.should eq(Qt::Frame::Shape.values.size)
    shape.key_to_value("Box".to_unsafe).should eq({Qt::Frame::Shape::Box.to_i, true}) # With the `bool *ok`
    # Qt 6.9 replaced valueToKey(int) with valueToKey(quint64).
    panel = {% if Qt::QT_VERSION >= 0x060900 %} Qt::Frame::Shape::Panel.to_u64 {% else %} Qt::Frame::Shape::Panel.to_i {% end %}
    String.new(shape.value_to_key(panel)).should eq("Panel")
    (0...shape.key_count).map { |i| String.new(shape.key(i)) }.should contain("NoFrame")
    meta.class_info_count.should eq(0)
  end
end

describe Qt::MetaType do
  it "describes types" do
    int = Qt::MetaType.new(Qt::MetaType::Type::Int.to_i)
    int.valid?.should be_true
    String.new(int.name).should eq("int")
    int.size_of.should eq(4)
    int.flags.should_not eq(Qt::MetaType::TypeFlags::None)
    {% if Qt::QT_VERSION >= 0x060500 %}
      int.default_constructible?.should be_true
    {% end %}
    string = Qt::MetaType.from_name("QString".to_slice)
    string.id.should eq(Qt::MetaType::Type::QString.to_i)
    (int == string).should be_false
    Qt::MetaType.can_convert(int, string).should be_true
    Qt::MetaType.from_name("NoSuchType".to_slice).valid?.should be_false
    Qt::MetaType.new.valid?.should be_false
    String.new(Qt::MetaType.new(Qt::MetaType::Type::QObjectStar.to_i).meta_object.not_nil!.class_name).should eq("QObject")
  end
end

describe Qt::ObjectCleanupHandler do
  it "deletes the objects it holds" do
    handler = Qt::ObjectCleanupHandler.new
    handler.empty?.should be_true
    object = Qt::Object.new
    handler.add(object).should eq(object)
    handler.empty?.should be_false
    handler.remove(object)
    handler.empty?.should be_true
    handler.add(Qt::Object.new)
    handler.clear
    handler.empty?.should be_true
  end
end

describe Qt::ByteArrayMatcher do
  it "finds a pattern" do
    matcher = Qt::ByteArrayMatcher.new("needle".to_slice)
    String.new(matcher.pattern).should eq("needle")
    matcher.index_in("hay needle stack".to_slice).should eq(4)
    matcher.index_in("hay".to_slice).should eq(-1)
    matcher.index_in("needle needle".to_slice, 1).should eq(7)
  end
end

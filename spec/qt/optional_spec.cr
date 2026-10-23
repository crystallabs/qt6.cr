require "../spec_helper"

# `std::optional<T>` converts to and from a `T?`, see config/containers.yml.
describe "std::optional" do
  it "returns the value or nil" do
    combo = Qt::FontComboBox.new
    typeof(combo.display_font("Sans")).should eq(Qt::Font?)
    combo.set_display_font("Sans", Qt::Font.new("Sans", 12))
    combo.display_font("Sans").try(&.point_size).should eq(12)

    {% if Qt::QT_VERSION >= 0x060700 %}
      Qt::FontTag.from_string("liga").try(&.to_string).should eq("liga".to_slice)
      Qt::FontTag.from_string("too long").should be_nil
      Qt::FontTag.from_value(0_u32).should be_nil
    {% end %}
  end

  it "takes the value or nil" do
    dir = Qt::Dir.new(Qt::Dir.temp_path)
    name = "qt6cr-optional-#{Process.pid}"
    dir.mkdir(name, nil).should be_true
    dir.rmdir(name).should be_true
    owner = Qt::FileDevice::Permissions.flags(ReadOwner, WriteOwner, ExeOwner)
    dir.mkdir(name, owner).should be_true
    dir.rmdir(name).should be_true
  end
end

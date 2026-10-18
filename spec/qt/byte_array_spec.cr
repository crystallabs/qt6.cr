require "../spec_helper"

# `QByteArray` maps to `Bytes`, copied in both directions.
describe "QByteArray" do
  it "is returned from Qt" do
    process = Qt::Process.new
    process.start("sh", ["-c", "printf hi; printf err >&2"])
    process.wait_for_finished(5000).should be_true
    process.exit_code.should eq(0)
    String.new(process.read_all_standard_output).should eq("hi")
    String.new(process.read_all_standard_error).should eq("err")
    process.read_all_standard_output.should eq(Bytes.empty)
  end

  it "is passed to and returned from Qt" do
    data = Bytes[0, 1, 2, 255, 128, 0, 7]
    mime = Qt::MimeData.new
    mime.set_data("application/x-spec", data)
    mime.has_format("application/x-spec").should be_true
    mime.data("application/x-spec").should eq(data)
    mime.data("application/x-spec").should_not be(data) # A copy
    mime.data("text/plain").should eq(Bytes.empty)
    mime.set_data("text/plain", "text".to_slice)
    mime.text.should eq("text")
  end

  it "is listed in a QList<QByteArray>" do
    object = Qt::Object.new
    object.set_property("spec".to_unsafe, Qt.variant(1))
    object.dynamic_property_names.map { |name| String.new(name) }.should eq(["spec"])
  end
end

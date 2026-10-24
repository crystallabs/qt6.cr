require "../spec_helper"

# Qt keeps the function a `std::function` argument is wrapped in, and the block
# it calls must stay alive meanwhile.
private def set_provider(doc : Qt::TextDocument)
  prefix = "provided " + "by a closure "
  doc.resource_provider = ->(url : Qt::Url) { Qt::Variant.new(prefix + url.to_string) }
end

private def query(doc : Qt::TextDocument, name : String) : String
  doc.resource(Qt::TextDocument::ResourceType::UserResource.value.to_i, Qt::Url.new(name)).to(String)
end

describe "std::function arguments" do
  it "calls the Proc given to a setter" do
    doc = Qt::TextDocument.new
    doc.resource_provider = ->(url : Qt::Url) { Qt::Variant.new("provided " + url.to_string) }
    query(doc, "test://x").should eq "provided test://x"
  end

  it "keeps the closure alive in Qt" do
    doc = Qt::TextDocument.new
    set_provider(doc)
    5.times { GC.collect; Array.new(1000) { |i| "garbage #{i}" } }
    query(doc, "test://y").should eq "provided by a closure test://y"
  end
end

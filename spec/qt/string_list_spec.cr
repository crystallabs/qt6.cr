require "../spec_helper"

# `QStringList` is a `QList<QString>`, wrapped as `Qt::StringList`: methods
# taking one accept any `Enumerable(String)`.
describe "QStringList" do
  it "is passed to Qt" do
    combo = Qt::ComboBox.new
    combo.add_items(["one", "two", "three"])
    combo.count.should eq(3)
    combo.item_text(2).should eq("three")

    list = Qt::ListWidget.new
    list.add_items({"a", "b"})
    list.count.should eq(2)
    list.item(1).text.should eq("b")
  end

  it "is returned from Qt" do
    root = File.join(Qt::Dir.temp_path, "qt6cr-string-list-#{Process.pid}")
    Dir.mkdir(root)
    begin
      %w[b.txt a.txt c.log].each { |name| File.touch(File.join(root, name)) }
      dir = Qt::Dir.new(root)
      names = dir.entry_list(["*.txt"], Qt::Dir::Filters::Files, Qt::Dir::SortFlags::Name)
      names.to_a.should eq(["a.txt", "b.txt"])
      dir.entry_list(Qt::Dir::Filters::Files).to_a.sort.should eq(["a.txt", "b.txt", "c.log"])
      dir.name_filters = ["*.log"]
      dir.name_filters.to_a.should eq(["*.log"])
    ensure
      Qt::Dir.new(root).remove_recursively
    end

    match = Qt::RegularExpression.new("(\\d+)-(\\d+)").match("10-20")
    match.captured_texts.to_a.should eq(["10-20", "10", "20"])
  end

  it "builds wrapped lists directly" do
    list = Qt::QList.of(String).from(["x", "y"])
    list.size.should eq(2)
    list << "z"
    list.to_a.should eq(["x", "y", "z"])
    list.join(", ").should eq("x, y, z")
    list[2].should eq("z")
    expect_raises(IndexError) { list[3] } # Indexable#[], not Qt's unchecked one
  end

  it "has the QStringList methods" do
    list = Qt::StringList.from(["Banana", "apple", "cherry", "apple"])
    list.should be_a(Qt::QList(String))
    list.remove_duplicates.should eq(1)
    list.to_a.should eq(["Banana", "apple", "cherry"])
    list.sort(Qt::CaseSensitivity::CaseInsensitive) # In place
    list.to_a.should eq(["apple", "Banana", "cherry"])
    list.sort # Qt's too: `Enumerable` has no `sort`
    list.to_a.should eq(["Banana", "apple", "cherry"])

    list.filter("an").to_a.should eq(["Banana"])
    list.filter("AN", Qt::CaseSensitivity::CaseInsensitive).to_a.should eq(["Banana"])
    list.filter(Qt::RegularExpression.new("^.herry$")).to_a.should eq(["cherry"])
    list.contains("APPLE", Qt::CaseSensitivity::CaseInsensitive).should be_true
    list.contains("APPLE").should be_false
    list.index_of("cherry").should eq(2)
    list.index_of(Qt::RegularExpression.new("B.*")).should eq(0) # Whole strings match
    list.index_of(Qt::RegularExpression.new("B.*"), 1).should eq(-1)
    list.last_index_of(Qt::RegularExpression.new(".*e.*")).should eq(2)
    list.last_index_of(Qt::RegularExpression.new(".*e.*"), 1).should eq(1)

    list.replace_in_strings("a", "4")
    list.to_a.should eq(["B4n4n4", "4pple", "cherry"])
    list.replace_in_strings(Qt::RegularExpression.new("(\\d)"), "<\\1>")
    list.to_a.should eq(["B<4>n<4>n<4>", "<4>pple", "cherry"])
    list.join("+").should eq("B<4>n<4>n<4>+<4>pple+cherry")
  end

  it "passes program arguments to a process" do
    process = Qt::Process.new
    process.start("sh", ["-c", "exit 3"])
    process.wait_for_finished.should be_true
    process.exit_code.should eq(3)
  end
end

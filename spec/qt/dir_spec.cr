require "../spec_helper"

describe Qt::Dir do
  it "creates and removes directories" do
    root = File.join(Qt::Dir.temp_path, "qt6cr-spec-#{Process.pid}")
    dir = Qt::Dir.new(root)
    dir.exists.should be_false
    dir.mkpath(".").should be_true
    dir.exists.should be_true

    dir.mkdir("child").should be_true
    dir.exists("child").should be_true
    File.directory?(File.join(root, "child")).should be_true
    dir.rmdir("child").should be_true
    dir.exists("child").should be_false

    dir.mkpath("a/b/c").should be_true
    dir.remove_recursively.should be_true
    Dir.exists?(root).should be_false
  end

  it "resolves paths" do
    Qt::Dir.clean_path("/a/b/../c/./d").should eq("/a/c/d")
    Qt::Dir.is_absolute_path("/tmp").should be_true
    Qt::Dir.new("/tmp").absolute_file_path("x").should eq("/tmp/x")
    Qt::Dir.home_path.should eq(Qt::Dir.home.path)
  end
end

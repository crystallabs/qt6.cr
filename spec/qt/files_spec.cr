require "../spec_helper"

private def temp_path(name)
  File.join(Qt::Dir.temp_path, "qt6cr-files-#{Process.pid}-#{name}")
end

describe Qt::File do
  it "writes and reads bytes" do
    path = temp_path("file.txt")
    begin
      file = Qt::File.new(path)
      file.exists.should be_false
      file.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
      file.write("hello\nworld\n".to_slice).should eq(12)
      file.close
      file.exists.should be_true
      file.size.should eq(12)

      file.open(Qt::IODevice::OpenMode::ReadOnly).should be_true
      String.new(file.read_line).should eq("hello\n")
      String.new(file.read_all).should eq("world\n")
      file.at_end.should be_true
      file.close

      Qt::File.exists(path).should be_true
      Qt::File.remove(path).should be_true
      Qt::File.exists(path).should be_false
    ensure
      File.delete?(path)
    end
  end
end

describe Qt::FileInfo do
  it "describes a file" do
    path = temp_path("info.txt")
    begin
      File.write(path, "12345")
      info = Qt::FileInfo.new(path)
      info.exists.should be_true
      info.file?.should be_true
      info.dir?.should be_false
      info.size.should eq(5)
      info.file_name.should eq(File.basename(path))
      info.suffix.should eq("txt")
      info.base_name.should eq(File.basename(path, ".txt"))
      info.path.should eq(Qt::Dir.temp_path)
      info.dir.path.should eq(Qt::Dir.temp_path)
      info.absolute?.should be_true
      info.readable?.should be_true
      info.permission(Qt::FileDevice::Permissions::ReadOwner).should be_true
      info.last_modified.valid?.should be_true
      Qt::FileInfo.new(Qt::Dir.temp_path).dir?.should be_true
      Qt::FileInfo.exists(temp_path("missing")).should be_false
    ensure
      File.delete?(path)
    end
  end
end

describe Qt::TemporaryFile do
  it "creates a file that is removed again" do
    tmp = Qt::TemporaryFile.new(temp_path("XXXXXX"))
    tmp.auto_remove.should be_true
    tmp.open.should be_true
    name = tmp.file_name
    name.should start_with(temp_path(""))
    File.exists?(name).should be_true
    tmp.write("temp".to_slice).should eq(4)
    tmp.close
    File.read(name).should eq("temp")
    tmp.remove.should be_true
    File.exists?(name).should be_false
  end
end

describe Qt::TemporaryDir do
  it "creates and cleans up a directory" do
    dir = Qt::TemporaryDir.new(temp_path("dir-XXXXXX"))
    dir.valid?.should be_true
    dir.auto_remove.should be_true
    Dir.exists?(dir.path).should be_true
    File.write(dir.file_path("child.txt"), "x")
    File.exists?(File.join(dir.path, "child.txt")).should be_true
    dir.remove.should be_true
    Dir.exists?(dir.path).should be_false
  end
end

describe Qt::SaveFile do
  it "commits atomically" do
    path = temp_path("save.txt")
    begin
      save = Qt::SaveFile.new(path)
      save.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
      save.write("saved".to_slice).should eq(5)
      File.exists?(path).should be_false
      save.commit.should be_true
      File.read(path).should eq("saved")

      save = Qt::SaveFile.new(path)
      save.open(Qt::IODevice::OpenMode::WriteOnly).should be_true
      save.write("discarded".to_slice)
      save.cancel_writing
      save.commit.should be_false
      File.read(path).should eq("saved")
    ensure
      File.delete?(path)
    end
  end
end

describe Qt::TextStream do
  it "formats text over a buffer" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::ReadWrite).should be_true
    stream = Qt::TextStream.new(buffer)
    stream << "answer: " << 42 << ' ' << 1.5 << "\n"
    stream.flush
    String.new(buffer.data).should eq("answer: 42 1.5\n")
    buffer.size.should eq(15)

    stream.seek(0).should be_true
    stream.read_line.should eq("answer: 42 1.5")
    stream.at_end.should be_true
    stream.status.should eq(Qt::TextStream::Status::Ok)

    stream.seek(0)
    stream.field_width = 10
    stream.field_alignment = Qt::TextStream::FieldAlignment::AlignRight
    stream.integer_base = 16
    stream << 255
    stream.flush
    String.new(buffer.data).should start_with("        ff")
  end

  it "reads from bytes" do
    stream = Qt::TextStream.new("one two\nthree".to_slice)
    stream.read_line.should eq("one two")
    stream.read_all.should eq("three")
  end
end

describe Qt::DirIterator do
  it "walks a directory" do
    dir = Qt::TemporaryDir.new(temp_path("iter-XXXXXX"))
    begin
      %w[a.txt b.txt c.log].each { |name| File.write(dir.file_path(name), name) }
      Dir.mkdir(dir.file_path("sub"))
      File.write(dir.file_path("sub/d.txt"), "d")

      names = [] of String
      iterator = Qt::DirIterator.new(dir.path, ["*.txt"])
      while iterator.has_next?
        iterator.next
        names << iterator.file_name
      end
      names.sort.should eq(%w[a.txt b.txt])

      iterator = Qt::DirIterator.new(dir.path, ["*.txt"], Qt::Dir::Filters::Files, Qt::DirIterator::IteratorFlags::Subdirectories)
      infos = [] of Qt::FileInfo
      while iterator.has_next?
        infos << iterator.next_file_info
      end
      infos.map(&.file_name).sort.should eq(%w[a.txt b.txt d.txt])
      infos.all?(&.file?).should be_true
    ensure
      dir.remove
    end
  end
end

describe Qt::LockFile do
  it "locks a file" do
    dir = Qt::TemporaryDir.new(temp_path("lock-XXXXXX"))
    begin
      path = dir.file_path("spec.lock")
      lock = Qt::LockFile.new(path)
      lock.file_name.should eq(path)
      lock.locked?.should be_false
      lock.lock.should be_true
      lock.locked?.should be_true
      File.exists?(path).should be_true

      other = Qt::LockFile.new(path)
      other.try_lock(10).should be_false
      other.error.should eq(Qt::LockFile::LockError::LockFailedError)
      lock.unlock
      lock.locked?.should be_false
      other.try_lock(10.milliseconds).should be_true
      other.unlock
    ensure
      dir.remove
    end
  end
end

describe Qt::FileSystemWatcher do
  it "watches paths" do
    dir = Qt::TemporaryDir.new(temp_path("watch-XXXXXX"))
    begin
      path = dir.file_path("watched.txt")
      File.write(path, "0")
      watcher = Qt::FileSystemWatcher.new
      watcher.add_path(dir.path).should be_true
      watcher.add_paths([path]).to_a.should be_empty # Nothing failed
      watcher.directories.to_a.should eq([dir.path])
      watcher.files.to_a.should eq([path])
      watcher.remove_path(path).should be_true
      watcher.files.to_a.should be_empty
      watcher.add_path(temp_path("missing")).should be_false
    ensure
      dir.remove
    end
  end
end

describe Qt::StandardPaths do
  it "knows the standard locations" do
    temp = Qt::StandardPaths.writable_location(Qt::StandardPaths::StandardLocation::TempLocation)
    temp.should_not be_empty
    Dir.exists?(temp).should be_true
    Qt::StandardPaths.display_name(Qt::StandardPaths::StandardLocation::HomeLocation).should_not be_empty
  end
end

describe "Qt::Settings" do
  it "writes and reads an INI file" do
    path = temp_path("app.ini")
    begin
      settings = Qt::Settings.new(path, Qt::Settings::Format::IniFormat)
      settings.format.should eq(Qt::Settings::Format::IniFormat)
      settings.set_value("window/title", Qt.variant("Hello"))
      settings.sync
      settings.status.should eq(Qt::Settings::Status::NoError)
      ::File.exists?(path).should be_true
      ::File.read(path).should contain("title=Hello")
      Qt::Settings.new(path, Qt::Settings::Format::IniFormat).value("window/title").to?(String).should eq("Hello")
    ensure
      ::File.delete?(path)
    end
  end

  it "groups keys" do
    path = temp_path("groups.ini")
    begin
      settings = Qt::Settings.new(path, Qt::Settings::Format::IniFormat)
      settings.begin_group("window")
      settings.set_value("width", Qt.variant(640))
      settings.end_group
      settings.contains("window/width").should be_true
      settings.child_groups.to_a.should eq(["window"])
      settings.value("missing", Qt.variant(1)).to?(Int32).should eq(1)
      settings.remove("window")
      settings.all_keys.to_a.should be_empty
    ensure
      ::File.delete?(path)
    end
  end
end

describe Qt::TextStreamManipulator do
  it "applies a field width and a pad character" do
    buffer = Qt::Buffer.new
    buffer.open(Qt::IODevice::OpenMode::ReadWrite).should be_true
    stream = Qt::TextStream.new(buffer)
    stream << Qt.q_set_field_width(6) << Qt.q_set_pad_char('*') << 42
    stream << Qt.q_set_field_width(0) << Qt.q_set_real_number_precision(2) << ' ' << 3.14159
    stream.flush
    String.new(buffer.data).should eq("****42 3.1")
    stream.real_number_precision.should eq(2)
  end
end

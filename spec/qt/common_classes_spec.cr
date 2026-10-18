require "../spec_helper"

describe "date and time" do
  it "round-trips dates and times" do
    date = Qt::Date.new(2024, 2, 29)
    date.valid?.should be_true
    {date.year, date.month, date.day}.should eq({2024, 2, 29})
    date.add_days(1).to_string(Qt::DateFormat::Isodate).should eq("2024-03-01")
    Qt::Date.from_string("2024-12-31", Qt::DateFormat::Isodate).days_to(date).should eq(-306)
    Qt::Date.new(2023, 2, 29).valid?.should be_false

    time = Qt::Time.new(23, 59, 30)
    time.add_secs(45).to_string(Qt::DateFormat::Isodate).should eq("00:00:15")
    time.secs_to(Qt::Time.new(23, 59, 59)).should eq(29)

    date_time = Qt::DateTime.new(date, time)
    date_time.date.should eq(date)
    date_time.time.hour.should eq(23)
    date_time.add_secs(60).to_string(Qt::DateFormat::Isodate).should eq("2024-03-01T00:00:30")
    date_time.secs_to(date_time.add_days(1)).should eq(86_400)
    Qt::DateTime.current_date_time.valid?.should be_true
  end
end

describe Qt::RegularExpression do
  it "matches and captures" do
    re = Qt::RegularExpression.new("(\\w+)@(\\w+)\\.org")
    re.valid?.should be_true
    match = re.match("mail me at someone@example.org please")
    match.has_match?.should be_true
    match.captured.should eq("someone@example.org")
    match.captured(2).should eq("example")
    re.match("nothing here").has_match?.should be_false
    Qt::RegularExpression.new("(").valid?.should be_false
  end
end

describe Qt::Settings do
  it "stores values" do
    path = File.join(Qt::Dir.temp_path, "qt6cr-spec-#{Process.pid}.ini")
    begin
      settings = Qt::Settings.new(path, Qt::Settings::Format::IniFormat)
      settings.file_name.should eq(path)
      settings.set_value("window/title", Qt.variant("spec"))
      settings.set_value("window/width", Qt.variant(640))
      settings.contains("window/title").should be_true
      settings.value("window/title").to(String).should eq("spec")
      settings.value("window/width").to(Int32).should eq(640)
      settings.value("missing", Qt.variant("default")).to(String).should eq("default")
      settings.remove("window/width")
      settings.contains("window/width").should be_false

      settings.clear
      settings.sync
      settings.status.should eq(Qt::Settings::Status::NoError)
    ensure
      File.delete(path) if File.exists?(path)
    end
  end
end

describe "container widgets" do
  it "stack and split widgets" do
    stack = Qt::StackedWidget.new
    first = Qt::Label.new("first")
    second = Qt::Label.new("second")
    stack.add_widget(first).should eq(0)
    stack.add_widget(second).should eq(1)
    stack.count.should eq(2)
    stack.current_index = 1
    stack.current_widget.should eq(second)
    stack.index_of(first).should eq(0)

    splitter = Qt::Splitter.new(Qt::Orientation::Horizontal)
    splitter.add_widget(Qt::Label.new("left"))
    splitter.add_widget(Qt::Label.new("right"))
    splitter.resize(400, 100)
    splitter.show
    splitter.count.should eq(2)
    splitter.orientation.should eq(Qt::Orientation::Horizontal)
    splitter.sizes = [300, 100]
    sizes = splitter.sizes
    sizes.size.should eq(2)
    (sizes[0] > sizes[1]).should be_true
  end

  it "shows a model in a tree view" do
    model = Qt::StandardItemModel.new(2, 1)
    tree = Qt::TreeView.new
    tree.model = model
    tree.show
    tree.model.row_count.should eq(2)
    tree.current_index = model.index(1, 0)
    tree.current_index.row.should eq(1)
  end
end

describe Qt::SortFilterProxyModel do
  it "filters and sorts a source model" do
    model = Qt::StandardItemModel.new(3, 1)
    %w[banana apple cherry].each_with_index { |name, row| model.set_data(model.index(row, 0), Qt.variant(name)) }
    proxy = Qt::SortFilterProxyModel.new
    proxy.source_model = model
    proxy.row_count.should eq(3)

    proxy.sort(0)
    (0..2).map { |row| proxy.map_to_source(proxy.index(row, 0)).row }.should eq([1, 0, 2])
    (0..2).map { |row| proxy.data(proxy.index(row, 0)).to(String) }.should eq(%w[apple banana cherry])
    proxy.map_from_source(model.index(2, 0)).row.should eq(2)

    proxy.filter_regular_expression = "an"
    proxy.row_count.should eq(1)
    proxy.map_to_source(proxy.index(0, 0)).row.should eq(0)

    proxy.filter_regular_expression = Qt::RegularExpression.new("^c")
    proxy.row_count.should eq(1)
    proxy.map_to_source(proxy.index(0, 0)).row.should eq(2)
  end
end

describe Qt::MessageBox do
  it "configures its contents" do
    box = Qt::MessageBox.new(Qt::MessageBox::Icon::Warning, "title", "text")
    box.icon.should eq(Qt::MessageBox::Icon::Warning)
    box.text.should eq("text")
    box.informative_text = "more"
    box.informative_text.should eq("more")
    buttons = Qt::MessageBox::StandardButtons::Ok | Qt::MessageBox::StandardButtons::Cancel
    box.standard_buttons = buttons
    box.standard_buttons.should eq(buttons)
  end
end

describe Qt::Clipboard do
  it "holds text" do
    clipboard = Qt::Application.clipboard
    clipboard.set_text("copied")
    clipboard.text.should eq("copied")
    clipboard.clear
    clipboard.text.should eq("")
  end
end

describe Qt::VariantAnimation do
  it "runs through its states" do
    animation = Qt::VariantAnimation.new
    animation.duration = 20
    animation.duration.should eq(20)
    states = [] of Qt::AbstractAnimation::State
    animation.on_state_changed { |new_state, _old_state| states << new_state }
    loop = Qt::EventLoop.new
    finished = false
    animation.on_finished do
      finished = true
      loop.quit
    end

    animation.state.should eq(Qt::AbstractAnimation::State::Stopped)
    animation.start
    animation.state.should eq(Qt::AbstractAnimation::State::Running)
    loop.exec
    finished.should be_true
    animation.state.should eq(Qt::AbstractAnimation::State::Stopped)
    states.should eq([Qt::AbstractAnimation::State::Running, Qt::AbstractAnimation::State::Stopped])
  end

  it "holds key values as tuples" do
    animation = Qt::VariantAnimation.new
    animation.start_value = Qt.variant(0.0)
    animation.end_value = Qt.variant(10.0)
    animation.set_key_value_at(0.5, Qt.variant(2.0))
    animation.key_values.map(&.[0]).should eq([0.0, 0.5, 1.0])
    animation.key_values.map(&.[1].to(Float64)).should eq([0.0, 2.0, 10.0])
    animation.key_values = [{0.0, Qt.variant(1.0)}, {1.0, Qt.variant(3.0)}]
    animation.key_value_at(1.0).to(Float64).should eq(3.0)
  end
end

describe Qt::Process do
  it "runs a program" do
    Qt::Process.execute("true").should eq(0)

    process = Qt::Process.new
    exit_codes = [] of Int32
    process.on_finished { |code, _status| exit_codes << code }
    process.start("false")
    process.wait_for_finished.should be_true
    process.state.should eq(Qt::Process::ProcessState::NotRunning)
    process.exit_code.should eq(1)
    exit_codes.should eq([1])
  end
end

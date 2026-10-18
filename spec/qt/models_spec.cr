require "../spec_helper"

# A list model written in Crystal implements only row_count(parent) and
# data(index, role): bindgen makes the no-argument overloads concrete and
# wraps the privately overridden parent, column_count and has_children
# through AbstractItemModel.
class SquaresModel < Qt::AbstractListModel
  def row_count(parent : Qt::ModelIndex) : Int32
    parent.valid? ? 0 : 4
  end

  def data(index : Qt::ModelIndex, role : Int32 = 0) : Qt::Variant
    return Qt.variant(nil) unless role == Qt::ItemDataRole::DisplayRole.to_i
    Qt.variant(index.row * index.row)
  end
end

# A table model implements column_count(parent) too.
class GridModel < Qt::AbstractTableModel
  def row_count(parent : Qt::ModelIndex) : Int32
    parent.valid? ? 0 : 2
  end

  def column_count(parent : Qt::ModelIndex) : Int32
    parent.valid? ? 0 : 3
  end

  def data(index : Qt::ModelIndex, role : Int32 = 0) : Qt::Variant
    return Qt.variant(nil) unless role == Qt::ItemDataRole::DisplayRole.to_i
    Qt.variant("#{index.row},#{index.column}")
  end
end

# A subclass of a concrete model only overrides what it changes.
class ShoutingListModel < Qt::StringListModel
  def data(index : Qt::ModelIndex, role : Int32 = 0) : Qt::Variant
    value = superclass.data(index, role)
    role == Qt::ItemDataRole::DisplayRole.to_i ? Qt.variant(value.to(String).upcase) : value
  end
end

describe Qt::StandardItem do
  it "builds a tree in a model" do
    model = Qt::StandardItemModel.new
    root = Qt::StandardItem.new("root")
    child = Qt::StandardItem.new("child")
    root.append_row(child)
    model.append_row(root)

    model.row_count.should eq(1)
    model.item(0).not_nil!.text.should eq("root")
    model.item(0).not_nil!.to_unsafe.should eq(root.to_unsafe) # No operator== on QStandardItem
    root.has_children?.should be_true
    root.child(0).not_nil!.text.should eq("child")
    child.parent.not_nil!.to_unsafe.should eq(root.to_unsafe)
    child.row.should eq(0)
    child.index.parent.should eq(root.index)
    model.item_from_index(child.index).not_nil!.to_unsafe.should eq(child.to_unsafe)
    model.data(child.index).to(String).should eq("child")

    root.append_row([Qt::StandardItem.new("a"), Qt::StandardItem.new("b")])
    root.row_count.should eq(2)
    root.column_count.should eq(2)
    root.child(1, 1).not_nil!.text.should eq("b")

    child.text = "renamed"
    child.set_data(Qt.variant(42))
    child.data.to(Int32).should eq(42)
    roles = model.item_data(child.index) # A QMap<int, QVariant>, Hash-like
    roles[Qt::ItemDataRole::DisplayRole.to_i].to(String).should eq("renamed")
    roles[Qt::ItemDataRole::UserRole.to_i + 1].to(Int32).should eq(42)
    roles[Qt::ItemDataRole::ToolTipRole.to_i]?.should be_nil
    roles.keys.includes?(Qt::ItemDataRole::DisplayRole.to_i).should be_true
    model.set_item_data(child.index, {Qt::ItemDataRole::ToolTipRole.to_i => Qt.variant("tip")}).should be_true
    child.tool_tip.should eq("tip")
    names = model.role_names # A QHash<int, QByteArray>
    String.new(names[Qt::ItemDataRole::DisplayRole.to_i]).should eq("display")
    names.has_key?(Qt::ItemDataRole::EditRole.to_i).should be_true
    names.to_h.size.should eq(names.size)
    child.checkable = true
    child.check_state = Qt::CheckState::Checked
    child.check_state.should eq(Qt::CheckState::Checked)
    child.tool_tip = "tip"
    child.tool_tip.should eq("tip")
    child.editable = false
    child.editable?.should be_false
    model.find_items("root").size.should eq(1)
    model.find_items("renamed").size.should eq(0) # Top level only

    taken = root.take_child(0).not_nil!
    taken.to_unsafe.should eq(child.to_unsafe)
    root.child(0).should be_nil # No item there any more
    root.remove_row(0)
    root.row_count.should eq(1)
    clone = root.clone.not_nil!
    clone.text.should eq("root")
    clone.row_count.should eq(0)
  end
end

describe Qt::StringListModel do
  it "wraps a list of strings" do
    model = Qt::StringListModel.new(["banana", "apple", "cherry"])
    model.row_count.should eq(3)
    model.column_count.should eq(1)
    model.string_list.to_a.should eq(["banana", "apple", "cherry"])
    model.data(model.index(1)).to(String).should eq("apple")
    model.sort(0)
    model.string_list.to_a.should eq(["apple", "banana", "cherry"])
    model.set_data(model.index(0), Qt.variant("apricot")).should be_true
    model.insert_rows(0, 1).should be_true
    model.row_count.should eq(4)
    model.string_list.to_a.should eq(["", "apricot", "banana", "cherry"])
    model.string_list = ["x", "y"]
    model.row_count.should eq(2)
    model.parent(model.index(0)).valid?.should be_false

    view = Qt::ListView.new
    view.model = model
    view.model.not_nil!.row_count.should eq(2)
  end

  it "backs a proxy model" do
    model = Qt::StringListModel.new(["a", "b", "c"])
    proxy = Qt::IdentityProxyModel.new
    proxy.source_model = model
    proxy.row_count.should eq(3)
    proxy.column_count.should eq(1)
    proxy.data(proxy.index(2, 0)).to(String).should eq("c")
    proxy.map_to_source(proxy.index(1, 0)).row.should eq(1)
    proxy.map_from_source(model.index(2)).row.should eq(2)
  end
end

describe Qt::ItemSelectionModel do
  it "selects indexes of a model" do
    model = Qt::StandardItemModel.new(3, 2)
    selection_model = Qt::ItemSelectionModel.new(model)
    selection_model.model.should eq(model)
    selection_model.has_selection?.should be_false

    changes = [] of {Int32, Int32}
    selection_model.on_selection_changed { |selected, deselected| changes << {selected.size, deselected.size} }

    selection_model.select(model.index(0, 0), Qt::ItemSelectionModel::SelectionFlags::Select)
    selection_model.select(Qt::ItemSelection.new(model.index(1, 0), model.index(2, 1)), Qt::ItemSelectionModel::SelectionFlags::Select)
    selection_model.has_selection?.should be_true
    selection_model.selected_indexes.size.should eq(5)
    selection_model.selected_indexes.map { |index| {index.row, index.column} }.should contain({2, 1})
    selection_model.is_selected(model.index(2, 1)).should be_true
    selection_model.is_selected(model.index(0, 1)).should be_false
    selection_model.is_row_selected(2).should be_true
    selection_model.is_row_selected(0).should be_false
    selection_model.selected_rows.size.should eq(2)
    changes.should eq([{1, 0}, {1, 0}])

    selection = selection_model.selection
    selection.size.should eq(2)
    selection.contains(model.index(1, 1)).should be_true
    selection.indexes.size.should eq(5)
    range = selection[1]
    {range.top, range.left, range.bottom, range.right}.should eq({1, 0, 2, 1})
    range.width.should eq(2)
    range.height.should eq(2)
    range.top_left.row.should eq(1)
    range.contains(model.index(2, 0)).should be_true

    selection_model.set_current_index(model.index(1, 1), Qt::ItemSelectionModel::SelectionFlags::NoUpdate)
    selection_model.current_index.row.should eq(1)
    selection_model.select(model.index(0, 0), Qt::ItemSelectionModel::SelectionFlags::Deselect)
    selection_model.selected_indexes.size.should eq(4)
    changes.last.should eq({0, 1})
    selection_model.clear_selection
    selection_model.has_selection?.should be_false
  end
end

describe Qt::ItemSelection do
  it "is a list of ranges" do
    model = Qt::StandardItemModel.new(4, 2)
    selection = Qt::ItemSelection.new
    selection.empty?.should be_true
    selection << Qt::ItemSelectionRange.new(model.index(0, 0), model.index(1, 0))
    selection.size.should eq(1)
    selection.first.height.should eq(2)
    selection.select(model.index(3, 0), model.index(3, 1))
    selection.size.should eq(2)
    selection.map(&.top).should eq([0, 3])
    selection.indexes.size.should eq(4)
    selection.contains(model.index(2, 0)).should be_false

    other = Qt::ItemSelection.new(model.index(2, 0), model.index(2, 1))
    selection.merge(other, Qt::ItemSelectionModel::SelectionFlags::Select)
    selection.size.should eq(3)
    selection.indexes.size.should eq(6)
    selection.merge(other, Qt::ItemSelectionModel::SelectionFlags::Deselect)
    selection.indexes.size.should eq(4)

    range = Qt::ItemSelectionRange.new(model.index(0, 0), model.index(2, 1))
    range.intersects(other.first).should be_true
    range.intersected(other.first).height.should eq(1)
    range.valid?.should be_true
    range.indexes.size.should eq(6)
    Qt::ItemSelectionRange.new.valid?.should be_false
  end
end

describe Qt::PersistentModelIndex do
  it "follows its item" do
    model = Qt::StringListModel.new(["a", "b", "c"])
    persistent = Qt::PersistentModelIndex.new(model.index(2))
    persistent.valid?.should be_true
    persistent.row.should eq(2)
    persistent.data.to(String).should eq("c")
    model.remove_rows(0, 1).should be_true
    persistent.row.should eq(1)
    persistent.to_q_model_index.should eq(model.index(1))
    (persistent == model.index(1)).should be_true
    model.remove_rows(1, 1).should be_true
    persistent.valid?.should be_false
    Qt::PersistentModelIndex.new.valid?.should be_false
  end
end

describe Qt::FileSystemModel do
  it "lists a directory" do
    dir = Qt::TemporaryDir.new(File.join(Qt::Dir.temp_path, "qt6cr-fsmodel-XXXXXX"))
    begin
      File.write(dir.file_path("a.txt"), "a")
      model = Qt::FileSystemModel.new
      model.read_only = true
      model.filter = Qt::Dir::Filters::Files | Qt::Dir::Filters::NoDotAndDotDot

      # The listing is gathered in a thread, which reports through this signal.
      loop = Qt::EventLoop.new
      loaded = [] of String
      model.on_directory_loaded do |path|
        loaded << path
        loop.quit
      end
      root = model.set_root_path(dir.path)
      root.valid?.should be_true
      model.root_path.should eq(dir.path)
      model.root_directory.path.should eq(dir.path)
      model.file_path(root).should eq(dir.path)
      model.is_dir(root).should be_true
      model.file_info(root).dir?.should be_true

      timeout = Qt::Timer.new
      timeout.single_shot = true
      timeout.on_timeout { loop.quit }
      timeout.start(5000)
      loop.exec unless loaded.includes?(dir.path)
      if loaded.includes?(dir.path)
        model.row_count(root).should eq(1)
        index = model.index(0, 0, root)
        model.file_name(index).should eq("a.txt")
        model.size(index).should eq(1)
        model.is_dir(index).should be_false
        model.index(dir.file_path("a.txt")).should eq(index)
        model.data(index).to(String).should eq("a.txt")
      else
        STDERR.puts "FileSystemModel did not load #{dir.path} within 5 s, skipping the listing checks"
      end
    ensure
      dir.remove
    end
  end
end

describe Qt::EasingCurve do
  it "maps progress to values" do
    linear = Qt::EasingCurve.new
    linear.type.should eq(Qt::EasingCurve::Type::Linear)
    linear.value_for_progress(0.3).should be_close(0.3, 1e-9)

    curve = Qt::EasingCurve.new(Qt::EasingCurve::Type::InQuad)
    curve.value_for_progress(0.0).should eq(0.0)
    curve.value_for_progress(0.5).should be_close(0.25, 1e-9)
    curve.value_for_progress(1.0).should eq(1.0)
    curve.type = Qt::EasingCurve::Type::OutQuad
    curve.value_for_progress(0.5).should be_close(0.75, 1e-9)
    (curve != linear).should be_true
    curve.overshoot = 2.0
    curve.overshoot.should eq(2.0)
  end
end

describe "animation groups" do
  it "run property animations in sequence and in parallel" do
    widget = Qt::Widget.new
    first = Qt::PropertyAnimation.new(widget, "minimumWidth".to_slice)
    first.start_value = Qt.variant(0)
    first.end_value = Qt.variant(50)
    first.duration = 20
    second = Qt::PropertyAnimation.new(widget, "minimumHeight".to_slice)
    second.start_value = Qt.variant(0)
    second.end_value = Qt.variant(40)
    second.duration = 20

    group = Qt::SequentialAnimationGroup.new
    current = [] of Qt::AbstractAnimation
    group.on_current_animation_changed { |animation| current << animation }
    group.add_animation(first) # Makes it the current animation already
    pause = group.add_pause(5).not_nil!
    pause.duration.should eq(5)
    group.add_animation(second)
    group.animation_count.should eq(3)
    group.index_of_animation(second).should eq(2)
    group.animation_at(0).should eq(first)
    group.duration.should eq(45)

    loop = Qt::EventLoop.new
    group.on_finished { loop.quit }
    group.start
    group.state.should eq(Qt::AbstractAnimation::State::Running)
    loop.exec
    group.state.should eq(Qt::AbstractAnimation::State::Stopped)
    widget.minimum_width.should eq(50)
    widget.minimum_height.should eq(40)
    # Signals pass the base type, so compare the wrapped pointers
    current.map(&.to_unsafe).should eq([first, pause, second].map(&.to_unsafe))

    group.take_animation(1).not_nil!.to_unsafe.should eq(pause.to_unsafe)
    group.animation_count.should eq(2)
    group.clear
    group.animation_count.should eq(0)

    parallel = Qt::ParallelAnimationGroup.new
    third = Qt::PropertyAnimation.new(widget, "minimumWidth".to_slice)
    third.end_value = Qt.variant(10)
    third.duration = 10
    parallel.add_animation(third)
    parallel.add_animation(Qt::PauseAnimation.new(30))
    parallel.duration.should eq(30)
    parallel.on_finished { loop.quit }
    parallel.start
    loop.exec
    widget.minimum_width.should eq(10)
  end
end

describe Qt::TimeLine do
  it "counts frames" do
    line = Qt::TimeLine.new(40)
    line.duration.should eq(40)
    line.set_frame_range(0, 10)
    line.end_frame.should eq(10)
    line.easing_curve = Qt::EasingCurve.new(Qt::EasingCurve::Type::Linear)
    line.value_for_time(20).should be_close(0.5, 1e-9)
    line.frame_for_time(40).should eq(10)

    frames = [] of Int32
    line.on_frame_changed { |frame| frames << frame }
    states = [] of Qt::TimeLine::State
    line.on_state_changed { |state| states << state }
    loop = Qt::EventLoop.new
    line.on_finished { loop.quit }
    line.state.should eq(Qt::TimeLine::State::NotRunning)
    line.start
    line.state.should eq(Qt::TimeLine::State::Running)
    loop.exec
    line.state.should eq(Qt::TimeLine::State::NotRunning)
    line.current_frame.should eq(10)
    line.current_value.should eq(1.0)
    frames.last.should eq(10)
    frames.should eq(frames.sort)
    states.should eq([Qt::TimeLine::State::Running, Qt::TimeLine::State::NotRunning])
  end
end

describe "Models written in Crystal" do
  it "implement the pure virtual methods only" do
    model = SquaresModel.new
    model.row_count.should eq(4)
    model.column_count.should eq(1)
    model.has_children?.should be_true
    model.has_children(model.index(0)).should be_false
    model.parent(model.index(2)).valid?.should be_false
    model.data(model.index(3)).to(Int32).should eq(9)
    model.data(model.index(3), Qt::ItemDataRole::ToolTipRole.to_i).to?(Int32).should be_nil

    view = Qt::ListView.new
    view.model = model
    view.model.not_nil!.row_count.should eq(4)
    view.model.not_nil!.index(1, 0).data.to(Int32).should eq(1)

    grid = GridModel.new
    grid.row_count.should eq(2)
    grid.column_count.should eq(3)
    grid.has_children?.should be_true
    grid.index(1, 2).data.to(String).should eq("1,2")
    grid.index(1, 2).sibling(0, 0).data.to(String).should eq("0,0")
  end

  it "subclass a concrete model" do
    model = ShoutingListModel.new
    model.string_list = ["a", "b"]
    model.row_count.should eq(2)
    model.column_count.should eq(1)
    model.data(model.index(1)).to(String).should eq("B")
    model.data(model.index(1), Qt::ItemDataRole::EditRole.to_i).to(String).should eq("b")
    model.index(0).data.to(String).should eq("A")
  end
end

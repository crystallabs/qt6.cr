require "../spec_helper"

describe "item models" do
  it "store data in a standard item model" do
    model = Qt::StandardItemModel.new(2, 3)
    model.row_count.should eq(2)
    model.column_count.should eq(3)

    index = model.index(1, 2)
    index.valid?.should be_true
    model.set_data(index, Qt.variant("cell")).should be_true
    model.data(index).to(String).should eq("cell")
    model.set_data(model.index(0, 0), Qt.variant(42)).should be_true
    model.data(model.index(0, 0)).to(Int32).should eq(42)

    changes = [] of Int32
    model.on_data_changed(Qt::ModelIndex, Qt::ModelIndex) { |top_left, _bottom_right| changes << top_left.row }
    model.set_data(model.index(1, 0), Qt.variant("again"))
    changes.should eq([1])

    model.insert_rows(0, 2).should be_true
    model.row_count.should eq(4)
    model.remove_rows(0, 3).should be_true
    model.row_count.should eq(1)
  end

  it "show a model in a view" do
    model = Qt::StandardItemModel.new(3, 1)
    view = Qt::ListView.new
    view.model = model
    view.show
    view.model.row_count.should eq(3)
    view.current_index = model.index(2, 0)
    view.current_index.row.should eq(2)
  end

  it "fill a table widget" do
    table = Qt::TableWidget.new(2, 2)
    table.set_item(0, 0, Qt::TableWidgetItem.new("top left"))
    table.set_item(1, 1, Qt::TableWidgetItem.new("bottom right"))
    table.row_count.should eq(2)
    table.item(0, 0).text.should eq("top left")
    table.item(1, 1).text.should eq("bottom right")
    table.set_current_cell(1, 1)
    table.current_item.text.should eq("bottom right")
  end
end

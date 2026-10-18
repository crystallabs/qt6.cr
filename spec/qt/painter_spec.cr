require "../spec_helper"

describe "painting" do
  it "draws into an image" do
    image = Qt::Image.new(8, 8, Qt::Image::Format::Argb32)
    image.fill(Qt::Color.new(255, 255, 255))

    painter = Qt::Painter.new(image)
    painter.fill_rect(Qt::Rect.new(0, 0, 4, 4), Qt::Color.new(255, 0, 0))
    painter.pen = Qt::Pen.new(Qt::Color.new(0, 0, 255))
    painter.draw_line(0, 7, 7, 7)
    painter.end

    image.pixel_color(1, 1).name.should eq("#ff0000")
    image.pixel_color(6, 1).name.should eq("#ffffff")
    image.pixel_color(3, 7).name.should eq("#0000ff")
  end

  it "converts colors" do
    color = Qt::Color.new("#102030")
    color.valid?.should be_true
    {color.red, color.green, color.blue}.should eq({0x10, 0x20, 0x30})
    color.alpha.should eq(255)
    color.rgb.should eq(0xff102030_u32)
    Qt::Color.new(Qt::GlobalColor::Red).name.should eq("#ff0000")
    Qt::Color.new("no such color").valid?.should be_false
  end

  it "describes fonts" do
    font = Qt::Font.new("Serif", 12)
    font.family.should eq("Serif")
    font.point_size.should eq(12)
    font.bold = true
    font.bold.should be_true
  end
end

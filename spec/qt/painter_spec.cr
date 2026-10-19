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

  it "draws polygons, which are lists of points" do
    polygon = Qt::Polygon.new
    polygon << Qt::Point.new(1, 1)
    polygon << Qt::Point.new(6, 1)
    polygon << Qt::Point.new(6, 6)
    polygon.size.should eq(3)
    polygon.to_a.should eq([Qt::Point.new(1, 1), Qt::Point.new(6, 1), Qt::Point.new(6, 6)])
    polygon.bounding_rect.should eq(Qt::Rect.new(1, 1, 6, 6))
    Qt::Polygon.new([Qt::Point.new(1, 1), Qt::Point.new(6, 1), Qt::Point.new(6, 6)]).to_a.should eq(polygon.to_a)

    image = Qt::Image.new(8, 8, Qt::Image::Format::Argb32)
    image.fill(Qt::Color.new(255, 255, 255))
    painter = Qt::Painter.new(image)
    painter.pen = Qt::Color.new(255, 0, 0)
    painter.brush = Qt::Brush.new(Qt::Color.new(255, 0, 0))
    painter.draw_polygon(polygon)
    painter.end
    image.pixel_color(5, 2).name.should eq("#ff0000") # Inside the triangle
    image.pixel_color(2, 5).name.should eq("#ffffff") # Outside

    polygon_f = Qt::PolygonF.new([Qt::PointF.new(1.0, 1.0), Qt::PointF.new(6.0, 1.0)])
    polygon_f << Qt::PointF.new(6.0, 6.0)
    polygon_f.size.should eq(3)
    polygon_f.to_a.last.should eq(Qt::PointF.new(6.0, 6.0))
    polygon_f.bounding_rect.should eq(Qt::RectF.new(1.0, 1.0, 5.0, 5.0))
    polygon_f.to_polygon.to_a.should eq(polygon.to_a)

    image.fill(Qt::Color.new(255, 255, 255))
    painter = Qt::Painter.new(image)
    painter.pen = Qt::Color.new(0, 0, 255)
    painter.brush = Qt::Brush.new(Qt::Color.new(0, 0, 255))
    painter.draw_polygon(polygon_f)
    painter.end
    image.pixel_color(5, 2).name.should eq("#0000ff")
    image.pixel_color(2, 5).name.should eq("#ffffff")
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

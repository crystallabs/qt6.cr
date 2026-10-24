require "../spec_helper"

# `QMatrix3x3` and friends are typedefs of `QGenericMatrix<N, M, float>`.
describe "QGenericMatrix typedefs" do
  it "starts as an identity" do
    Qt::Matrix3x3.new.identity?.should be_true
    Qt::Matrix2x2.new.identity?.should be_true
  end

  it "gives access to elements" do
    m = Qt::Matrix3x3.new
    m.call(1, 1).value.should eq 1.0_f32
    m.call(0, 1).value.should eq 0.0_f32
    m.call(0, 1).value = 5.0_f32
    m.call(0, 1).value.should eq 5.0_f32
    m.identity?.should be_false
  end

  it "supports arithmetic and comparison" do
    m = Qt::Matrix3x3.new
    m.fill(2.0_f32)
    m.mul!(3.0_f32)
    m.const_data[8].should eq 6.0_f32
    n = Qt::Matrix3x3.new
    n.fill(6.0_f32)
    (m == n).should be_true
    (m != Qt::Matrix3x3.new).should be_true
  end

  it "is returned by Matrix4x4#normal_matrix" do
    Qt::Matrix4x4.new.normal_matrix.identity?.should be_true
  end

  it "is returned by Quaternion#to_rotation_matrix" do
    Qt::Quaternion.new.to_rotation_matrix.identity?.should be_true
  end
end

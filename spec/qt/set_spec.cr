require "../spec_helper"

# `QSet<T>` is wrapped as an `Enumerable(T)`.  No wrapped Qt method uses one,
# so the specs build the instantiations configured in containers.yml.
describe "QSet" do
  it "is built from values and deduplicates" do
    set = Qt::QSet.of(String).from(["a", "b", "a"])
    set.size.should eq(2)
    set.empty?.should be_false
    set.includes?("a").should be_true
    set.includes?("z").should be_false
    set.to_a.sort.should eq(["a", "b"])
  end

  it "adds, deletes and concatenates" do
    set = Qt::QSet.of(Int32).from([1, 2, 3])
    set << 4
    set.add(1)
    set.size.should eq(4)
    set.delete(2).should be_true
    set.delete(2).should be_false
    set.concat([10, 11])
    set.to_a.sort.should eq([1, 3, 4, 10, 11])
    set.map { |v| v * 2 }.sort.should eq([2, 6, 8, 20, 22])
  end

  it "can be modified while iterating over a copy" do
    set = Qt::QSet.of(Int32).from([1, 2, 3])
    set.to_a.each { |v| set.delete(v) if v.odd? }
    set.to_a.should eq([2])
    Qt::QSet.of(String).new.empty?.should be_true
  end
end

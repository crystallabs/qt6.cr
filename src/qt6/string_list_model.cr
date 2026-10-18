module Qt
  # bindgen 0.11.1 gives a class only the pure virtual methods it copies from
  # an abstract base, without the overloads their default arguments add.
  class StringListModel
    def column_count : Int32
      column_count(ModelIndex.new)
    end
  end
end

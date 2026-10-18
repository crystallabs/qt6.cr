module Qt
  # The matches of `RegularExpression#global_match`, as an `Iterator`:
  #
  # ```
  # regex.global_match(text).map(&.captured).to_a
  # ```
  class RegularExpressionMatchIterator
    include Iterator(RegularExpressionMatch)

    # Returns the next match, see `Iterator#next`.
    def next : RegularExpressionMatch | Iterator::Stop
      if has_next?
        RegularExpressionMatch.new(unwrap: Binding.bg_QRegularExpressionMatchIterator_next_(self))
      else
        stop
      end
    end
  end
end

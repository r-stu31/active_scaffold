class ActiveScaffold::Ring < ::Array
  # Returns the value after the given value. Wraps around.
  def after(value)
    include?(value) ? self[(index(value).to_i + 1) % length] : nil
  end
end

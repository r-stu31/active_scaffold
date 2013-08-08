module ActiveScaffold
  module MarkedModel
    # This is a module aimed at making the make session_stored marked_records available to ActiveRecord models

    def marked
      false
    end

    def marked=(value)
      value
    end
  end
end

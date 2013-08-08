module ActiveScaffold::Actions
  module Mark
    def self.included(base)
      base.helper_method :marked_records
    end

    protected

    def marked_records
      if params[:marked_records]
        params[:marked_records].split(',').collect {|x| Integer(x)}.uniq
      else
        []
      end
    end
  end
end

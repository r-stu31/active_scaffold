module ActiveScaffold
  # wrap the action rendering for ActiveScaffold controllers
  module Render
    def render(*args, &block)
      if params[:adapter] and @rendering_adapter.nil?
        @rendering_adapter = true # recursion control
        # if we need an adapter, then we render the actual stuff to a string and insert it into the adapter template
        opts = args.blank? ? Hash.new : args.first
        super :partial => params[:adapter][1..-1],
        :locals => {:payload => render_to_string(opts.merge(:layout => false), &block).html_safe},
               :use_full_path => true, :layout => false, :content_type => :html
        @rendering_adapter = nil # recursion control
      else
        super
      end
    end
  end
end

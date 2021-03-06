module UsefulUtils
  module FlavouredMarkdown
    
    def fm(content, options = {}, &block)
      options[:preserve] = options[:preserve].nil? ? true : options[:preserve]
      options[:escape_html] = options[:escape_html].nil? ? true : options[:escape_html]
      options[:sanitize] = options[:sanitize].nil? ? false : options[:sanitize]
      options[:format_inline_images] = options[:format_inline_images].nil? ? false : options[:format_inline_images]
      options[:markup] ||= :markdown
      
      if options[:escape_html]
        content = content.gsub(/[&<]/) { |special| ERB::Util::HTML_ESCAPE[special] }
      end

      ## Format images neatly by plopping them into a P tag
      if options[:format_inline_images]
        content.gsub!(/!\[Image(\d+)?\]\((.*)\)/) { content_tag(:p, image_tag($2, :alt => "Image", :width => $1), :class => "image") }
      end
      
      content = case options[:markup].to_sym
      when :markdown
        begin
          require 'rdiscount'
          RDiscount.new(content)
        rescue LoadError
          require 'bluecloth'
          BlueCloth.new(content)
        end
      when :textile then RedCloth.new(content)
      when :simple then simple_format(content)
      else
        content
      end
      
      content = (content.respond_to?(:to_html) ? content.to_html : content)
      
      ## Extract all the preblocks before we do stuff like this...
      extractions = {}
      content.gsub!(/(\<pre\>.*?\<\/pre\>|\<code\>.*?\<\/code\>)/m) do |match|
        md5 = Digest::MD5.hexdigest(match)
        extractions[md5] = match
        "{afm-extraction-#{md5}}"
      end

      ## Sanaitize the content if appropriate (doesn't play nice with textile tables)
      if options[:sanitize]
        content = sanitize(content)
      end
      
      if options[:autolink]
        content = auto_link(content)
      end

      ## Prevent italic works from ending up with an italic word in the middle.
      content.gsub!(/(^(?! {4}|\t)\w+_\w+_\w[\w_]*)/) do |x|
        x.gsub('_', '\_') if x.split('').sort.to_s[0..1] == '__'
      end
      
      if block_given?
        content = block.call(content)
      end
      
      ## Re-insert the pres
      content.gsub!(/\{afm-extraction-([0-9a-f]{32})\}/) do
        "\n\n" + extractions[$1].gsub(/(#{ERB::Util::HTML_ESCAPE.values.join('|')})/) { |special| ERB::Util::HTML_ESCAPE.invert[special] }
      end

      if options[:preserve]
        content = preserve(content)
      end
      
      content_tag :div, content, :class => 'afm cfm'
    end
    
    alias_method :afm, :fm
    
  end
end

ActionView::Base.send :include, UsefulUtils::FlavouredMarkdown

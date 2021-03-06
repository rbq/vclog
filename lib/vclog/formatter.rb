require 'ostruct'

module VCLog

  #
  class Formatter

    DIR = File.dirname(__FILE__)

    #
    attr :vcs

    #
    def initialize(vcs)
      @vcs = vcs
    end

    #
    def changelog
      @vcs.changelog
    end

    #
    def history
      @vcs.history
    end

    #
    def user
      @options.user || @vcs.user
    end

    #
    def email
      @options.email || @vcs.user
    end

    #
    def repository
      @vcs.repository
    end

    # TODO
    def url
      @options.url || '/'
    end

    # TODO
    def homepage
      @options.homepage
    end

    #
    def title
      return @options.title if @options.title
      case @doctype
      when :history
        "Release History"
      else
        "Change Log"
      end
    end

    #
    def display(doctype, format, options={})
      options = OpenStruct.new(options)

      @doctype = doctype
      @format  = format
      @options = options

      require_formatter(format)

      tmp = File.read(File.join(DIR, 'templates', "#{@doctype}.#{@format}"))
      erb = ERB.new(tmp)
      erb.result(binding)
    end

    private

      #
      def require_formatter(format)
        case format.to_s
        when 'yaml'
          require 'yaml'
        when 'json'
          require 'json'
        end
      end

      #
      def h(input)
         result = input.to_s.dup
         result.gsub!("&", "&amp;")
         result.gsub!("<", "&lt;")
         result.gsub!(">", "&gt;")
         result.gsub!("'", "&apos;")
         #result.gsub!("@", "&at;")
         result.gsub!("\"", "&quot;")
         return result
      end

  end

end

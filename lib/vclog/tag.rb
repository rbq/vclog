module VCLog

  class Tag
    attr_accessor :name
    attr_accessor :date
    attr_accessor :author
    attr_accessor :message
    #attr_accessor :changes

    def initialize(name, date, author, message, changes=[])
      self.name    = name
      self.date    = date
      self.author  = author
      self.message = message
      #self.changes = changes
    end

    def name=(name)
      @name = name.strip
    end

    def author=(author)
      @author = author.strip
    end

    def date=(date)
      @date = Time.parse(date)
    end

    def message=(msg)
      @message = msg.strip
    end

    alias_method :tagger, :author
    alias_method :tagger=, :author=

    def to_json
      to_h.to_json
    end

    def to_h
      {
        :name => name,
        :date => date,
        :author => author,
        :message => message
      }
    end
  end

end

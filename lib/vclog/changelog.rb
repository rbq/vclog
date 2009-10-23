module VCLog

  require 'vclog/facets'

  # Supports output formats:
  #
  #   xml
  #   html
  #   yaml
  #   json
  #   text
  #
  class Changelog

    include Enumerable

    DAY = 24*60*60

    attr :changes

    def initialize(changes=nil)
      @changes = changes || []
    end

    def change(date, who, rev, note)
      note, type = *split_note(note)
      note = note.gsub(/^\s*?\n/m,'') # remove blank lines
      @changes << Entry.new(:when=>date, :who=>who, :rev=>rev, :type=>type, :msg=>note)
    end

    def each(&block) ; @changes.each(&block) ; end
    def empty? ; @changes.empty? ; end
    def size ; @changes.size ; end

    #
    def <<(entry)
      raise unless Entry===entry
      @changes << entry
    end

    # Return a new changelog with entries that have a specified type.
    # TODO: Be able to specify which types to include or omit.
    def typed
      self.class.new(changes.select{ |e| e.type })
    end

    # Return a new changelog with entries occuring after the
    # given date limit.
    def after(date_limit)
      after = changes.select{ |entry| entry.date > date_limit + DAY }
      self.class.new(after)
    end

    # Return a new changelog with entries occuring before the
    # given date limit.
    def before(date_limit)
      before = changes.select{ |entry| entry.date <= date_limit + DAY }
      self.class.new(before)
    end

    #

    #
    def by_type
      mapped = {}
      changes.each do |entry|
        mapped[entry.type] ||= self.class.new
        mapped[entry.type] << entry
      end
      mapped
    end

    #
    def by_author
      mapped = {}
      changes.each do |entry|
        mapped[entry.author] ||= self.class.new
        mapped[entry.author] << entry
      end
      mapped
    end

    #
    def by_date
      mapped = {}
      changes.each do |entry|
        mapped[entry.date.strftime('%Y-%m-%d')] ||= self.class.new
        mapped[entry.date.strftime('%Y-%m-%d')] << entry
      end
      mapped = mapped.to_a.sort{ |a,b| b[0] <=> a[0] }
      mapped
    end

    #
    #def by_date
    #  mapped = {}
    #  changes.each do |entry|
    #    mapped[entry.date.strftime('%Y-%m-%d')] ||= self.class.new
    #    mapped[entry.date.strftime('%Y-%m-%d')] << entry
    #  end
    #  mapped
    #end

    ##################
    # Output Formats #
    ##################

    def format_yaml
      require 'yaml'
      changes.to_yaml
    end

    def format_json
      require 'json'
      changes.to_json
    end

    #
    def format_gnu
      x = []
      by_date.each do |date, date_changes|
        date_changes.by_author.each do |author, author_changes|
          x << %[#{date}  #{author}\n]
          #author_changes = author_changes.sort{|a,b| b.date <=> a.date}
          author_changes.each do |entry|
            if entry.type
              msg = "#{entry.message} [#{entry.type}]".tabto(10)
            else
              msg = "#{entry.message}".tabto(10)
            end
            msg[8] = '*'
            x << msg
          end
        end
        x << "\n"
      end
      return x.join("\n")
    end

    #
    alias_method :to_s, :format_gnu

    # Create an XML formated changelog.
    # +xsl+ reference defaults to 'log.xsl'
    def format_xml(xsl=nil)
      xsl = 'log.xsl' if xsl.nil?
      x = []
      x << %[<?xml version="1.0"?>]
      x << %[<?xml-stylesheet href="#{xsl}" type="text/xsl" ?>] if xsl
      x << %[<log>]
      changes.sort{|a,b| b.date <=> a.date}.each do |entry|
        x << %[<entry>]
        x << %[  <date>#{entry.date}</date>]
        x << %[  <author>#{escxml(entry.author)}</author>]
        x << %[  <revison>#{escxml(entry.revison)}</revison>]
        x << %[  <type>#{escxml(entry.type)}</type>]
        x << %[  <message>#{escxml(entry.message)}</message>]
        x << %[</entry>]
      end
      x << %[</log>]
      return x.join("\n")
    end

    # Create an HTML formated changelog.
    # +css+ reference defaults to 'log.css'
    def format_html(css=nil)
      css = 'log.css' if css.nil?
      x = []
      x << %[<html>]
      x << %[<head>]
      x << %[  <title>Changelog</title>]
      x << %[  <style>]
      x << %[    body{font-family: sans-serif;}]
      x << %[    #changelog{width:800px;margin:0 auto;}]
      x << %[    li{padding: 10px;}]
      x << %[    .date{font-weight: bold; color: gray; float: left; padding: 0 5px;}]
      x << %[    .author{color: red;}]
      x << %[    .message{padding: 5 0; font-weight: bold;}]
      x << %[    .revison{font-size: 0.8em;}]
      x << %[  </style>]
      x << %[  <link rel="stylesheet" href="#{css}" type="text/css">] if css
      x << %[</head>]
      x << %[<body>]
      x << %[  <div id="changelog">]
      x << %[    <h1>ChangeLog</h1>]
      x << %[    <ul class="log">]
      changes.sort{|a,b| b.date <=> a.date}.each do |entry|
        x << %[  <li class="entry">]
        x << %[    <div class="date">#{entry.date}</div>]
        x << %[    <div class="author">#{escxml(entry.author)}</div>]
        x << %[    <div class="type">#{escxml(entry.type)}</div>]
        x << %[    <div class="message">#{escxml(entry.message)}</div>]
        x << %[    <div class="revison">##{escxml(entry.revison)}</div>]
        x << %[  </li>]
      end
      x << %[    </ul>]
      x << %[  </div>]
      x << %[</body>]
      x << %[</html>]
      return x.join("\n")
    end

    #
    def format_rel(file, current_version=nil, current_release=nil, rev=false)
      log = []
      # collect releases already listed in changelog file
      rels = releases(file)
      # add current verion to release list (if given)
      previous_version = rels[0][0]
      if current_version < previous_version
        raise ArgumentError, "Release version is less than previous version (#{previous_version})."
      end
      #case current_version
      #when 'major'
      #    v = previous_verison.split(/\W/)
      #    v[0] = v[0].succ
      #    current_version = v.join('.')
      #when 'minor'
      #    v = previous_verison.split(/\W/)
      #    v[1] = v[1].succ
      #    current_version = v.join('.')
      #  end
      #end
      rels << [current_version, current_release || Time.now]
      # make sure all release date are Time objects
      rels = rels.collect{ |v,d| [v, Time===d ? d : Time.parse(d)] }
      # only uniq releases
      rels = rels.uniq
      # sort by release date
      rels = rels.to_a.sort{ |a,b| a[1] <=> b[1] }
      # organize into deltas
      deltas, last = [], nil
      rels.each do |rel|
        deltas << [last, rel]
        last = rel
      end
      # gather changes for each delta and build log
      deltas.each do |gt, lt|
        if gt
          gt_vers, gt_date = *gt
          lt_vers, lt_date = *lt
          #gt_date = Time.parse(gt_date) unless Time===gt_date
          #lt_date = Time.parse(lt_date) unless Time===lt_date
          changes = after(gt_date).before(lt_date)
        else
          lt_vers, lt_date = *lt
          #lt_date = Time.parse(lt_date) unless Time===lt_date
          changes = before(lt_date)
        end
        reltext = changes.format_rel_types(rev)
        unless reltext.strip.empty?
          log << "== #{lt_vers} / #{lt_date.strftime('%Y-%m-%d')}\n\n#{reltext}"
        end
      end
      # reverse log order and make into document
      log.reverse.join("\n")
    end

    #
    def format_rel_types(rev=false)
      groups = changes.group_by{ |e| e.type_number }
      string = ""
      5.times do |n|
        entries = groups[n]
        next if !entries
        next if entries.empty?
        string << "* #{entries.size} #{entries[0].type_phrase}\n\n"
        entries.sort!{|a,b| a.date <=> b.date }
        entries.each do |entry|
          #string << "== #{date}  #{who}\n\n"  # no email :(
          if rev
            text = "#{entry.message} (##{entry.revison})"
          else
            text = "#{entry.message}"
          end
          text = text.tabto(6)
          text[4] = '*'
          #entry = entry.join(' ').tabto(6)
          #entry[4] = '*'
          string << text
          string << "\n"
        end
        string << "\n"
      end
      string
    end

    #
    def releases(file)
      return [] unless file
      clog = File.read(file)
      tags = clog.scan(/^==(.*?)$/)
      rels = tags.collect do |t|
        parse_version_tag(t[0])
      end
      return rels
    end

    #
    def parse_version_tag(tag)
      version, date = *tag.split('/')
      version, date = version.sub(/^\=+\s*/,'').strip, date.strip
      return version, date
    end

    ###################
    # Save Chaqngelog #
    ###################

    # Save changelog as file in specified format.
    def save(file, format=:gnu, *args)
      case format.to_sym
      when :xml
        text = format_xml
        save_xsl(file)
      when :html
        text = format_html(*args)
      when :rel
        text = format_rel(file, *args)
      when :yaml
        text = format_yaml(file)
      when :json
        text = format_json(file)
      else
        text = format_gnu
      end

      FileUtils.mkdir_p(File.dirname(file))

      different = true
      if File.exist?(file)
        different = (File.read(file) != text)
      end

      File.open(file, 'w') do |f|
        f << text
      end if different
    end

  private

    #
    def escxml(input)
       result = input.to_s.dup
       result.gsub!("&", "&amp;")
       result.gsub!("<", "&lt;")
       result.gsub!(">", "&gt;")
       result.gsub!("'", "&apos;")
       #result.gsub!("@", "&at;")
       result.gsub!("\"", "&quot;")
       return result
    end

    #
    def save_xsl(file)
      #xslfile = file.chomp(File.extname(file)) + '.xsl'
      xslfile = File.join(File.dirname(file), 'log.xsl')
      unless File.exist?(xslfile)
        FileUtils.mkdir_p(File.dirname(xslfile))
        File.open(xslfile, 'w') do |f|
          f << DEFAULT_LOG_XSL
        end
      end
    end

    # Looks for a "[type]" indicator at the end of the message.
    def split_note(note)
      note = note.strip
      if md = /\A.*?\[(.*?)\]\s*$/.match(note)
        t = md[1].strip.downcase
        n = note.sub(/\[#{md[1]}\]\s*$/, "")
      else
        n, t = note, nil
      end
      return n, t
    end

    # = Change Log Entry class
    class Entry
      include Comparable

      attr_accessor :author
      attr_accessor :date
      attr_accessor :revison
      attr_accessor :message
      attr_accessor :type

      def initialize(opts={})
        @author  = (opts[:author]  || opts[:who]).strip
        @date    = opts[:date]    || opts[:when]
        @revison = opts[:revison] || opts[:rev]
        @message = opts[:message] || opts[:msg]
        @type    = opts[:type]
      end

      #def clean_type(type)
      #  case type.to_s
      #  when 'maj', 'major' then :major
      #  when 'min', 'minor' then :minor
      #  when 'bug'          then :bug
      #  when ''             then :other
      #  else
      #    type.to_sym
      #  end
      #end

      #
      def type_phrase
        case type.to_s
        when 'maj', 'major'
          'Major Enhancements'
        when 'min', 'minor'
          'Minor Enhancements'
        when 'bug'
          'Bug Fixes'
        when ''
          'General Enhancements'
        when '-'
          'Administrative Changes'
        else
          "#{type.capitalize} Enhancements"
        end
      end

      #
      def type_number
        case type.to_s.downcase
        when 'maj', 'major'
          0
        when 'min', 'minor'
          1
        when 'bug'
          2
        when ''
          4
        when '-'
          5
        else # other
          3
        end
      end

      #
      def <=>(other)
        other.date <=> date
      end

      def inspect
        "#<Entry:#{object_id} #{date}>"
      end

      def to_h
        { 'author'   => @author,
          'date'     => @date,
          'revision' => @revison,
          'message'  => @message,
          'type'     => @type
        }
      end

      def to_json
        to_h.to_json
      end

      def to_yaml(*args)
        to_h.to_yaml(*args)
      end

    end #class Entry

  end

  DEFAULT_LOG_XSL = <<-END.tabto(0)
    <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

      <xsl:output cdata-section-elements="script"/>

      <xsl:template match="/">
        <html>
          <head>
            <title>Changelog</title>
            <link REL='SHORTCUT ICON' HREF="../img/ruby-sm.png" />
            <style>
              td { font-family: sans-serif;  padding: 0px 10px; }
            </style>
          </head>
          <body>
          <div class="container">
            <h1>Changelog</h1>
            <table style="width: 100%;">
              <xsl:apply-templates />
            </table>
          </div>
          </body>
        </html>
      </xsl:template>

      <xsl:template match="entry">
          <tr>
            <td><b><pre><xsl:value-of select="message"/></pre></b></td>
            <td><xsl:value-of select="author"/></td>
            <td><xsl:value-of select="date"/></td>
          </tr>
      </xsl:template>

    </xsl:stylesheet>
  END

end

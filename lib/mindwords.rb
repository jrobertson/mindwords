#!/usr/bin/env ruby

# file: mindwords.rb

require 'rexle'
require 'rxfreadwrite'
require 'line-tree'
require 'polyrex'


module HashCopy
  refine Hash do

    def deep_clone()
      Marshal.load(Marshal.dump(self))
    end

  end
end

class MindWords
  using ColouredText
  using HashCopy
  include RXFReadWriteModule

  attr_reader :words_missing
  attr_accessor :lines, :filepath

  def initialize(raws='', parent: nil, debug: false)

    @parent, @debug = parent, debug

    import(raws) if raws.length > 1

  end

  def add(s)

    @lines.concat s.strip.lines

  end

  def breadcrumb()
    @parent.attributes[:breadcrumb].split(/ +\/ +/) if @parent
  end

  def headings()
    breadcrumb[0..-2]
  end


  def element(id)

    doc = Rexle.new(to_xml())
    e =  doc.root.element("//*[@id='#{id}']")
    #e.attributes[:breadcrumb].to_s if e

  end

  # If title supplied, searches for a requested title and returns the
  #   associated hashtags
  # When no title is supplied, it will return the hashtags for the
  #   parent element of a search result object
  #
  def hashtags(title=nil)

    if title then
      found = search(title)
      found.hashtags() if found
    else
      @parent.attributes[:hashtags].split if @parent and @parent.attributes[:hashtags]
    end

  end

  def import(raws)

    s, type = RXFReader.read raws

    @filepath = raws if type == :file or type == :dfs
    rawlines = (s.strip.gsub(/(^\n|\r)/,'') + "\n").lines.uniq
    rawlines.shift if rawlines.first =~ /<\?mindwords\?>/

    # remove mindwords lines which don't have a hashtag
    lines = rawlines.reject do |line|

      found = line[/^\w+[^#]+$/]

      if found then
        puts ('no hashtag found on this line -> ' + line).warn
      end

      found

    end

    #--- handle indented text, indicated there are *groups* of words

    s2 = lines.join.gsub(/\n\s*$/,'')
    puts s2 if @debug
    a = s2.strip.split(/(?=^\w+)/)
    a2 = a.inject([]) do |r,x|

      if x =~ /\n\s+/ then

        a4 = x.lines[1..-1].map do |line|

          puts 'x.lines[0]: ' + x.lines[0].inspect if @debug
          hashtag = if x.lines[0][/ /] then
            x.lines[0].gsub(/\b\w/) {|x| x.upcase}.gsub(/ /,'')
          else
            x.lines[0]
          end

          "%s #%s" % [line.strip, hashtag]
        end

        r.concat a4

      else
        r << x
      end

    end

    #-- end of indented text handler

    @lines = a2.inject([]) do |r,line|

      # the following does 2 things:
      #      1. splits words separated by a bar (|) onto their own line
      #      2. prefixes a word with an underscore if the word is the
      #         same as the hashtag. That way it's not removed by the
      #         redundancy checker

      raw_words, raw_hashtags = line.split(/(?= #)/,2)
      words = raw_words.split(/ *\| */)
      hashtags = raw_hashtags.scan(/(?<=#)\w+/)

      words.each do |word|

        linex = (word +  raw_hashtags)
        r << (hashtags.include?(word) ? linex.sub!(/\b#{word}\b/, '_\0') \
              : linex)
      end

      r
    end
  end

  # helpful when searching for a word itself using autosuggest
  #
  def lookup(s)
    self.to_words.keys.sort.grep /^#{s}/i
  end

  # same as #lines but inludes the breadcrumb path; Helpful to identify
  # which words don't have a breadcrumb path.
  #
  def linesplus()

    to_a.map do |word, _|
      r = search word
      r ? [word, r.breadcrumb] : [r, nil]
    end

  end

  def save(file=@filepath)

    return if @lines.empty?

    puts 'before save' if @debug

    FileX.write file, to_s()

  end

  # Accepts a list of words with the aim of returning a MindWords document
  # using matched words with hashtags from the existing MindWords document.
  #
  def reflect(raws)

    h = to_h

    missing_words = []

    # add the tags from the main list
    a = raws.strip.lines.map do |x|
      if h[x.chomp] then
        [x.chomp, h[x.chomp]]
      else
        missing_words << x
        nil
      end
    end.compact

    # add any linkage words from the tags
    #
    a.map(&:last).flatten(1).each do |s|

      a << [s, h[s]] if h[s]

    end

    # remove suplicates lines and transform it into a raw mindwords format
    #
    raws3 = a.uniq.map {|s,tags| [s, tags.map {|x| '#' + x }.join(' ')].join(' ') }.join("\n")

    [MindWords.new(raws3), missing_words]

  end

  def search(keyword, succinct: true)

    a = @lines.grep(/#{keyword}/i).map do |line|

      puts 'line: ' + line.inspect if @debug

      words = line.split
      r = words.grep /#{keyword}/i
      i = words.index r[0]

      [line, i]

    end

    return nil if a.empty?
    #return a[0][0] if a.length < 2

    a2 = a.sort_by(&:last).map(&:first)
    puts 'a2: ' + a2.inspect if @debug
    e = element(keyword.downcase.gsub(/ +/,'-'))

    return MindWords.new(a2.uniq.join,  debug: @debug) if e.nil?

    # find and add any linkage support lines
    #

    a3 = []

    a2.each do |line|

      line.chomp.scan(/#[^ ]+/).each do |hashtag|

        puts 'hashtag: ' + hashtag.inspect  if @debug
        r2 = @lines.grep(/^#{hashtag[1..-1]} #/)
        a3 << r2.first if r2

      end
    end

    puts 'a2: ' + a2.inspect if @debug
    a2.concat a3

    if succinct then
      MindWords.new(a2.uniq.join, parent: e, debug: @debug)
    else
      MindWords.new(a2.uniq.join,  debug: @debug)
    end

  end

  def sort()
    s = @lines.sort.join

    def s.to_s()
      self.lines.map do |x|
        title, hashtags = x.split(/(?=#)/,2)
        title + hashtags.chomp.brown
      end.join("\n")
    end

    return s
  end

  def sort!()
    @lines = sort().lines
    self
  end

  def tag_sort()

    h = @lines.group_by  {|x| x[/#\w+/]}
    s = h.sort.map {|key, value| value.sort }.join

    def s.to_s()
      self.lines.map do |x|
        title, hashtags = x.split(/(?=#)/,2)
        title + hashtags.chomp.brown
      end.join("\n")
    end

    return s

  end

  def tag_sort!()
    @lines = tag_sort().lines
    self
  end

  def to_a()

    @lines.map do |x|
      s, rawtags = x.split(/(?= #)/,2)
      [s, rawtags.scan(/(?<=#)\w+/)]
    end

  end

  def to_h()
    to_a.to_h
  end

  def to_hashtags()
    @hashtags
  end

  def to_outline(sort: true)

    build()

    if sort then
      a = LineTree.new(@outline).to_a
      puts ('a: ' + a.inspect).debug if @debug
      a2tree(tree_sort(a))
    else
      @outline
    end

  end

  alias to_tree to_outline

  def to_s(colour: false)

    header = "<?mindwords?>\n\n"
    return header + @lines.map(&:chomp).join("\n") unless colour

    body = @lines.map do |x|
        title, hashtags = x.split(/(?=#)/,2)
        title + hashtags.chomp.brown
    end.join("\n")

    header + body

  end

  def to_words()

    h = {}

    Rexle.new(to_xml).root.each_recursive do |e|

      h[e.attributes[:title]] = {
        breadcrumb: e.attributes[:breadcrumb],
        hashtags: e.attributes[:hashtags]
      }

    end

    h

  end

  def to_xml()
    build() unless @xml
    @xml
  end

  private

  def build()

    h = {}

    @lines.each do |line|

      title, rawtags = line.split(/(?= #)/,2)

      rawtags.scan(/#(\w+)/).flatten(1).each do |rawtag|
        tag = rawtag.gsub(/ +/, '_')
        h[tag] ||= []
        h[tag] << title.strip
      end

    end

    @hashtags = h.deep_clone.sort.map {|tag, fields| [tag, fields.sort]}.to_h


    a = rexlize(h)
    doc = Rexle.new(['root', {}, '', *a])
    puts 'doc.xml: ' + doc.xml(pretty: true) if @debug

    # apply node nesting

    doc.root.elements.each do |e|

      doc.root.xpath('//' + e.name).each do |e2|

        next if e2 === e

        e2.parent.add e
        e2.delete

      end

    end

    puts 'after nesting; doc.xml: ' + doc.xml(pretty: true) if @debug

    # remove duplicates which appear in the same branch above the nested node
    rm_duplicates(doc)

    # remove redundant nodes (outsiders)
    # a redundant node is where all children exist in existing nested nodes

    redundants = doc.root.elements.map do |e|

      r = e.elements.all? {|x| !x.has_elements?}
      puts "%s %s" % [e.name, r] if @debug
      dups = e.elements.all? {|x| doc.root.xpath('//' + x.name).length > 1}
      puts 'dups: ' + dups.inspect if @debug
      e.backtrack.to_s if dups

    end

    puts 'redundants: ' + redundants.inspect if @debug

    redundants.compact.each {|x| doc.element(x).delete }

    node = if @parent then
      found = doc.root.element('//' + @parent.name)
      found ? found.parent : doc.root
    else
      doc.root
    end

    # the following removes any undescore prefix from words which were the
    # same as the hashtag

    node.root.each_recursive do |e|

      next unless e
      puts 'e: ' + e.inspect if @debug

      e.attributes[:id] = e.attributes[:id].sub(/^_/,'') if e.attributes[:id]
      e.attributes[:title] = e.attributes[:title].sub(/^_/,'') if e.attributes[:title]
      e.value = e.value.sub(/^_/,'')
      e.name = e.name.sub(/^_/,'')

    end

    # ----

    @outline = treeize node

    # ----

    # It's common for words to be missing from the outline, either because
    # they have erroneously been flagged as redundant or lack specific hashtag
    # context. Below, we attempt to identify the missing words with a
    # suggestion on how to fix it.

    words = @outline.lines.map(&:strip)
    orig_words = to_s().lines.map {|x| x[/^[^#]+(?= #)/]}.compact
    @words_missing = orig_words - words

    if @words_missing.any? then

      tags = []
      @words_missing.inject(tags) do |r,word|

        found = to_s().lines.grep(/#{word}/)

        if found then
          r << found.first.scan(/#\w+/).map {|x| x[1..-1]}
        else
          r
        end

      end

      add_sugg = tags.uniq.map do |atag|
        ("%s #%s" % [atag[0], atag[1]]).bg_black
      end

      puts ('@words_missing: ' + @words_missing.join(', ') ).warn
      puts "suggestion: try adding the following:".info
      puts add_sugg.join("\n")
      puts

    end

    # ----

    node.root.each_recursive do |e|

      e.attributes[:id] = e.attributes[:title].downcase.gsub(/ +/,'-')

      s = e.parent.attributes[:breadcrumb] ? \
          e.parent.attributes[:breadcrumb].to_s  + ' / ' : ''
      e.attributes[:breadcrumb] = s +  e.value.strip

      r = @lines.grep(/^#{e.attributes[:title]} #/i)
      next unless r.any?
      e.attributes[:hashtags] = r[0].scan(/(?<=#)\w+/).join(' ')


    end

    @xml = node.xml pretty: true

  end

  def rexlize(a)

    a.map do |x|

      puts 'x: ' + x.inspect if @debug

      case x
      when String
        [x.downcase.gsub(/ +/,''),  {title: x}, x]
      when Hash
        [
          x.keys.first.downcase.gsub(/_/,' '),
          {title: x.keys.first},
          x.keys.first,
         *rexlize(x.values.first)
        ]
      when Array
        [
          x.first.downcase.gsub(/_/,' '),
          {title: x.first}, x.first, *rexlize(x.last)
        ]
      end
    end

  end

  def rm_duplicates(doc)

    duplicates = []

    doc.root.each_recursive do |e|

      rows = e.parent.xpath('//' + e.name)
      next if rows.length < 2

      rows[0..-2].each {|e2| duplicates << e.backtrack.to_s }

    end

    duplicates.each do |path|

      puts 'pathx: ' + path.inspect if @debug
      e = doc.element(path)
      e.delete if e

    end

  end

  def treeize(node, indent=0)

    s, *children = node.children

    lines = children.map do |e|

      puts 'e: ' + e.inspect if @debug
      if e.is_a? Rexle::Element then
        ('  ' * indent) + e.value.to_s +  "\n" + treeize(e,indent+1)
      end
    end

    lines.join
  end

  def tree_sort(a)

    if a.first.is_a? Array then
      a.sort_by(&:first).map {|x|  tree_sort(x) }
    elsif a.any?
      [a.first] + tree_sort(a[1..-1])
    else
      []
    end
  end

  def a2tree(a, indent=0)

    a.map do |row|
      title, *remaining = row
      children = remaining ? a2tree(remaining, indent+1) : ''
      ('  ' * indent) + title + "\n" + children
    end.join

  end

end

class MindWordsWidget

  def initialize()

  end


  # can be used for main entries or a words list
  #
  def input(content: '', action: 'mwupdate', target: 'icontent')

<<EOF
<form action='#{action}' method='post' target='#{target}'>
  <textarea name='content' cols='30' rows='19'>
#{content}
  </textarea>
  <input type='submit' value='Submit'/>
</form>
EOF
  end

end

class MindWordsPlus

  attr_reader :to_px

  def initialize(s, fields: %w(title content), debug: false)

    lt = LineTree.new(s)
    h = lt.to_h

    mw = MindWords.new(h.keys.join("\n"))
    outline = mw.to_outline

    out = outline.lines.map do |line|

      word = line[/\w[^$]+/]

      found = h.keys.find do |key, value|

        if debug then
          puts 'key2: ' + key[/^[^#]+(?= #)/].inspect
          puts 'word: ' + word.chomp.inspect
        end

        word.chomp == key[/^[^#]+(?= #)/]
      end

      puts 'found: ' + found.inspect if debug

      if found and h[found][:body] then
        puts '***' + h[found][:body].keys.inspect  if debug
        line.chomp + ' # ' + h[found][:body].keys.join('<br/>') + "\n"
      else
        line
      end

    end

    puts out.join if debug

    px = Polyrex.new(schema: "entries[title]/entry[#{fields.join(', ')}]",
                     delimiter: ' # ')
    px.import out.join
    @px = px

  end

  def to_ph()

    lines = []

    @px.each_recursive do |x, parent, level|

      if level.to_i < 3 then
        line = ("\n" + '#' * (level.to_i + 1)) + ' ' + x.title + "\n\n"
      else
        line = '*' + ' ' + x.title + "\n"
      end

      if x.content.length >= 1 then
        txt = '- ' + x.content.gsub('&lt;','<').gsub('&gt;','>')
        line += "\n" + txt.gsub('<br/>',"\n- ") + "\n"
      end

      lines << line

    end

    lines.join.gsub(/\n\n\n/,"\n\n")
  end

  def to_px()
    @px
  end

  def to_tree()

    lines = []
    @px.each_recursive do |x, parent, level|

      line = ('  ' * level) + x.title

      if x.content.length >= 1 then
        txt = x.content.gsub('&lt;','<').gsub('&gt;','>')
        indent = '  ' * (level+1) + '* '
        line += "\n" + indent +  txt.gsub('<br/>',"\n" + indent)
      end

      lines << line
    end

    lines.join("\n")

  end

end

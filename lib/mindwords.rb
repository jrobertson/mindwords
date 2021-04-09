#!/usr/bin/env ruby

# file: mindwords.rb

require 'rexle'
require 'rxfhelper'
require 'line-tree'

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
  
  attr_accessor :lines, :filepath
  
  def initialize(raws='', parent: nil, debug: false)

    @parent, @debug = parent, debug
        
    s, type = RXFHelper.read raws
    
    @filepath = raws if type == :file or type == :dfs
    lines = s.strip.gsub(/^\n/,'').lines
    lines.shift if lines.first =~ /<\?mindwords\?>/       
    
    @lines = lines.inject([]) do |r,line|
      
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
  
  def add(line)
    @lines << line
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
  
  def hashtags()
    @parent.attributes[:hashtags].split if @parent
  end

  def save(file=@filepath)
    
    return if @lines.empty?
    
    puts 'before save' if @debug
    File.write file, to_s()
    
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
    sort ? a2tree(tree_sort(LineTree.new(@outline).to_a)) : @outline
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

    # apply node nesting

    doc.root.elements.each do |e|
      
      doc.root.xpath('//' + e.name).each do |e2|
        
        next if e2 === e
        
        e2.parent.add e
        e2.delete
        
      end
      
    end

    
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

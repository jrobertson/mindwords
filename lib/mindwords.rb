#!/usr/bin/env ruby

# file: mindwords.rb

require 'rexle'
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
  
  
  def initialize(s, parent: nil, debug: false)

    @debug = debug
    @a = s.strip.gsub(/^\n/,'').lines
    @a.shift if @a.first =~ /<\?mindwords\?>/
    
    lines = @a.map do |line|

      word = line.split(/ (?=#)/,2)

    end
    
    h = {}
    @hashtags = {}

    lines.each do |title, rawtags|

      rawtags.scan(/#(\w+)/).flatten(1).each do |rawtag|
        tag = rawtag.gsub(/ +/, '_')
        h[tag] ||= []
        h[tag] << title
      end

    end
    
    @hashtags = h.deep_clone.sort.map {|tag, fields| [tag, fields.sort]}.to_h

    # does the key exist as a field? Nesting of hash object is performed here.

    h.keys.each do |key|

      r = h.detect {|_, value| value.include? key}
      next unless r
      h[r.first].delete key
      h[r.first] << {key => h[key]}
      #puts r.inspect
      h.delete key

    end

    @h = h
    
    a = rexlize(h)
    doc = Rexle.new(['root', {}, '', *a])

    
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
    rm_duplicates(doc)
    
    node = if parent then
      found = doc.root.element('//' + parent)
      found ? found : doc.root
    else
      doc.root
    end
    
    @outline = treeize node
    
    node.root.each_recursive do |e|
    
      e.attributes[:id] = e.attributes[:title].downcase.gsub(/ +/,'-')      
      
      s = e.parent.attributes[:breadcrumb] ? \
          e.parent.attributes[:breadcrumb].to_s  + ' / ' : ''
      e.attributes[:breadcrumb] = s +  e.value.strip
      
      r = @a.grep(/^#{e.attributes[:title]} #/i)
      next unless r.any?
      e.attributes[:hashtags] = r[0].scan(/(?<=#)\w+/).join(' ')

      
    end
    
    @xml = node.xml pretty: true
    
  end
  
  def element(id)
    
    doc = Rexle.new(@xml)
    e =  doc.root.element("//*[@id='#{id}']")
    #e.attributes[:breadcrumb].to_s if e
    
  end  
  
  def search(keyword)
    
    a = @a.grep(/#{keyword}/i).map do |line|
      
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
    MindWords.new(a2.join, parent: keyword, debug: @debug)
    
  end
  
  def sort()
    s = @a.sort.join
    
    def s.to_s()
      self.lines.map do |x|
        title, hashtags = x.split(/(?=#)/,2)
        title + hashtags.chomp.brown
      end.join("\n")
    end    
    
    return s
  end
  
  def sort!()
    @a = sort().lines
    self
  end
  
  def tag_sort()
    
    h = @a.group_by  {|x| x[/#\w+/]}    
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
    @a = tag_sort().lines
    self
  end
  
  def to_h()
    @h
  end
  
  def to_hashtags()
    @hashtags
  end

  def to_outline(sort: true)
    sort ? a2tree(tree_sort(LineTree.new(@outline).to_a)) : @outline
  end
  
  def to_s(colour: false)
    
    header = "<?mindwords?>\n\n"
    return header + @a.join unless colour
    
    body = @a.map do |x|
        title, hashtags = x.split(/(?=#)/,2)
        title + hashtags.chomp.brown
    end.join("\n")
    
    header + body
    
  end
  
  def to_words()
    to_outline.lines.map {|x| x[/\w[\w ]+/] }
  end
  
  def to_xml()
    @xml
  end

  private

  def rexlize(a)
    
    a.map do |x|
     
      puts 'x: ' + x.inspect if @debug

      case x
      when String
        [x.gsub(/ +/,'_'),  {title: x}, x]
      when Hash
        [
          x.keys.first.gsub(/_/,' '), 
          {title: x.keys.first}, 
          x.keys.first,
         *rexlize(x.values.first)
        ]
      when Array
        [x.first.gsub(/_/,' '), {title: x.first}, x.first, *rexlize(x.last)]
      end
    end

  end
  
  def rm_duplicates(doc)
    
    duplicates = []
    doc.root.each_recursive do |e|

      puts 'e: ' + e.name.inspect if @debug
      rows = e.parent.xpath('//' + e.name)
      next if rows.length < 2

      rows[1..-1].each do |e2|
        puts 'e2: ' + e2.name.inspect if @debug
        duplicates << [e.backtrack.to_s, e2.backtrack.to_s]
      end
    end

    duplicates.each do |path, oldpath| 
      e = doc.element(path);
      e2 = doc.element(oldpath);  
      next unless e2
      e2.parent.add e
      e2.delete
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


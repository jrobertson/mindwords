#!/usr/bin/env ruby

# file: mindwords.rb

require 'rexle'

class MindWords
  using ColouredText
  
  def initialize(s, debug: false)

    @debug = debug
    @a = s.strip.lines
    
    lines = @a.map do |line|

      word = line.split(/ (?=#)/,2)

    end

    h = {}

    lines.each do |x|

      x.last.scan(/#(\w+)/).flatten(1).each do |rawtag|
        tag = rawtag.gsub(/ +/, '_')
        h[tag] ||= []
        h[tag] << x.first
      end

    end

    # does the key exist as a field?

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
    
    @xml = doc.root.xml pretty: true
    @outline = treeize doc.root
    
  end
  
  def search(keyword)
    
    a = @a.grep(/#{keyword}/i).map do |line|
      
      words = line.split
      r = words.grep /#{keyword}/i
      i = words.index r[0]
      
      [line, i]
      
    end
    
    return nil if a.empty?
    #return a[0][0] if a.length < 2

    a2 = a.sort_by(&:last).map(&:first)
    MindWords.new(a2.join)
    
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

  def to_outline(sort: true)
    sort ? a2tree(tree_sort(LineTree.new(@outline).to_a)) : @outline
  end
  
  def to_s(colour: false)
    
    return @a.join unless colour
    
    @a.map do |x|
        title, hashtags = x.split(/(?=#)/,2)
        title + hashtags.chomp.brown
    end.join("\n")
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
        [x.gsub(/ +/,'_'),  {}, x]
      when Hash
        [x.keys.first, {}, x.keys.first.gsub(/_/,' '), *rexlize(x.values.first)]
      when Array
        [x.first, {}, x.first.gsub(/_/,' '), *rexlize(x.last)]
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

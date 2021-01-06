#!/usr/bin/env ruby

# file: mindwords.rb

require 'rexle'

class MindWords

  def initialize(s, debug: false)

    @debug = debug

    lines = s.strip.lines.map do |line|

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
    
    @outline = treeize doc.root
    
  end

  def to_outline()
    @outline
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

end


Gem::Specification.new do |s|
  s.name = 'mindwords'
  s.version = '0.6.0'
  s.summary = 'Helps get what\'s in your mind into a structure using ' + 
      'words and hashtags.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mindwords.rb']
  s.add_runtime_dependency('line-tree', '~> 0.9', '>=0.9.2')
  s.add_runtime_dependency('rxfhelper', '~> 1.1', '>=1.1.3')
  s.signing_key = '../privatekeys/mindwords.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/mindwords'
end

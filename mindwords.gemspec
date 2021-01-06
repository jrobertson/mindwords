Gem::Specification.new do |s|
  s.name = 'mindwords'
  s.version = '0.1.0'
  s.summary = 'Helps get what\'s in your mind into a structure using words and hashtags.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/mindwords.rb']
  s.add_runtime_dependency('rexle', '~> 1.5', '>=1.5.9')
  s.signing_key = '../privatekeys/mindwords.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/mindwords'
end

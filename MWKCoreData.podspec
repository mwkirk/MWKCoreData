Pod::Spec.new do |s|
  s.name             = "MWKCoreData"
  s.version          = "1.0.0"
  s.license          = "MIT"
  s.summary          = "Simple, lightweight library for Core Data"
  s.description      = <<-DESC
  Lightweight, curated library for Core Data that keeps you close to the metal but removes some of the drudgery and eases progressive migrations.
  DESC
  s.homepage         = "https://github.com/mwkirk/MWKCoreData"
  s.author           = "Mark Kirk"
  s.social_media_url = "https://twitter.com/postmodjackass"
  s.platform         = :ios, "8.0"
  s.source           = { :git => "https://github.com/mwkirk/MWKCoreData.git", :tag => "#{s.version}" }
  s.source_files     = "Source/*.{h,m}"
  s.frameworks       = "CoreData"
  s.requires_arc     = true
end

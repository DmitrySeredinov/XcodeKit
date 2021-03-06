Pod::Spec.new do |s|
  s.name = "XcodeKit"
  s.version = "2.0.1"
  s.summary = "A library to read and write Xcode project files"
  s.homepage = "https://github.com/PodBuilder/XcodeKit"
  s.license = 'MIT'
  s.authors = { "William Kent" => "gmail.com:wjk011" }
  s.source = { :git => "https://github.com/PodBuilder/XcodeKit.git", :tag => "2.0.1" }
  s.platform = :osx, '10.9'
  s.source_files = 'XcodeKit/*.{h,m}'
  s.requires_arc = true
end

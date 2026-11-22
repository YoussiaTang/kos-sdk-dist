Pod::Spec.new do |s|
  s.name = 'KOSSDK'
  s.version = '1.0.5'
  s.summary = 'KOS native H5 container SDK'
  s.homepage = 'https://github.com/YoussiaTang/kos-sdk-dist'
  s.license = { :type => 'Commercial', :text => 'Copyright KOS. All rights reserved.' }
  s.author = 'KOS'
  s.source = { :http => "https://github.com/YoussiaTang/kos-sdk-dist/releases/download/v#{s.version}/KOSSDK-#{s.version}.xcframework.zip", :sha256 => '7d34e29ec95f50fc7357d1832e2f77a73a27d0de1bea11524c5f2f6cda2746e1' }
  s.platform = :ios, '15.0'
  s.vendored_frameworks = 'KOSSDK.xcframework'
  s.frameworks = 'UIKit', 'WebKit', 'ImageIO', 'Photos', 'AVFoundation', 'CoreMedia'
  s.requires_arc = true
  s.static_framework = false
end

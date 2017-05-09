Pod::Spec.new do |s|
  s.name         = "Layout"
  s.version      = "0.1.0"
  s.summary      = "Layout system"

  s.homepage     = "https://github.schibsted.io/layout/"
  s.author       = "Nick Lockwood"

  s.ios.deployment_target = '9.0'
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '3.1' }

  s.source       = { :git => "git@github.schibsted.io:rocket/layout.git", :tag => s.version }
  s.requires_arc = true
  
  s.source_files  = "Layout/*.swift"
  s.dependency 'Expression', '~> 0.5.0'
end

Pod::Spec.new do |s|
  s.name               = "Layout"
  s.version            = "0.3.5"
  s.summary            = "XML templates + expression-based layout system"

  s.homepage           = "https://github.schibsted.io/Rocket/layout/"
  s.license            = {
    :type => 'Internal',
    :text => "Copyright (c) #{Time.new.year} Schibsted Media Group. All rights reserved"
  }
  s.author             = {
    "Nick Lockwood" => "nick.lockwood@schibsted.com"
  }
  s.source             = {
    :git => 'git@github.schibsted.io:Rocket/layout.git', 
    :tag => s.version.to_s
  }
  s.default_subspecs   = "Core"
  
  s.subspec 'Core' do |core|
    core.source_files = "Layout/*.swift"
    core.ios.deployment_target = '9.0'
  end
  
  s.subspec 'CLI' do |cli|
    cli.preserve_paths = "LayoutTool/LayoutTool"
  end
    
  s.pod_target_xcconfig = { 'SWIFT_VERSION' => '3.1' }

  s.requires_arc = true
end

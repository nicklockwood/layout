Pod::Spec.new do |s|
  s.name         = "Northstar"
  s.version      = "0.0.1"
  s.summary      = "Controls and views implementing the Northstar look and feel."
  s.homepage     = "http://schibsted.com"
  s.license      = { "type" => "Proprietary", "text" => "Copyright Schibsted All rights reserved.\n\n" }
  s.author       = "Schibsted"
  s.platform     = :ios, "9.0"
  s.source       = { :path => '.' }
  s.source_files = "Source"
  s.resource_bundles = {
    'Northstar' => ['Resources/*']
  }
end

Pod::Spec.new do |s|
  s.name         = "DEjson"
  s.version      = "5.0.0"
  s.summary      = "JSON parser and serializer in pure swift."
  s.description  = <<-DESC
                    Error resilient JSON parser and serializer in pure swift.
                    -> Parses JSON files with minor errors (additional commas, etc.)
                    -> Serializes JSON in minified and pretty printed formats
                   DESC

  s.homepage     = "https://github.com/anfema/DEjson"
  s.license      = { :type => "BSD", :file => "LICENSE.txt" }
  s.author             = { "Johannes Schriewer" => "j.schriewer@anfe.ma" }
  s.social_media_url   = "http://twitter.com/dunkelstern"

  s.ios.deployment_target = "13.0"
  s.osx.deployment_target = "11.0"
  s.swift_version = '5.5'
  
  s.source       = { :git => "https://github.com/anfema/DEjson.git", :tag => "5.0.0" }
  s.source_files  = "Sources/*.swift"

end

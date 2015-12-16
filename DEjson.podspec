Pod::Spec.new do |s|
  s.name         = "DEjson"
  s.version      = "1.0.1"
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

  s.ios.deployment_target = "8.4"
  s.osx.deployment_target = "10.10"

  s.source       = { :git => "https://github.com/anfema/DEjson.git", :tag => "1.0.1" }
  s.source_files  = "Sources/*.swift"
  
end

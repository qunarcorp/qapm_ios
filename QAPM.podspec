Pod::Spec.new do |s|
s.name = "QAPM"
s.version = "0.0.1"
s.summary = "QAPMLib组件库"
s.description = <<-DESC
QAPM
DESC
s.homepage = "http://www.qunar.com"
s.author = { "mobi" => "mobi@qunar.com" }
s.platform = :ios, "6"
s.license      = "Copyright 2015 Qunar.com"

#对于下边的s.source部分，不需要用户进行编辑，发布平台会自动处理
s.source = { :git => "git@github.com:qunarcorp/qapm_ios.git", :tag => s.version.to_s}
#如果包含头文件，请将下边的注释去掉
s.source_files = "QAPM/**/*.{h,m}", "$(PODS_ROOT)/**/*.h"
#s.exclude_files = "Classes/Exclude"
s.public_header_files = "library/**/*.h"
end

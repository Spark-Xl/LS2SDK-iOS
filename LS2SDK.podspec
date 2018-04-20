#
# Be sure to run `pod lib lint LS2SDK.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'LS2SDK'
  s.version          = '0.7.1'
  s.summary          = 'A short description of LS2SDK.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/jdkizer9/LS2SDK'
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'Apache 2.0', :file => 'LICENSE' }
  s.author           = { 'jdkizer9' => 'jdkizer9@users.noreply.github.com' }
  s.source           = { :git => 'https://github.com/jdkizer9/LS2SDK.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '10.0'
  s.swift_version = '4.1'

  s.subspec 'Core' do |core|
    core.source_files = 'Source/Core/**/*'
    core.dependency 'Alamofire', '~> 4'
    core.dependency 'ResearchSuiteExtensions', '~> 0.14'
    core.dependency 'Gloss', '~> 2.0'
  end

  s.subspec 'RKSupport' do |rks|
    rks.source_files = 'Source/RKSupport/**/*'
    rks.dependency 'LS2SDK/Core'
    rks.dependency 'ResearchKit', '~> 1.5'
  end

  s.subspec 'RSTBSupport' do |rstb|
    rstb.source_files = 'Source/RSTBSupport/**/*'
    rstb.dependency 'LS2SDK/Core'
    rstb.dependency 'LS2SDK/RKSupport'
    rstb.dependency 'ResearchSuiteTaskBuilder'
  end

  s.subspec 'RSRPSupport' do |rsrp|
    rsrp.source_files = 'Source/RSRPSupport/**/*'
    rsrp.dependency 'LS2SDK/Core'
    rsrp.dependency 'ResearchSuiteResultsProcessor', '~> 0.8'
  end

  # s.default_subspec = 'Core'

end

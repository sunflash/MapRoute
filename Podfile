# Uncomment this line to define a global platform for your project
platform :ios, '13.0'
use_frameworks!
inhibit_all_warnings!

abstract_target 'Map' do

    pod 'SwiftyJSON'
    pod 'RealmSwift', '~> 5.0'
    pod 'SwiftLint'

    target 'MapRoute' do
    end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '13.0'
      config.build_settings["EXCLUDED_ARCHS[sdk=iphonesimulator*]"] = "arm64"
    end
  end
end

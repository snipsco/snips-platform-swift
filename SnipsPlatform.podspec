Pod::Spec.new do |s|
  s.name = 'SnipsPlatform'
  s.version = '0.52.0-SNAPSHOT'
  s.summary = 'The Swift framework for the Snips Platform'
  s.description = <<-DESC
    The Snips Voice Platform allows anyone to integrate AI powered voice interaction in their devices with ease.
    The end-to-end pipeline - Hotword detection, Automatic Speech Recognition (ASR) and
    Natural Language Understanding (NLU) - runs fully on device, powered by state of the art deep learning.
    By using Snips, you can avoid cloud provider costs, cloud latency, and protect user’s privacy.
  DESC
  s.homepage = 'https://github.com/snipsco/snips-platform-swift'
  s.license =  'Apache 2.0 / MIT'
  s.author = { 'Snips' => 'contact@snips.ai' }

  s.ios.deployment_target = '9.0'

  s.source = {
    :git => 'https://github.com/snipsco/snips-platform-swift.git',
    :tag => s.version.to_s
  }
  s.source_files  = 'SnipsPlatform/*.{swift,h}'
  s.preserve_paths = 'Dependencies'

  s.prepare_command = <<-CMD
    mkdir -p Dependencies/ios && cd "$_"
    curl -s https://s3.amazonaws.com/snips/snips-platform-dev/snips-platform-ios.#{s.version.to_s}.tgz | tar zxv
    CMD
  s.pod_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO',
    'SWIFT_INCLUDE_PATHS' => '"${SRCROOT}/SnipsPlatform/Dependencies/ios"',
    'LIBRARY_SEARCH_PATHS' => '"${SRCROOT}/SnipsPlatform/Dependencies/ios"',
    'OTHER_LDFLAGS' => '"-force_load ${SRCROOT}/SnipsPlatform/Dependencies/ios/libtensorflow.a"',
  }

  s.frameworks = 'Accelerate'
  s.libraries = 'c++', 'resolv', 'iconv', 'protobuf', 'snips_kaldi'

end

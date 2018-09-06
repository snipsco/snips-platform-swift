Pod::Spec.new do |s|
  s.name = 'SnipsPlatformObjC'
  s.version = '0.59.0-RC2'
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

  s.ios.deployment_target = '11.0'

  s.source = {
    :git => 'https://github.com/snipsco/snips-platform-swift.git',
    :branch => 'objc'
  }
  s.source_files  = 'SnipsPlatformObjC/*.{swift,h}'
  s.dependency 'SnipsPlatform', '0.59.0-RC2'
  s.pod_target_xcconfig = {
    'ENABLE_BITCODE' => 'NO',
    'VALID_ARCHS' => 'arm64',
  }

end

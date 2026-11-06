# Local pod for the speech engine: the prebuilt VOICEVOX core (C API) and the VOICEVOX build of
# ONNX Runtime, released by the VOICEVOX project (core: MIT License; ONNX Runtime build: the
# VOICEVOX ONNX Runtime terms of use, which allow it inside an app). The two
# xcframeworks are not in git; the voice build tool downloads them (pinned version and sha256)
# into this folder. The Podfile adds this pod only when both are present.
Pod::Spec.new do |s|
  s.name         = 'VoicevoxCore'
  s.version      = '0.17.1'
  s.summary      = 'VOICEVOX core C API with VOICEVOX ONNX Runtime (prebuilt xcframeworks).'
  s.homepage     = 'https://github.com/VOICEVOX/voicevox_core'
  s.license      = { :type => 'MIT (VOICEVOX core); VOICEVOX ONNX Runtime terms of use' }
  s.author       = 'VOICEVOX'
  s.source       = { :path => '.' }
  # The official xcframeworks declare MinimumOSVersion 16.2.
  s.platform     = :ios, '16.2'
  s.vendored_frameworks = 'voicevox_core.xcframework', 'voicevox_onnxruntime.xcframework'
end

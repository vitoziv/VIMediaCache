Pod::Spec.new do |s|
    s.name = 'VIMediaCache'
    s.version = '0.1'
    s.license = 'MIT'
    s.summary = 'VIMediaCache is a tool to cache media file while play media using AVPlayer'
    s.homepage = 'https://github.com/vitoziv/VIMediaCache'
    s.author = { 'Vito' => 'vvitozhang@gmail.com' }
    s.source = { :git => 'https://github.com/vitoziv/VIMediaCache.git', :tag => s.version.to_s }
    s.platform = :ios, '7.0'
    s.source_files = 'VIMediaCache/*.{h,m}', 'VIMediaCache/**/*.{h,m}'
    s.frameworks = 'MobileCoreServices', 'AVFoundation'
    s.requires_arc = true
end


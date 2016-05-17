Pod::Spec.new do |s|
    s.name = 'MTMediaCache'
    s.version = '0.1'
    s.license = 'MIT'
    s.summary = 'VIMediaCache is a tool to cache media file while play media using AVPlayer'
    s.homepage = 'https://www.github.com/vitoziv/VIMediaCache'
    s.author = { 'Vito' => 'vvitozhang@gmail.com' }
    s.source = { :git => 'https://www.github.com/vitoziv/VIMediaCache.git' }
    s.platform = :ios, '7.0'
    s.source_files = 'MTMediaCache/*.{h,m}', 'MTMediaCache/**/*.{h,m}'
    s.frameworks = 'MobileCoreService', 'AVFoundation'
    s.requires_arc = true
end


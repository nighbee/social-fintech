/// Feed API uses `video_1080p_url`; POST /feed/media/upload returns `url`.
Object? readVideo1080pOrUrl(Map<Object?, Object?> json, String key) =>
    json['video_1080p_url'] ?? json['url'] ?? '';

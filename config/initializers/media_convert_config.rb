Settings.encoding.media_convert ||= Config::Options.new
Settings.encoding.media_convert.configuration = {
  mapping: {'1080' => 'high', '720' => 'medium', '540' => 'low'},
  options: {
    'avalon' => {
      media_type: :video,
      outputs: [
        {preset: "System-Avc_16x9_1080p_29_97fps_8500kbps", modifier: "-1080"},
        {preset: "System-Avc_16x9_720p_29_97fps_5000kbps", modifier: "-720"},
        {preset: "System-Avc_16x9_540p_29_97fps_3500kbps", modifier: "-540"}
      ]
    },
    'fullaudio' => {
      media_type: :audio,
      outputs: [
        {preset: "avr-audio-high", modifier: "-high"},
        {preset: "avr-audio-medium", modifier: "-medium"}
      ]
    }
  }
}
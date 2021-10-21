Settings.encoding.media_convert ||= Config::Options.new
Settings.encoding.media_convert.configuration = {
  mapping: {'1080' => 'high', '720' => 'medium', '540' => 'low'},
  options: {
    'avalon' => {
      media_type: :video,
      outputs: [
        {preset: "avr-video-high", modifier: "-1080"},
        {preset: "avr-video-medium", modifier: "-720"},
        {preset: "avr-video-low", modifier: "-540"}
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
class Preset < ApplicationRecord
  enum preset_context: {
    hidden_genre: 'hidden_genre',
    stream_guest: 'stream_guest'
  }
end

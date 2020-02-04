class Setting < ApplicationRecord

  OPTIONS = {
    disable_sign_up: '0',
    disable_verification: '0',
    disable_live_video: '0',
    disable_merch_upload: '0',
    audio_reminder_tracks_count: '10'
  }
end

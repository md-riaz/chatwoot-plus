import { AUDIO_FORMATS } from 'shared/constants/messages';

export const getAudioRecordFormat = ({
  isAWhatsAppCloudChannel = false,
  isAWhatsAppChannel = false,
  isATelegramChannel = false,
  isAPIInbox = false,
} = {}) => {
  if (isAWhatsAppCloudChannel) {
    return AUDIO_FORMATS.OGG;
  }

  if (isAWhatsAppChannel || isATelegramChannel) {
    return AUDIO_FORMATS.MP3;
  }

  if (isAPIInbox) {
    return AUDIO_FORMATS.MP3;
  }

  return AUDIO_FORMATS.WAV;
};

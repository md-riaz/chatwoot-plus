import { AUDIO_FORMATS } from 'shared/constants/messages';
import { getAudioRecordFormat } from '../audioRecordFormat';

describe('#getAudioRecordFormat', () => {
  it('uses OGG for WhatsApp Cloud channels', () => {
    expect(
      getAudioRecordFormat({
        isAWhatsAppCloudChannel: true,
        isAWhatsAppChannel: true,
      })
    ).toBe(AUDIO_FORMATS.OGG);
  });

  it.each([
    ['WhatsApp', { isAWhatsAppChannel: true }],
    ['Telegram', { isATelegramChannel: true }],
    ['API inbox', { isAPIInbox: true }],
  ])('uses MP3 for %s audio recordings', (_name, flags) => {
    expect(getAudioRecordFormat(flags)).toBe(AUDIO_FORMATS.MP3);
  });

  it('uses WAV for other channels', () => {
    expect(getAudioRecordFormat()).toBe(AUDIO_FORMATS.WAV);
  });
});

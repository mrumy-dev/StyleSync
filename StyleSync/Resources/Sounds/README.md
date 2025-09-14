# Premium Sound Effects for StyleSync

This directory contains high-quality sound effects designed for the StyleSync app. All sounds are optimized for iOS and provide subtle, premium audio feedback.

## Sound Files

### Interactive Sounds
- `tap.wav` - Light tap for button presses
- `click.wav` - Crisp click for confirmations
- `subtleBeep.wav` - Gentle interaction feedback
- `pop.wav` - Playful pop sound

### Transition Sounds
- `whoosh.wav` - Smooth transitions and swipes
- `swipeSound.wav` - Gesture feedback
- `elasticSnap.wav` - Spring/elastic interactions

### Feedback Sounds
- `success.wav` - Success confirmation
- `error.wav` - Error notification
- `chime.wav` - Gentle notification
- `notification.wav` - Alert sound

### Special Effects
- `cameraShutter.wav` - Premium camera shutter sound
- `celebration.wav` - Achievement/celebration fanfare
- `magicChime.wav` - Magical sparkle effect

## Sound Design Principles

1. **Subtle & Premium**: All sounds are designed to be pleasant and non-intrusive
2. **Short Duration**: Most sounds are under 0.5 seconds for quick feedback
3. **High Quality**: 44.1kHz, 16-bit WAV files for crisp audio
4. **Volume Optimized**: Pre-balanced for consistent volume levels
5. **iOS Optimized**: Compatible with iOS audio session management

## Usage

Sounds are automatically loaded by the SoundManager and can be triggered using:

```swift
SoundManager.SoundType.cameraShutter.play(volume: 0.8)
```

## Credits

Sound effects designed for premium iOS applications with attention to Apple's Human Interface Guidelines.
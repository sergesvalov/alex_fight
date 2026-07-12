import wave
import struct
import math

def generate_square_wave(frequency, duration, sample_rate=44100, amplitude=8000):
    num_samples = int(duration * sample_rate)
    samples = []
    for i in range(num_samples):
        # Square wave
        val = amplitude if math.sin(2 * math.pi * frequency * i / sample_rate) > 0 else -amplitude
        samples.append(val)
    return samples

def main():
    sample_rate = 44100
    # A simple cheerful 8-bit melody: C4, E4, G4, C5, G4, E4
    notes = [
        (261.63, 0.2), # C4
        (329.63, 0.2), # E4
        (392.00, 0.2), # G4
        (523.25, 0.2), # C5
        (392.00, 0.2), # G4
        (329.63, 0.2), # E4
        (261.63, 0.2), # C4
        (392.00, 0.2), # G4
        (440.00, 0.4), # A4
        (392.00, 0.4), # G4
    ]
    
    all_samples = []
    for freq, duration in notes:
        # play note
        all_samples.extend(generate_square_wave(freq, duration * 0.8, sample_rate))
        # brief pause
        all_samples.extend([0] * int(0.2 * duration * sample_rate))
        
    # Repeat a few times
    all_samples = all_samples * 2
    
    with wave.open("assets/audio/elevator_music.wav", "w") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(sample_rate)
        for s in all_samples:
            wav_file.writeframes(struct.pack('h', int(s)))

if __name__ == "__main__":
    main()

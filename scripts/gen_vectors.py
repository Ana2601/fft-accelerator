#!/usr/bin/env python3
"""Generate FFT input frames: impulse, DC, single tones, two-tone, random noise, full-scale square."""
import math
import random
import sys


def q15(x):
    return max(-32768, min(32767, int(round(x * 32767))))


def main(n, frames, path, seed=1):
    rng = random.Random(seed)
    sigs = []
    sigs.append([(0.99 if i == 0 else 0.0, 0.0) for i in range(n)])                  # impulse
    sigs.append([(0.5, -0.25)] * n)                                                   # DC
    for b in (1, 7, n // 4, n // 2 - 1):                                              # bin-centred tones
        sigs.append([(0.9 * math.cos(2 * math.pi * b * i / n), 0.9 * math.sin(2 * math.pi * b * i / n)) for i in range(n)])
    sigs.append([(0.45 * math.cos(2 * math.pi * 10.3 * i / n) + 0.45 * math.cos(2 * math.pi * 37 * i / n), 0.0) for i in range(n)])
    sigs.append([(0.99 if (i // 8) % 2 else -0.99, 0.0) for i in range(n)])          # full-scale square
    while len(sigs) < frames:
        a = rng.choice([0.05, 0.3, 0.7, 0.99])
        sigs.append([(rng.uniform(-a, a), rng.uniform(-a, a)) for _ in range(n)])
    with open(path, "w") as f:
        for s in sigs:
            f.write(" ".join(f"{q15(re) & 0xFFFF:04x}{q15(im) & 0xFFFF:04x}" for re, im in s) + "\n")
    print(f"wrote {len(sigs)} frames of {n} points to {path}")


if __name__ == "__main__":
    main(int(sys.argv[1]), int(sys.argv[2]), sys.argv[3])

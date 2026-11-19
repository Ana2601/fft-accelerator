#!/usr/bin/env python3
"""Compare RTL FFT output against numpy (double precision) FFT(x)/N.

Reports per-frame SQNR and max error in LSBs; fails if any frame is worse
than the limits below (chosen for 8 stages of Q1.15 with per-stage rounding).
"""
import sys

import numpy as np

MAX_ERR_LSB = 6.0
MIN_SQNR_DB = 35.0          # fixed 1/N block scaling limits SQNR on low-amplitude broadband input


def s16(x):
    return x - 0x10000 if x & 0x8000 else x


def load(path):
    return [np.array([complex(s16(int(w, 16) >> 16), s16(int(w, 16) & 0xFFFF)) for w in line.split()])
            for line in open(path) if line.strip()]


def main(n, inp, out):
    xs, ys = load(inp), load(out)
    assert len(xs) == len(ys), f"{len(xs)} input frames but {len(ys)} output frames"
    worst_err, worst_sqnr, fails = 0.0, 1e9, 0
    for f, (x, y) in enumerate(zip(xs, ys)):
        ref = np.fft.fft(x) / n
        err = y - ref
        max_err = float(np.max(np.abs(err)))
        p_sig, p_err = float(np.sum(np.abs(ref) ** 2)), float(np.sum(np.abs(err) ** 2))
        sqnr = 10 * np.log10(p_sig / p_err) if p_err > 0 else 200.0
        peak = int(np.argmax(np.abs(y)))
        check_sqnr = float(np.max(np.abs(ref))) > 200      # skip SQNR on near-silent outputs
        ok = max_err <= MAX_ERR_LSB and (not check_sqnr or sqnr >= MIN_SQNR_DB)
        fails += not ok
        worst_err = max(worst_err, max_err)
        if check_sqnr:
            worst_sqnr = min(worst_sqnr, sqnr)
        if f < 9 or not ok:
            print(f"frame {f:3d}: max err {max_err:5.2f} LSB  SQNR {sqnr:6.1f} dB  peak bin {peak:3d}  {'ok' if ok else 'FAIL'}")
    print(f"{len(xs)} frames: worst max-error {worst_err:.2f} LSB, worst SQNR {worst_sqnr:.1f} dB, {fails} failing")
    if fails:
        sys.exit("TEST FAILED")
    print("TEST PASSED")


if __name__ == "__main__":
    main(int(sys.argv[1]), sys.argv[2], sys.argv[3])

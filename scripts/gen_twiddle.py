#!/usr/bin/env python3
"""Write the twiddle ROM: W_N^k = exp(-2*pi*i*k/N), k = 0..N/2-1, Q1.15, {re, im} per line."""
import math
import sys


def q15(x):
    return max(-32768, min(32767, int(round(x * 32768))))


def main(n, path):
    with open(path, "w") as f:
        for k in range(n // 2):
            re = q15(math.cos(2 * math.pi * k / n)) & 0xFFFF
            im = q15(-math.sin(2 * math.pi * k / n)) & 0xFFFF
            f.write(f"{re:04x}{im:04x}\n")


if __name__ == "__main__":
    main(int(sys.argv[1]), sys.argv[2])

`timescale 1ns/1ps
// Streams frames through the FFT with random valid/ready stalls and dumps the
// output bins; scripts/check.py compares them against numpy.
module tb_fft;
    parameter integer N = 256;
    parameter         TW_FILE = "rtl/twiddle_256.hex";

    reg clk = 0, rst_n = 0;
    always #5 clk = ~clk;

    reg         in_valid = 0, out_ready = 0;
    reg  [15:0] in_re = 0, in_im = 0;
    wire        in_ready, out_valid, out_last, busy;
    wire [15:0] out_re, out_im;

    fft_core #(.N(N), .TW_FILE(TW_FILE)) dut (.*);

    reg [31:0] frame [0:N-1];
    integer fin, fout, r, i, frames = 0, cyc = 0, t0, t_sum = 0, got;
    string in_file, out_file;
    always @(posedge clk) cyc <= cyc + 1;

    initial begin
        if (!$value$plusargs("in=%s", in_file))   in_file  = "build/in.txt";
        if (!$value$plusargs("out=%s", out_file)) out_file = "build/out.txt";
        fin = $fopen(in_file, "r"); fout = $fopen(out_file, "w");
        repeat (4) @(posedge clk);
        rst_n = 1;
        while (1) begin
            for (i = 0; i < N; i = i + 1) begin
                r = $fscanf(fin, "%h", frame[i]);
                if (r != 1) break;
            end
            if (r != 1) break;
            t0 = cyc;
            for (i = 0; i < N; i = i + 1) begin
                while ($urandom_range(0, 7) == 0) begin in_valid <= 0; @(posedge clk); end
                in_valid <= 1; {in_re, in_im} <= frame[i];
                @(posedge clk);
                while (!in_ready) @(posedge clk);
            end
            in_valid <= 0;
            got = 0;
            while (got < N) begin
                out_ready <= ($urandom_range(0, 7) != 0);
                @(posedge clk);
                if (out_valid && out_ready) begin
                    $fwrite(fout, "%04x%04x%s", out_re, out_im, out_last ? "\n" : " ");
                    if (out_last != (got == N - 1)) $fatal(1, "out_last misplaced");
                    got = got + 1;
                end
            end
            out_ready <= 0;
            t_sum = t_sum + (cyc - t0);
            frames = frames + 1;
        end
        $fclose(fout);
        $display("FFT-%0d: %0d frames, avg %0d cycles/frame incl. random stalls (ideal %0d)",
                 N, frames, t_sum / frames, 2 * N + (N / 2) * $clog2(N));
        $finish;
    end
endmodule

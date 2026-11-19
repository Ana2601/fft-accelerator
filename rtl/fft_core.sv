// In-place radix-2 decimation-in-time FFT, N points, Q1.15 complex samples.
//
//  * LOAD:    N samples on a valid/ready stream, written in bit-reversed order
//  * COMPUTE: log2(N) stages x N/2 butterflies, one butterfly per clock
//  * UNLOAD:  N bins streamed out in natural order (valid/ready, last on bin N-1)
//
// Every butterfly output is halved (unconditional block scaling), so the
// result is FFT(x)/N and can never overflow.  Products are rounded to nearest.
// Throughput: N + (N/2)*log2(N) + N cycles per transform (no overlap).
module fft_core #(
    parameter integer N       = 256,
    parameter         TW_FILE = "twiddle_256.hex"
) (
    input  wire        clk,
    input  wire        rst_n,

    input  wire        in_valid,
    output wire        in_ready,
    input  wire [15:0] in_re,
    input  wire [15:0] in_im,

    output wire        out_valid,
    input  wire        out_ready,
    output wire [15:0] out_re,
    output wire [15:0] out_im,
    output wire        out_last,
    output wire        busy
);
    localparam integer L = $clog2(N);
    localparam [1:0] S_LOAD = 2'd0, S_COMP = 2'd1, S_OUT = 2'd2;

    reg signed [15:0] mem_re [0:N-1];
    reg signed [15:0] mem_im [0:N-1];
    reg        [31:0] tw_rom [0:N/2-1];
    initial $readmemh(TW_FILE, tw_rom);

    reg [1:0]   st;
    reg [L-1:0] cnt;          // load / unload index
    reg [L-1:0] stage;
    reg [L-2:0] bfly;

    function automatic [L-1:0] bitrev(input [L-1:0] x);
        integer i;
        for (i = 0; i < L; i = i + 1) bitrev[i] = x[L-1-i];
    endfunction

    // ---------------------------------------------------------- butterfly addressing
    wire [L-1:0] half  = {{(L-1){1'b0}}, 1'b1} << stage;
    wire [L-1:0] kmask = half - 1'b1;
    wire [L-1:0] k     = {1'b0, bfly} & kmask;
    wire [L-1:0] grp   = ({1'b0, bfly} >> stage) << (stage + 1'b1);
    wire [L-1:0] i0    = grp | k;
    wire [L-1:0] i1    = i0 + half;
    wire [L-2:0] tw_ix = k << (L - 1 - stage);

    wire signed [15:0] w_re = tw_rom[tw_ix][31:16];
    wire signed [15:0] w_im = tw_rom[tw_ix][15:0];
    wire signed [15:0] a_re = mem_re[i0], a_im = mem_im[i0];
    wire signed [15:0] b_re = mem_re[i1], b_im = mem_im[i1];

    // t = W * b  (Q1.15 x Q1.15 -> Q2.30, round to Q1.15 with one guard bit kept)
    wire signed [32:0] p_re = w_re * b_re - w_im * b_im;
    wire signed [32:0] p_im = w_re * b_im + w_im * b_re;
    wire signed [17:0] t_re = (p_re + 33'sd16384) >>> 15;
    wire signed [17:0] t_im = (p_im + 33'sd16384) >>> 15;

    // (a +/- t) / 2 with rounding (operands kept signed: a concatenation would be unsigned)
    wire signed [18:0] ax_re = a_re, ax_im = a_im;
    wire signed [18:0] tx_re = t_re, tx_im = t_im;
    wire signed [18:0] s0_re = ax_re + tx_re + 19'sd1;
    wire signed [18:0] s0_im = ax_im + tx_im + 19'sd1;
    wire signed [18:0] s1_re = ax_re - tx_re + 19'sd1;
    wire signed [18:0] s1_im = ax_im - tx_im + 19'sd1;

    function automatic [15:0] sat_half(input signed [18:0] v);
        reg signed [17:0] h;
        begin
            h = v >>> 1;
            sat_half = (h > 18'sd32767) ? 16'h7FFF : (h < -18'sd32768) ? 16'h8000 : h[15:0];
        end
    endfunction

    // ---------------------------------------------------------- control
    assign in_ready  = (st == S_LOAD);
    assign out_valid = (st == S_OUT);
    assign out_re    = mem_re[cnt];
    assign out_im    = mem_im[cnt];
    assign out_last  = (st == S_OUT) && (cnt == N - 1);
    assign busy      = (st != S_LOAD) || (cnt != 0);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_LOAD; cnt <= {L{1'b0}}; stage <= {L{1'b0}}; bfly <= {(L-1){1'b0}};
        end else begin
            case (st)
                S_LOAD: if (in_valid) begin
                    mem_re[bitrev(cnt)] <= in_re;
                    mem_im[bitrev(cnt)] <= in_im;
                    cnt <= cnt + 1'b1;
                    if (cnt == N - 1) begin
                        st <= S_COMP; stage <= {L{1'b0}}; bfly <= {(L-1){1'b0}};
                    end
                end

                S_COMP: begin
                    mem_re[i0] <= sat_half(s0_re);
                    mem_im[i0] <= sat_half(s0_im);
                    mem_re[i1] <= sat_half(s1_re);
                    mem_im[i1] <= sat_half(s1_im);
                    bfly <= bfly + 1'b1;
                    if (&bfly) begin
                        stage <= stage + 1'b1;
                        if (stage == L - 1) begin st <= S_OUT; cnt <= {L{1'b0}}; end
                    end
                end

                default: if (out_ready) begin            // S_OUT
                    cnt <= cnt + 1'b1;
                    if (cnt == N - 1) st <= S_LOAD;
                end
            endcase
        end
    end
endmodule

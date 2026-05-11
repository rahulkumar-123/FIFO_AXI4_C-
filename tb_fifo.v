`timescale 1ns / 1ps

module tb_fifo_sync_axi4s;

    // Parameters
    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 4;
    parameter DEPTH = 1 << ADDR_WIDTH;

    // Signals
    reg                   clk;
    reg                   rst_n;

    // slave side
    reg  [DATA_WIDTH-1:0] s_axis_tdata;
    reg  [(DATA_WIDTH/8)-1:0] s_axis_tkeep;
    reg                   s_axis_tvalid;
    wire                  s_axis_tready;
    reg                   s_axis_tlast;

    // master side
    wire [DATA_WIDTH-1:0] m_axis_tdata;
    wire [(DATA_WIDTH/8)-1:0] m_axis_tkeep;
    wire                  m_axis_tvalid;
    reg                   m_axis_tready;
    wire                  m_axis_tlast;
    
    // flags
    wire                  almost_full;
    wire                  almost_empty;

    // tap internal signals for waveform visibility
    wire                  fifo_full  = dut.full;
    wire                  fifo_empty = dut.empty;

    // DUT Instantiation
    fifo_sync_axi4s #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tkeep(s_axis_tkeep),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tready(s_axis_tready),
        .s_axis_tlast(s_axis_tlast),
        .m_axis_tdata(m_axis_tdata),
        .m_axis_tkeep(m_axis_tkeep),
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tlast(m_axis_tlast),
        .almost_full(almost_full),
        .almost_empty(almost_empty)
    );

    // basic clk
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // file I/O
    integer fd_in;
    integer fd_out;
    integer scan_in;
    
    // main ctrl
    initial begin
        // init
        rst_n = 0;
        s_axis_tdata = 0;
        s_axis_tkeep = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;
        m_axis_tready = 0;

        // setup files
        fd_in = $fopen("input_vectors.txt", "r");
        if (fd_in == 0) begin
            $display("err: no input_vectors.txt");
            $finish;
        end
        
        fd_out = $fopen("actual_output.txt", "w");
        if (fd_out == 0) begin
            $display("err: no actual_output.txt");
            $finish;
        end

        // waves
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_fifo_sync_axi4s);

        // bounce reset
        #20 rst_n = 1;
    end

    // feed the beast (write)
    initial begin
        wait(rst_n == 1);
        #10;
        // keep pumping til eof
        while (!$feof(fd_in)) begin
            @(posedge clk);
            // Randomly assert valid
            if (($random % 100) > 30) begin // 70% chance to be valid
                scan_in = $fscanf(fd_in, "%h %h %d\n", s_axis_tdata, s_axis_tkeep, s_axis_tlast);
                if (scan_in == 3) begin
                    s_axis_tvalid = 1;
                    // Wait until ready
                    wait(s_axis_tready == 1);
                    @(posedge clk);
                    // Deassert immediately after successful transaction to introduce randomness 
                    // or continue to next if next random check passes.
                    s_axis_tvalid = 0; 
                end
            end else begin
                s_axis_tvalid = 0;
            end
        end
        s_axis_tvalid = 0;
    end

    // Receive data (Read from FIFO)
    // Removed legacy process to avoid duplicate $fwrite
    
    // read pump
    always @(posedge clk) begin
        if (rst_n) begin
            m_axis_tready <= ($random % 100) > 40; // 60% rdy
            
            // snarf data if handshake passed
            if (m_axis_tvalid && m_axis_tready) begin
                $fwrite(fd_out, "%0x %0x %d\n", m_axis_tdata, m_axis_tkeep, m_axis_tlast);
            end
        end
    end

    // timeout safety
    // We assume test finishes shortly after all inputs are written and output files are generated.
    reg [31:0] timeout_cnt;
    always @(posedge clk) begin
        if (!rst_n) timeout_cnt <= 0;
        else begin
            timeout_cnt <= timeout_cnt + 1;
            if (timeout_cnt > 100000) begin
                $display("Simulation Timeout");
                $fclose(fd_in);
                $fclose(fd_out);
                $finish;
            end
            if ($feof(fd_in) && dut.empty) begin
                // flush out any remaining data
                #100;
                $fclose(fd_in);
                $fclose(fd_out);
                $display("Simulation completed successfully.");
                $finish;
            end
        end
    end

endmodule

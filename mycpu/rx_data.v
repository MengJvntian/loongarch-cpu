`timescale 1ns / 1ps

`include "defines.vh"

module rx_data (
    input  wire         aclk,
    input  wire         aresetn,
    input  wire         clear,
    output reg          ready,
    output reg   [7:0]  rx

);
    localparam IDLE      = 5'b00000;
    localparam first     = 5'b00001;
    localparam second    = 5'b00010;
    localparam third     = 5'b00011;
    localparam fourth    = 5'b00100;
    localparam fifth     = 5'b00101;
    localparam sixth     = 5'b00110;
    localparam seventh   = 5'b00111;
    localparam eighth    = 5'b01000;
    localparam ninth     = 5'b01001;
    localparam IDLE0  = 5'b01010;
    localparam first0  = 5'b01011;
    localparam second0  = 5'b01100;
    localparam third0  = 5'b01101;
    localparam fourth0  = 5'b01110;
    localparam fifth0  = 5'b01111;
    localparam sixth0  = 5'b10000;
    localparam seventh0  = 5'b10001;
    localparam eighth0  = 5'b10010;
    localparam ninth0  = 5'b10011;
    localparam first1  = 5'b10100;
    localparam second1  = 5'b10101;
    localparam third1   = 5'b10110;
    localparam fourth1  = 5'b10111;
    localparam finish    = 5'b11000;

    reg [4:0] current_state;   
    reg [4:0] next_state;  
    
    always @(posedge aclk or negedge aresetn) begin
        if (!aresetn) current_state <= IDLE;
        else          current_state <= next_state;
    end
    
    always @(*) begin
        case (current_state)
            IDLE    :  next_state = first;
            first   : if (clear) next_state = second;
                      else       next_state = first;
            second  : if (clear) next_state = third;
                      else       next_state = second;
            third   : if (clear) next_state = fourth;
                      else       next_state = third;
            fourth  : if (clear) next_state = fifth;
                      else       next_state = fourth;
            fifth   : if (clear) next_state = sixth;
                      else       next_state = fifth;  
            sixth   : if (clear) next_state = seventh;
                      else       next_state = sixth;  
            seventh : if (clear) next_state = eighth;
                      else       next_state = seventh;   
            eighth  : if (clear) next_state = ninth;
                      else       next_state = eighth;   
            ninth   : if (clear) next_state = IDLE0;
                      else       next_state = ninth;   
            IDLE0   :  next_state = first0;
            first0   : if (clear) next_state = second0;
                      else       next_state = first0;
            second0  : if (clear) next_state = third0;
                      else       next_state = second0;
            third0  : if (clear) next_state = fourth0;
                      else       next_state = third0;
            fourth0  : if (clear) next_state = fifth0;
                      else       next_state = fourth0;
            fifth0   : if (clear) next_state = sixth0;
                      else       next_state = fifth0;  
            sixth0   : if (clear) next_state = seventh0;
                      else       next_state = sixth0;  
            seventh0 : if (clear) next_state = eighth0;
                      else       next_state = seventh0;   
            eighth0 : if (clear) next_state = ninth0;
                      else       next_state = eighth0;   
            ninth0   : if (clear) next_state = first1;
                      else       next_state = ninth0;  
            first1   : if (clear) next_state = second1;
                      else       next_state = first1;
            second1  : if (clear) next_state = third1;
                      else       next_state = second1;
            third1   : if (clear) next_state = fourth1;
                      else       next_state = third1;
            fourth1  : if (clear) next_state = finish;
                      else       next_state = fourth1;    
            finish  :   next_state = IDLE;
            default  :  next_state = IDLE;
        endcase
    end
    
    always @(*) begin
        if (!aresetn) begin
            ready    = 1'h0;
            rx       = 8'h0;
        end
        else begin
            case (current_state)
                first: begin
                            ready = 1'h1;
                            rx    = 8'h41;   
                        end
                second: begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                third: begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                fourth: begin
                            ready = 1'h1;
                            rx    = 8'h40;   
                        end
                fifth: begin
                            ready = 1'h1;
                            rx    = 8'h80;   
                        end
                sixth: begin
                            ready = 1'h1;
                            rx    = 8'h04;   
                        end
                seventh:begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                eighth:begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                ninth:begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                first0: begin
                            ready = 1'h1;
                            rx    = 8'h44;   
                        end
                second0: begin
                            ready = 1'h1;
                            rx    = 8'h33;   
                        end
                third0: begin
                            ready = 1'h1;
                            rx    = 8'h22;   
                        end
                fourth0: begin
                            ready = 1'h1;
                            rx    = 8'h11;   
                        end
                fifth0: begin
                            ready = 1'h1;
                            rx    = 8'h44;   
                        end
                sixth0: begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                seventh0:begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                eighth0:begin
                            ready = 1'h1;
                            rx    = 8'h40;   
                        end
                ninth0:begin
                            ready = 1'h1;
                            rx    = 8'h80;   
                        end
                first1: begin
                            ready = 1'h1;
                            rx    = 8'h04;   
                        end
                second1: begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                third1: begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                fourth1: begin
                            ready = 1'h1;
                            rx    = 8'h00;   
                        end
                default:begin
                            ready    = 1'h0;
                            rx       = 8'h0;
                        end
            endcase
        end
    end     

endmodule
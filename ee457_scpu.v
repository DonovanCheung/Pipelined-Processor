`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:30:57 03/22/2010 
// Design Name: 
// Module Name:    ee357_mcpu 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module ee457_scpu(
	// I/O interface to memory
	output 		[31:0] 	imem_addr,
	output 		[31:0] 	imem_wdata,
	output 					imemread,
	output 					imemwrite,
 	input			[31:0]	imem_rdata,

	output 		[31:0] 	dmem_addr,
	output 		[31:0] 	dmem_wdata,
	output 					dmemread,
	output 					dmemwrite,
	input			[31:0]	dmem_rdata,
	
	// Register File I/O for debug/checking purposes
	output		[4:0]		reg_ra,
	output		[4:0]		reg_rb,
	output		[4:0]		reg_wa,
	output		[31:0]	reg_radata,
	output		[31:0]	reg_rbdata,
	output		[31:0]	reg_wdata,
	output					regwrite,
	 
	// Clock and reset
  	input 					clk,
   input 					rst
   );

	// Use these for opcode decoding
	localparam OP_LW    = 6'b100011;
	localparam OP_SW    = 6'b101011;
	localparam OP_RTYPE = 6'b000000;
	localparam OP_BEQ   = 6'b000100;
	localparam OP_BNE   = 6'b000101;
	localparam OP_JMP   = 6'b000010;
	localparam OP_ADDI  = 6'b001000;
	localparam OP_JAL   = 6'b000011;
	localparam FUNC_ADD = 6'b100000;
	localparam FUNC_SUB = 6'b100010;
	localparam FUNC_AND = 6'b100100;
	localparam FUNC_OR  = 6'b100101;
	localparam FUNC_XOR = 6'b100110;
	localparam FUNC_NOR = 6'b100111;
	localparam FUNC_SLT = 6'b101010;
	localparam FUNC_SLL = 6'b000000;
	localparam FUNC_SRL = 6'b000010;
	localparam FUNC_SRA = 6'b000011;
	localparam FUNC_JR  = 6'b001000;
	
	// Control Signals
	wire 				jump;
   wire 				branch;
   wire 				memtoreg;
   wire 				regdst;
   wire 				alusrc;
   wire [1:0]		aluop;


	reg  [31:0]		pc;
	reg  [31:0]		pc_d;
	wire [31:0]		next_pc;
	wire [31:0] 	imm_sext;
	wire [31:0]		imm_sext_sh2;
	wire [31:0]		jump_target_pc;
	wire [31:0]		branch_target_pc;
	

	// Decode Register 
	reg [31:0]	pc_reg_id;
//	reg [4:0]	shamt;
	wire [5:0]		opcode;
	wire [4:0]		rs;
	wire [4:0]		rt;
	wire [4:0]		rd;
	wire [4:0]		shamt;	
	wire [5:0]		func;
	wire [15:0]		imm;
	wire [25:0]		jmpaddr;
	reg [31:0]		instruction;
	reg [5:0]		opcode_reg;
	reg [5:0]		func_reg;

	
	// Buffers
	wire dmemread_buf;
	wire dmemwrite_buf;
	wire regwrite_buf;
	wire memtoreg_buf;


	// EX/ALU Register
	reg [31:0]	pc_reg_ex;
	reg [31:0]	rdata1_reg;
	reg [31:0]	rdata2_reg;
	reg [31:0]	imm_reg_ex;
	reg [4:0]	rs_reg_ex;
	reg [4:0]	rt_reg_ex;
	reg [4:0]	rd_reg_ex;
	
	reg [9:0]	ex_reg_ex;
	reg [3:0]	mem_reg_ex;
	reg [1:0]	wb_reg_ex;


	// ALU signals
	wire 	[31:0]	alu_ina;
	wire 	[31:0]	alu_inb;
	reg	[5:0]		alu_func;
	wire	[31:0]	alu_res;
	wire 				sov;
	wire    			uov;
	wire				zero;
	wire 	[31:0] 	alu_mux_in0;


	//Forwarding Unit
	reg EX1;
	reg EX2;
	reg [1:0] ALUSelA;
	reg [1:0] ALUSelB;
	

	// MEM Register
	reg	[31:0]	pc_reg_mem;
	reg 				zero_reg;
	reg 	[31:0]	alures_mem;
	reg 	[31:0]	dmem_wdata_reg;
	reg 	[4:0]		reg_wa_mem;
	reg 	[3:0]		mem_reg_mem;
	reg 	[1:0]		wb_reg_mem;
	wire	[4:0]		reg_write_addr_wire;


	// WB Register
	reg [1:0]	wb_reg_wb;
	reg [31:0]	alures_wb;
	reg [31:0]  mem_rdata_wb;
	reg [4:0]	reg_wa_wb;
	reg [31:0]	reg_wdata_prev;
	reg [4:0]	reg_wa_prev;

	reg stall;
	
	initial
	begin 
		stall = 0;
	end
	
	always @*
	begin
		stall = 0;
		if (wb_reg_ex[1] == 1 && ex_reg_ex[8] == 0 && (reg_write_addr_wire == rs || reg_write_addr_wire == rt))
			// wb_re_ex[1] = regwrite in ID/EX, ex_reg_ex[8] = regdst in ID/EX
			stall = 1;
	end
	
	// PC process
	always @(posedge clk)
	begin
		if(rst == 1)
		begin
			pc <= 32'b0;
		end
		else 
		begin
			if (stall != 1)
			begin
				if(mem_reg_mem[3] == 1 && zero_reg == 1)	// || opcode == OP_BNE && zero == 0
					// mem_reg_mem[3] = branch in EX/MEM, zero_reg = zero in EX/MEM
					pc <= branch_target_pc;
				else if (mem_reg_mem[2] == 1)
					// mem_reg_mem [2] = jump in EX/MEM
					pc <= jump_target_pc;
				else
					pc <= next_pc;
			end
		end
	end

  assign imemread = 1'b1;	
  assign imemwrite = 1'b0;
  assign imem_addr = pc;	
  assign imem_wdata = 32'b0;

  assign next_pc = pc + 32'd4;
   
  
  	// Decode
	
	always @(posedge clk)
	begin
		if (stall != 1 && rst != 1)
		begin
			pc_reg_id <= next_pc;
			instruction <= imem_rdata;
		end	
	end
  
	assign opcode = instruction[31:26];
	assign rs = instruction[25:21];
	assign rt = instruction[20:16];
	assign rd = instruction[15:11];
	assign shamt = instruction[10:6];	
	assign func = instruction[5:0];
	assign imm = instruction[15:0];
	assign jmpaddr = instruction[25:0];
  
	// IR Field Breakout	
	assign reg_ra = rs;
	assign reg_rb = rt;

	assign imm_sext = { {16{imm[15]}},imm};

	
	
	

	// Control Unit (state machine)
	ee457_scpu_cu ctrl_unit(
    .op(opcode),
    .func(func),
    .branch(branch),
    .jmp(jump),
    .mr(dmemread_buf),
    .mw(dmemwrite_buf),
    .regw(regwrite_buf),
    .mtor(memtoreg_buf),
    .rdst(regdst),
    .alusrc(alusrc),
    .aluop(aluop)
    );

	
	// Regfile instance
	ee457_regfile_2r1w regfile (
		.ra(rs),
		.rb(rt),
		.wa(reg_wa),			
		.wdata(reg_wdata),	
		.wen(wb_reg_wb[1]),	
		.clk(clk),
		.rst(rst),
		.radata(reg_radata),
		.rbdata(reg_rbdata)
	);	
	

	//Execute/ALU
	always @(posedge clk)
	begin
		if (rst != 1)
		begin
			if (stall == 1)
			begin
				// Control Signals
				ex_reg_ex <= 10'b0000000000;
				mem_reg_ex <= 4'b0000;
				wb_reg_ex <= 2'b00;
			end
			else
			begin
				// Control Signals
				ex_reg_ex <= {alusrc, regdst, aluop, func};
				mem_reg_ex <= {branch, jump, dmemread_buf, dmemwrite_buf};
				wb_reg_ex <= {regwrite_buf, memtoreg_buf};
				
				pc_reg_ex <= pc_reg_id;
				
				// Internal Forwarding 
				if (rs == reg_wa)
					rdata1_reg <= reg_wdata;
				else 
					rdata1_reg <= reg_radata;
		 
				if (rt == reg_wa)
					rdata2_reg <= reg_wdata;
				else
					rdata2_reg <= reg_rbdata;
					
				imm_reg_ex <= imm_sext; 
				rs_reg_ex <= rs;
				rt_reg_ex <= rt; 
				rd_reg_ex <= rd; 
			end
		end
	end
	 

	assign imm_sext_sh2 = {imm_reg_ex[29:0],2'b0};
	assign branch_target_pc = pc_reg_ex + imm_sext_sh2;
 	assign jump_target_pc = {pc_reg_id[31:28],jmpaddr,2'b00};	// Check later
 	
	// Forwarding Unit
	always @*
	begin
		EX1 = 0;
		EX2 = 0;
		ALUSelA = 2'b0;
		ALUSelB = 2'b0;
		
		// EX Hazard
		if (wb_reg_mem[1] == 1 && reg_wa_mem != 0 && reg_wa_mem == rs_reg_ex)
			// wb_reg_mem[1] = regwrite in EX/MEM, reg_wa_mem = writereg in EX/MEM, rs_reg_ex in reg1 in ID/EX
			EX1 = 1;
		if (EX1 == 1)
			ALUSelA = 2'b01; 
			
		if (wb_reg_mem[1] == 1 && reg_wa_mem != 0 && reg_wa_mem == rt_reg_ex)
			// wb_reg_mem[1] = regwrite in EX/MEM, reg_wa_mem = writereg in EX/MEM, rt_reg_ex in reg2 in ID/EX
			EX2 = 1;
		if (EX2 == 1)
			ALUSelB = 2'b01;
	
		// MEM Hazard
		if (wb_reg_wb[1] == 1 && reg_wa_wb != 0 && reg_wa_wb == rs_reg_ex && EX1 == 0)	// Check later
			// wb_reg_mem[1] = regwrite in EX/MEM
			ALUSelA = 2'b10;
		if (wb_reg_wb[1] == 1 && reg_wa_wb != 0 && reg_wa_wb == rt_reg_ex && EX2 == 0)
			// wb_reg_mem[1] = regwrite in EX/MEM
			ALUSelB = 2'b10;
	end
	
 	assign alu_mux_in0 = (ALUSelB == 2'b10) ? reg_wdata:
						(ALUSelB == 2'b01) ? alures_mem:rdata2_reg;
 	assign alu_ina = (ALUSelA == 2'b10) ? reg_wdata: 	// Check later
						(ALUSelA == 2'b01) ? alures_mem:rdata1_reg;
	assign alu_inb = ex_reg_ex[9] ? imm_reg_ex:alu_mux_in0;
	// ex_reg_ex[9] = alusrc
	
	always @*
	begin 
	 if (ex_reg_ex[7:6] == 2'b00)
		alu_func = FUNC_ADD;
	 else if (ex_reg_ex[7:6] == 2'b01)
		alu_func = FUNC_SUB;
	 else
		alu_func = ex_reg_ex[5:0];
	end
 	
	// ALU instance 
   ee457_alu alu (
		.opa(alu_ina),
		.opb(alu_inb),
		.func(alu_func),
    .res(alu_res), 
    .uov(), 
		.sov(sov),
    .zero(zero),
		.cout()
		);

	
	// MEM
	assign reg_write_addr_wire = ex_reg_ex[8] ? rd_reg_ex : rt_reg_ex;
	// ex_reg_ex[8] = regdst in ID/EX
	 
	always @(posedge clk)
	begin
		if (rst != 1)
		begin
		// Control Signals
			pc_reg_mem <= branch_target_pc;
			mem_reg_mem <= mem_reg_ex;
			wb_reg_mem <= wb_reg_ex;
			
			zero_reg <= zero; 
			alures_mem <= alu_res;
			dmem_wdata_reg <= alu_mux_in0;
			reg_wa_mem <= reg_write_addr_wire;
		end
	end 
	
	assign dmem_addr = alures_mem;
	assign dmem_wdata = dmem_wdata_reg;
	assign dmemread = mem_reg_mem[1];
	assign dmemwrite = mem_reg_mem[0];
	
	
	// WB
	always @(posedge clk)
	begin
		if (rst != 1)
		begin
		// Control Signals
			wb_reg_wb <= wb_reg_mem;
			 
			alures_wb <= alures_mem;
			mem_rdata_wb <= dmem_rdata;
			reg_wa_wb <= reg_wa_mem;
			
			reg_wdata_prev <= reg_wdata;
			reg_wa_prev <= reg_wa;
		end
	end
	
	assign memtoreg = wb_reg_wb[0];
	assign regwrite = wb_reg_wb[1]; 
	assign reg_wdata = memtoreg ? mem_rdata_wb : alures_wb;
	assign reg_wa = reg_wa_wb;
endmodule
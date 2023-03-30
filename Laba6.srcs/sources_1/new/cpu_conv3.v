`timescale 1ns / 1ps

`define PC_WIDTH 10
`define COMMAND_SIZE 46
`define PROGRAM_SIZE 1024
`define DATA_SIZE 1024
`define OP_SIZE 4
`define ADDR_SIZE 10

`define NOP 0
`define LOAD 1
`define MVREGA 2
`define CALL 3
`define RET 4
//Подпрограмма 1
`define MUL_N 5//ВЫЧИСЛЕНИЕ НЕОБХОДИМОЙ СУММЫ, ДЛЯ N-ого члена, ЗАПИСЬ В ПАМЯТЬ
`define FIND_N 6//Первый ЧЛЕН+СУММА N-ОГО ЧЛЕНА, ЗАПИСЫВАЕТСЯ В ПАМЯТЬ
//Подпрограмма 2
`define SUM_HALF 7
`define FIND_SUM 8
/*
    Формат команды:
    NOP,RET,MUL_N,FIND_N,SUM_HALF,FIND_SUM:
    | код операции  |                                                 |
    |     4 бита    |                  42 бита                        |
    MVREGA:
    | код операции  |  адрес в памяти |                               |
    |     4 бита    |     10 бит      |            32 бита            |
    LOAD:
    | код операции  |  адрес в памяти |           Литерал             |
         4 бита     |     10 бит      |            32 бита            |
    CALL:
    | код операции  | Адрес перехода  |                               |
    |    4 бита     |     10 бит      |            32 бита            |
    
*/


module cpu_conv3(
    input clk_in,
    input reset,
    output pc
);

wire clk;
reg[`PC_WIDTH-1 : 0] pc, newpc;


reg [`COMMAND_SIZE-1 : 0]   Program [0:`PROGRAM_SIZE - 1  ];
reg [31:0]                  Data    [0:`DATA_SIZE - 1];

reg[`COMMAND_SIZE-1 : 0] command_1, command_2, command_3;
wire [`OP_SIZE - 1 : 0] op_2 = command_2 [`COMMAND_SIZE - 1 -: `OP_SIZE];
wire [`OP_SIZE - 1 : 0] op_3 = command_3 [`COMMAND_SIZE - 1 -: `OP_SIZE];

wire [`ADDR_SIZE - 1 : 0] addr1 = command_2[`COMMAND_SIZE - 1 - `OP_SIZE                 -: `ADDR_SIZE];
//wire [`ADDR_SIZE - 1 : 0] addr2 = command_2[`COMMAND_SIZE - 1 - `OP_SIZE - `ADDR_SIZE    -: `ADDR_SIZE];

wire [$clog2(`DATA_SIZE) - 1 : 0] new_addr = command_3 [`COMMAND_SIZE - 1 - `OP_SIZE -: $clog2(`DATA_SIZE)];
wire [$clog2(`DATA_SIZE) - 1 : 0] addr_to_load = command_3 [`COMMAND_SIZE - 1 - `OP_SIZE - `ADDR_SIZE - `ADDR_SIZE -: $clog2(`DATA_SIZE)];
wire [$clog2(`DATA_SIZE) - 1 : 0] addr_to_load_L = command_3 [`COMMAND_SIZE - 1 - `OP_SIZE  -: `ADDR_SIZE];

wire [31:0] literal_to_load = command_3 [`COMMAND_SIZE - 1 - `OP_SIZE - $clog2(`DATA_SIZE) -: 32];
reg [31:0] Reg_A, Reg_B, newReg_A, newReg_B;
reg [9:0] Reg_ADDR,newReg_ADDR;
reg [31:0] Reg_Temp,newReg_Temp;
integer i;
initial 
begin
    pc = 0; newpc = 0;
    $readmemb("Program.mem", Program);
    for(i = 0; i < `DATA_SIZE; i = i + 1)
        Data[i] = 32'b0;
    command_1 = 0;
    command_2 = 0;
    command_3 = 0;
    Reg_A = 0;
    Reg_B = 0;
    newReg_A = 0; 
    newReg_B = 0;
end

reg rstn=1;
reg pop=0;
reg push=0;
reg [31:0] stackIN;
wire [31:0] stackOUT;
stack1 stack(.clk(clk),.rstn(rstn),.pop(pop),.push(push),.din(stackIN),.dout(stackOUT));
clk_wiz_0 inst(
    .clk_in1(clk_in),
    .clk_out1(clk)
);
//Блок управления счётчиком команд
always@(posedge clk)
    if (reset) pc <= 0;
    else pc <= newpc;


//Такт 2
always @(posedge clk)
begin 
    if (reset) Reg_A <= 0;
    else Reg_A <= newReg_A;
    if (reset) Reg_B <= 0;
    else Reg_B <= newReg_B;
    if (reset) Reg_ADDR <= 0;
    else Reg_ADDR <= newReg_ADDR;
    if (reset) Reg_Temp <= 0;
    else Reg_Temp <= newReg_Temp;
end

always @*
begin
    case(op_2)
        `MVREGA:
            newReg_ADDR <= addr1;    
        default: newReg_ADDR <= newReg_ADDR;
    endcase
end

always @*
begin
    case(op_2)
        `MUL_N:
            newReg_A <= Data[Reg_ADDR+1];   
        `FIND_N:
            newReg_A <= Data[Reg_ADDR]; 
        `SUM_HALF:
            newReg_A <= Data[Reg_ADDR];
        `FIND_SUM:    
            newReg_A <= Data[Reg_ADDR+2];
        default: newReg_A <= newReg_A;
    endcase
end

always @*
begin
    case(op_2)
        `MUL_N:
            newReg_B <= Data[Reg_ADDR+2]-1; 
        `SUM_HALF:
            newReg_B <= Data[Reg_ADDR+3];      
        default: newReg_B <= newReg_B;
    endcase
end
always @*
begin
    case(op_2)
        `CALL: 
            begin 
                stackIN<=pc+1;
            end    
        `RET:
            begin 
                pop<=1;
            end
        default:
            begin
                push<=0;
                pop<=0;
            end 
    endcase
end
//Такт_3
reg [31:0] new_data;

always @(posedge clk)
begin
    case(op_3)
        //`MUL_N,`SUM_HALF: newReg_Temp<=new_data;
        `FIND_N: Data[Reg_ADDR+3]<=new_data;
        `FIND_SUM: Data[Reg_ADDR+4]<=new_data;
        `LOAD:
            Data[addr_to_load_L] <= new_data;
    endcase
end

always @*
begin
    case(op_3)
        `MUL_N: newReg_Temp<=Reg_A*Reg_B;
        `FIND_N: new_data<=Reg_A+Reg_Temp;
        `SUM_HALF: newReg_Temp<=(Reg_A+Reg_B);
        `FIND_SUM: new_data<=(Reg_A*Reg_Temp)/2;
        `LOAD: new_data <= literal_to_load;
    endcase
end

//Блок определения следующего значения счётчика команд
always@*
begin
    if(op_3 == `CALL)
        begin
        newpc <= new_addr;
        push<=1;
        end
    else 
    if(op_3 == `RET)
        newpc <= stackOUT;
    else newpc <= pc + 1;
end

always@(posedge clk)
begin
    command_1 <= Program[pc];
    command_2 <= command_1;
    command_3 <= command_2;
end

endmodule

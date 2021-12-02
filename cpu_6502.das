require cpu
require bus
require fio
require strings


enum CpuFlags
    C = 0 // carry
    Z = 1 // zero
    I = 2 // interrupt
    D = 3 // decimal (unused in NES)
    B = 4 // break
    U = 5 // unused
    V = 6 // overflow
    N = 7 // negative


class Cpu6502: Cpu
    bus: Bus?
    a: int
    x: int
    y: int
    sp: int
    pc: int
    status: int

    absAddr: int
    cycles: int
    totalCycles: int
    prevOpcode: int
    prevPc: int
    halt: bool
    dbgMode: bool

    def attachBus(b: Bus?)
        bus = b

    def override irq(): void
        return

    def override nmi(): void
        return

    def override reset(): void
        a = 0
        x = 0
        y = 0
        sp = int(0xFD)
        status = (1 << int(CpuFlags U)) | (1 << int(CpuFlags I))
        pc = cpu_read(self, int(0xFFFC)) | (cpu_read(self, int(0xFFFD)) << 8)
        cycles = 7
        totalCycles = cycles
        absAddr = 0
        if dbgMode
            let f = fopen("6502.log", "wt")
            fclose(f)


struct AddressingMode
    fmt: function<(var cpu: Cpu6502; address: int): string>
    setup: function<(var cpu: Cpu6502): int>
    read: function<(var cpu: Cpu6502): int>
    write: function<(var cpu: Cpu6502; data: int): void>
    bytes: int


struct CpuInstruction
    name: string
    impl: function<(var cpu: Cpu6502; am: AddressingMode): int>
    addrMode: AddressingMode
    cycles: int


def cpu_read(var cpu: Cpu6502; address: int): int
    return cpu.bus->read(address)

def cpu_write(var cpu: Cpu6502; address: int; data: int)
    cpu.bus->write(address, data)

def cpu_addr_read_abs(var cpu: Cpu6502): int
    return cpu_read(cpu, cpu.absAddr)

def cpu_addr_write_abs(var cpu: Cpu6502; data: int): void
    cpu_write(cpu, cpu.absAddr, data)

def cpu_addr_read_a(var cpu: Cpu6502): int
    return cpu.a

def cpu_addr_write_a(var cpu: Cpu6502; data: int): void
    cpu.a = data & int(0xFF)

def cpu_addr_read_none(var cpu: Cpu6502): int
    assert(false)
    return 0

def cpu_addr_write_none(var cpu: Cpu6502; data: int): void
    assert(false)
    return

def cpu_setup_ACC(var cpu: Cpu6502)
    return 0

def cpu_setup_IMM(var cpu: Cpu6502)
    cpu.absAddr = cpu.pc
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    return 0

def cpu_setup_ABS(var cpu: Cpu6502)
    var address = cpu_read(cpu, cpu.pc)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    address |= cpu_read(cpu, cpu.pc) << 8
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    cpu.absAddr = address
    return 0

def cpu_setup_ZP(var cpu: Cpu6502)
    cpu.absAddr = cpu_read(cpu, cpu.pc)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    return 0

def cpu_setup_ZPX(var cpu: Cpu6502)
    cpu.absAddr = (cpu_read(cpu, cpu.pc) + cpu.x) & int(0xFF)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    return 0

def cpu_setup_ZPY(var cpu: Cpu6502)
    cpu.absAddr = (cpu_read(cpu, cpu.pc) + cpu.y) & int(0xFF)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    return 0

def cpu_setup_ABSX(var cpu: Cpu6502)
    var address = cpu_read(cpu, cpu.pc)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    address |= cpu_read(cpu, cpu.pc) << 8
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    cpu.absAddr = (address + cpu.x) & int(0xFFFF)
    return (cpu.absAddr & int(0xFF00)) != (address & int(0xFF00)) ? 1 : 0

def cpu_setup_ABSY(var cpu: Cpu6502)
    var address = cpu_read(cpu, cpu.pc)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    address |= cpu_read(cpu, cpu.pc) << 8
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    cpu.absAddr = (address + cpu.y) & int(0xFFFF)
    return (cpu.absAddr & int(0xFF00)) != (address & int(0xFF00)) ? 1 : 0

def cpu_setup_IMP(var cpu: Cpu6502)
    return 0

def cpu_setup_REL(var cpu: Cpu6502)
    var relAddr = cpu_read(cpu, cpu.pc)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    if (relAddr & int(0x80)) != 0
        relAddr |= int(0xFF00)
    cpu.absAddr = (cpu.pc + relAddr) & int(0xFFFF)
    return 0

def cpu_setup_INDX(var cpu: Cpu6502)
    var ptr = (cpu_read(cpu, cpu.pc) + cpu.x) & int(0xFF)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    var address = cpu_read(cpu, ptr)
    address |= cpu_read(cpu, (ptr + 1) & int(0xFF)) << 8
    cpu.absAddr = address
    return 0

def cpu_setup_INDY(var cpu: Cpu6502)
    var ptr = cpu_read(cpu, cpu.pc)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    var address = cpu_read(cpu, ptr)
    address |= cpu_read(cpu, (ptr + 1) & int(0xFF)) << 8
    cpu.absAddr = address + cpu.y
    return (cpu.absAddr & int(0xFF00)) != (address & int(0xFF00)) ? 1 : 0

def cpu_setup_IND(var cpu: Cpu6502)
    var ptr = cpu_read(cpu, cpu.pc)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    ptr |= cpu_read(cpu, cpu.pc) << 8
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    var address = cpu_read(cpu, ptr)
    // 6502 HW bug: the high part of the pointer does not change on page boundaries
    if (ptr & int(0xFF)) == int(0xFF)
        address |= cpu_read(cpu, ptr & int(0xFF00)) << 8
    else
        address |= cpu_read(cpu, ptr + 1) << 8
    cpu.absAddr = address
    return 0


def cpu_fmt_ACC(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_IMM(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_ABS(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_ZP(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_ZPX(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_ZPY(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_ABSX(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_ABSY(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_IMP(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_REL(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_INDX(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_INDY(var cpu: Cpu6502; address: int)
    return ""

def cpu_fmt_IND(var cpu: Cpu6502; address: int)
    return ""


let cpu_a_ACC  <- [[AddressingMode fmt=@@cpu_fmt_ACC,  setup=@@cpu_setup_ACC,  read=@@cpu_addr_read_a,    write=@@cpu_addr_write_a,    bytes=0]]
let cpu_a_IMM  <- [[AddressingMode fmt=@@cpu_fmt_IMM,  setup=@@cpu_setup_IMM,  read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_none, bytes=1]]
let cpu_a_ABS  <- [[AddressingMode fmt=@@cpu_fmt_ABS,  setup=@@cpu_setup_ABS,  read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_abs,  bytes=2]]
let cpu_a_ZP   <- [[AddressingMode fmt=@@cpu_fmt_ZP,   setup=@@cpu_setup_ZP,   read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_abs,  bytes=1]]
let cpu_a_ZPX  <- [[AddressingMode fmt=@@cpu_fmt_ZPX,  setup=@@cpu_setup_ZPX,  read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_abs,  bytes=1]]
let cpu_a_ZPY  <- [[AddressingMode fmt=@@cpu_fmt_ZPY,  setup=@@cpu_setup_ZPY,  read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_abs,  bytes=1]]
let cpu_a_ABSX <- [[AddressingMode fmt=@@cpu_fmt_ABSX, setup=@@cpu_setup_ABSX, read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_abs,  bytes=2]]
let cpu_a_ABSY <- [[AddressingMode fmt=@@cpu_fmt_ABSY, setup=@@cpu_setup_ABSY, read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_abs,  bytes=2]]
let cpu_a_IMP  <- [[AddressingMode fmt=@@cpu_fmt_IMP,  setup=@@cpu_setup_IMP,  read=@@cpu_addr_read_none, write=@@cpu_addr_write_none, bytes=0]]
let cpu_a_REL  <- [[AddressingMode fmt=@@cpu_fmt_REL,  setup=@@cpu_setup_REL,  read=@@cpu_addr_read_none, write=@@cpu_addr_write_none, bytes=1]]
let cpu_a_INDX <- [[AddressingMode fmt=@@cpu_fmt_INDX, setup=@@cpu_setup_INDX, read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_abs,  bytes=1]]
let cpu_a_INDY <- [[AddressingMode fmt=@@cpu_fmt_INDY, setup=@@cpu_setup_INDY, read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_abs,  bytes=1]]
let cpu_a_IND  <- [[AddressingMode fmt=@@cpu_fmt_IND,  setup=@@cpu_setup_IND,  read=@@cpu_addr_read_abs,  write=@@cpu_addr_write_abs,  bytes=2]]


// Instruction implementations

def cpu_i_ADC(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = cpu.a + fetched + cpu_get_flag(cpu, CpuFlags C)
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu_set_flag(cpu, CpuFlags V, ((~(cpu.a ^ fetched)) & (cpu.a ^ res) & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 1

def cpu_i_AND(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = cpu.a & fetched
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 1

def cpu_i_ASL(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = fetched << 1
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    invoke(am.write, cpu, res & int(0xFF))
    return 0

def cpu_i_BCC(var cpu: Cpu6502; am: AddressingMode)
    if !cpu_get_flag_bool(cpu, CpuFlags C)
        cpu.cycles++
        if (cpu.absAddr & int(0xFF00)) != (cpu.pc & int(0xFF00))
            cpu.cycles++
        cpu.pc = cpu.absAddr
    return 0

def cpu_i_BCS(var cpu: Cpu6502; am: AddressingMode)
    if cpu_get_flag_bool(cpu, CpuFlags C)
        cpu.cycles++
        if (cpu.absAddr & int(0xFF00)) != (cpu.pc & int(0xFF00))
            cpu.cycles++
        cpu.pc = cpu.absAddr
    return 0

def cpu_i_BEQ(var cpu: Cpu6502; am: AddressingMode)
    if cpu_get_flag_bool(cpu, CpuFlags Z)
        cpu.cycles++
        if (cpu.absAddr & int(0xFF00)) != (cpu.pc & int(0xFF00))
            cpu.cycles++
        cpu.pc = cpu.absAddr
    return 0

def cpu_i_BIT(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = cpu.a & fetched
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    return 0

def cpu_i_BMI(var cpu: Cpu6502; am: AddressingMode)
    if cpu_get_flag_bool(cpu, CpuFlags N)
        cpu.cycles++
        if (cpu.absAddr & int(0xFF00)) != (cpu.pc & int(0xFF00))
            cpu.cycles++
        cpu.pc = cpu.absAddr
    return 0

def cpu_i_BNE(var cpu: Cpu6502; am: AddressingMode)
    if !cpu_get_flag_bool(cpu, CpuFlags Z)
        cpu.cycles++
        if (cpu.absAddr & int(0xFF00)) != (cpu.pc & int(0xFF00))
            cpu.cycles++
        cpu.pc = cpu.absAddr
    return 0

def cpu_i_BPL(var cpu: Cpu6502; am: AddressingMode)
    if !cpu_get_flag_bool(cpu, CpuFlags N)
        cpu.cycles++
        if (cpu.absAddr & int(0xFF00)) != (cpu.pc & int(0xFF00))
            cpu.cycles++
        cpu.pc = cpu.absAddr
    return 0

def cpu_i_BRK(var cpu: Cpu6502; am: AddressingMode)
    cpu_st_push(cpu, cpu.pc >> 8)
    cpu_st_push(cpu, cpu.pc)

    cpu_set_flag(cpu, CpuFlags B, 1)
    cpu_st_push(cpu, cpu.status)
    cpu_set_flag(cpu, CpuFlags I, 1)

    cpu.pc = cpu_read(cpu, int(0xFFFE)) | (cpu_read(cpu, int(0xFFFF)) << 8)
    return 0

def cpu_i_BVC(var cpu: Cpu6502; am: AddressingMode)
    if !cpu_get_flag_bool(cpu, CpuFlags V)
        cpu.cycles++
        if (cpu.absAddr & int(0xFF00)) != (cpu.pc & int(0xFF00))
            cpu.cycles++
        cpu.pc = cpu.absAddr
    return 0

def cpu_i_BVS(var cpu: Cpu6502; am: AddressingMode)
    if cpu_get_flag_bool(cpu, CpuFlags V)
        cpu.cycles++
        if (cpu.absAddr & int(0xFF00)) != (cpu.pc & int(0xFF00))
            cpu.cycles++
        cpu.pc = cpu.absAddr
    return 0

def cpu_i_CLC(var cpu: Cpu6502; am: AddressingMode)
    cpu_set_flag(cpu, CpuFlags C, 0)
    return 0

def cpu_i_CLD(var cpu: Cpu6502; am: AddressingMode)
    cpu_set_flag(cpu, CpuFlags D, 0)
    return 0

def cpu_i_CLI(var cpu: Cpu6502; am: AddressingMode)
    cpu_set_flag(cpu, CpuFlags I, 0)
    return 0

def cpu_i_CLV(var cpu: Cpu6502; am: AddressingMode)
    cpu_set_flag(cpu, CpuFlags V, 0)
    return 0

def cpu_i_CMP(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = cpu.a - fetched
    cpu_set_flag(cpu, CpuFlags C, res >= 0)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    return 1

def cpu_i_CPX(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = cpu.x - fetched
    cpu_set_flag(cpu, CpuFlags C, res >= 0)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    return 0

def cpu_i_CPY(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = cpu.y - fetched
    cpu_set_flag(cpu, CpuFlags C, res >= 0)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    return 0

def cpu_i_DEC(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = fetched - 1
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    invoke(am.write, cpu, res & int(0xFF))
    return 0

def cpu_i_DEX(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu.x - 1
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.x = res & int(0xFF)
    return 0

def cpu_i_DEY(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu.y - 1
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.y = res & int(0xFF)
    return 0

def cpu_i_EOR(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = cpu.a ^ fetched
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 1

def cpu_i_INC(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = fetched + 1
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    invoke(am.write, cpu, res & int(0xFF))
    return 0

def cpu_i_INX(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu.x + 1
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.x = res & int(0xFF)
    return 0

def cpu_i_INY(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu.y + 1
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.y = res & int(0xFF)
    return 0

def cpu_i_JMP(var cpu: Cpu6502; am: AddressingMode)
    cpu.pc = cpu.absAddr
    return 0

def cpu_i_JSR(var cpu: Cpu6502; am: AddressingMode)
    let pc_to_store = (cpu.pc - 1) & int(0xFFFF)
    cpu_st_push(cpu, pc_to_store >> 8)
    cpu_st_push(cpu, pc_to_store)
    cpu.pc = cpu.absAddr
    return 0

def cpu_i_LDA(var cpu: Cpu6502; am: AddressingMode)
    let res = invoke(am.read, cpu)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 1

def cpu_i_LDX(var cpu: Cpu6502; am: AddressingMode)
    let res = invoke(am.read, cpu)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.x = res & int(0xFF)
    return 1

def cpu_i_LDY(var cpu: Cpu6502; am: AddressingMode)
    let res = invoke(am.read, cpu)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.y = res & int(0xFF)
    return 1

def cpu_i_LSR(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = fetched >> 1
    cpu_set_flag(cpu, CpuFlags C, fetched & 1)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    invoke(am.write, cpu, res & int(0xFF))
    return 0

def cpu_i_NOP(var cpu: Cpu6502; am: AddressingMode)
    return 0

def cpu_i_ORA(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = cpu.a | fetched
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 1

def cpu_i_PHA(var cpu: Cpu6502; am: AddressingMode)
    cpu_st_push(cpu, cpu.a)
    return 0

def cpu_i_PHP(var cpu: Cpu6502; am: AddressingMode)
    let val = cpu.status | (1 << int(CpuFlags U)) | (1 << int(CpuFlags B))
    cpu_st_push(cpu, val)
    return 0

def cpu_i_PLA(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu_st_pop(cpu)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 0

def cpu_i_PLP(var cpu: Cpu6502; am: AddressingMode)
    cpu.status = (cpu_st_pop(cpu) | (1 << int(CpuFlags U))) & ~(1 << int(CpuFlags B))
    return 0

def cpu_i_ROL(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = (fetched << 1) | cpu_get_flag(cpu, CpuFlags C)
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    invoke(am.write, cpu, res & int(0xFF))
    return 0

def cpu_i_ROR(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = (fetched >> 1) | (cpu_get_flag(cpu, CpuFlags C) << 7)
    cpu_set_flag(cpu, CpuFlags C, fetched & 1)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    invoke(am.write, cpu, res & int(0xFF))
    return 0

def cpu_i_RTI(var cpu: Cpu6502; am: AddressingMode)
    cpu.status = cpu_st_pop(cpu) | (1 << int(CpuFlags U))
    let pcl = cpu_st_pop(cpu)
    let pch = cpu_st_pop(cpu)
    cpu.pc = (pch << 8) | pcl
    return 0

def cpu_i_RTS(var cpu: Cpu6502; am: AddressingMode)
    let pcl = cpu_st_pop(cpu)
    let pch = cpu_st_pop(cpu)
    cpu.pc = ((pch << 8) | pcl) + 1 & int(0xFFFF)
    return 0

def cpu_i_SBC(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let not_fetched = fetched ^ int(0xFF)
    let res = cpu.a + not_fetched + cpu_get_flag(cpu, CpuFlags C)
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu_set_flag(cpu, CpuFlags V, ((~(cpu.a ^ not_fetched)) & (cpu.a ^ res) & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 1

def cpu_i_SEC(var cpu: Cpu6502; am: AddressingMode)
    cpu_set_flag(cpu, CpuFlags C, 1)
    return 0

def cpu_i_SED(var cpu: Cpu6502; am: AddressingMode)
    cpu_set_flag(cpu, CpuFlags D, 1)
    return 0

def cpu_i_SEI(var cpu: Cpu6502; am: AddressingMode)
    cpu_set_flag(cpu, CpuFlags I, 1)
    return 0

def cpu_i_STA(var cpu: Cpu6502; am: AddressingMode)
    invoke(am.write, cpu, cpu.a)
    return 0

def cpu_i_STX(var cpu: Cpu6502; am: AddressingMode)
    invoke(am.write, cpu, cpu.x)
    return 0

def cpu_i_STY(var cpu: Cpu6502; am: AddressingMode)
    invoke(am.write, cpu, cpu.y)
    return 0

def cpu_i_TAX(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu.a
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.x = res
    return 0

def cpu_i_TAY(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu.a
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.y = res
    return 0

def cpu_i_TSX(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu.sp
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.x = res
    return 0

def cpu_i_TXA(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu.x
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res
    return 0

def cpu_i_TXS(var cpu: Cpu6502; am: AddressingMode)
    cpu.sp = cpu.x
    return 0

def cpu_i_TYA(var cpu: Cpu6502; am: AddressingMode)
    let res = cpu.y
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res
    return 0

// Unofficial instructions

def cpu_i_LAX(var cpu: Cpu6502; am: AddressingMode)
    let res = invoke(am.read, cpu)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res
    cpu.x = res
    return 0

def cpu_i_SAX(var cpu: Cpu6502; am: AddressingMode)
    invoke(am.write, cpu, cpu.a & cpu.x)
    return 0

def cpu_i_DCP(var cpu: Cpu6502; am: AddressingMode)
    let value = (invoke(am.read, cpu) - 1) & int(0xFF)
    invoke(am.write, cpu, value)
    let res = cpu.a - value
    cpu_set_flag(cpu, CpuFlags C, res >= 0)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    return 0

def cpu_i_ISB(var cpu: Cpu6502; am: AddressingMode)
    let value = (invoke(am.read, cpu) + 1) & int(0xFF)
    invoke(am.write, cpu, value)
    let not_value = value ^ int(0xFF)
    let res = cpu.a + not_value + cpu_get_flag(cpu, CpuFlags C)
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu_set_flag(cpu, CpuFlags V, ((~(cpu.a ^ not_value)) & (cpu.a ^ res) & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 0

def cpu_i_SLO(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    var res = fetched << 1
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    res &= int(0xFF)
    invoke(am.write, cpu, res)
    res |= cpu.a
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 0

def cpu_i_RLA(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    var res = (fetched << 1) | cpu_get_flag(cpu, CpuFlags C)
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    res &= int(0xFF)
    invoke(am.write, cpu, res)
    res &= cpu.a
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 0

def cpu_i_SRE(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    var res = fetched >> 1
    cpu_set_flag(cpu, CpuFlags C, fetched & 1)
    res &= int(0xFF)
    invoke(am.write, cpu, res)
    res ^= cpu.a
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 0

def cpu_i_RRA(var cpu: Cpu6502; am: AddressingMode)
    var fetched = invoke(am.read, cpu)
    var res = (fetched >> 1) | (cpu_get_flag(cpu, CpuFlags C) << 7)
    cpu_set_flag(cpu, CpuFlags C, fetched & 1)
    res &= int(0xFF)
    invoke(am.write, cpu, res)
    fetched = res
    res = cpu.a + fetched + cpu_get_flag(cpu, CpuFlags C)
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu_set_flag(cpu, CpuFlags V, ((~(cpu.a ^ fetched)) & (cpu.a ^ res) & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 0

def cpu_i_STP(var cpu: Cpu6502; am: AddressingMode)
    cpu.halt = true
    return 0

def cpu_i_LAS(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = fetched & cpu.sp
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res
    cpu.x = res
    cpu.sp = res
    return 0

def cpu_i_ANC(var cpu: Cpu6502; am: AddressingMode)
    cpu_i_AND(cpu, am)
    cpu_set_flag(cpu, CpuFlags C, (cpu.a & int(0x80)) != 0)
    return 0

def cpu_i_ALR(var cpu: Cpu6502; am: AddressingMode)
    cpu_i_AND(cpu, am)
    let res = cpu.a >> 1
    cpu_set_flag(cpu, CpuFlags C, cpu.a & 1)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 0

def cpu_i_ARR(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    cpu.a &= fetched
    let res = (fetched >> 1) | (cpu_get_flag(cpu, CpuFlags C) << 7)
    cpu_set_flag(cpu, CpuFlags C, fetched & 1)
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    invoke(am.write, cpu, res & int(0xFF))
    return 0

def cpu_i_SBX(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = ((cpu.a & cpu.x) - fetched) & int(0xFFFF)
    cpu_set_flag(cpu, CpuFlags C, res > int(0xFF))
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.x = res & int(0xFF)
    return 0

def cpu_i_XAA(var cpu: Cpu6502; am: AddressingMode)
    let fetched = invoke(am.read, cpu)
    let res = cpu.a & cpu.x & fetched
    cpu_set_flag(cpu, CpuFlags Z, (res & int(0xFF)) == 0)
    cpu_set_flag(cpu, CpuFlags N, (res & int(0x80)) != 0)
    cpu.a = res & int(0xFF)
    return 0

def cpu_i_IGN(var cpu: Cpu6502; am: AddressingMode)
    return 1


let cpu_instruction_table <- [[CpuInstruction[]
    [[CpuInstruction name="BRK",  impl=@@cpu_i_BRK, addrMode=cpu_a_IMP,  cycles=7]]; // 0x00
    [[CpuInstruction name="ORA",  impl=@@cpu_i_ORA, addrMode=cpu_a_INDX, cycles=6]]; // 0x01
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x02
    [[CpuInstruction name="SLO?", impl=@@cpu_i_SLO, addrMode=cpu_a_INDX, cycles=8]]; // 0x03
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ZP,   cycles=3]]; // 0x04
    [[CpuInstruction name="ORA",  impl=@@cpu_i_ORA, addrMode=cpu_a_ZP,   cycles=3]]; // 0x05
    [[CpuInstruction name="ASL",  impl=@@cpu_i_ASL, addrMode=cpu_a_ZP,   cycles=5]]; // 0x06
    [[CpuInstruction name="SLO?", impl=@@cpu_i_SLO, addrMode=cpu_a_ZP,   cycles=5]]; // 0x07
    [[CpuInstruction name="PHP",  impl=@@cpu_i_PHP, addrMode=cpu_a_IMP,  cycles=3]]; // 0x08
    [[CpuInstruction name="ORA",  impl=@@cpu_i_ORA, addrMode=cpu_a_IMM,  cycles=2]]; // 0x09
    [[CpuInstruction name="ASL",  impl=@@cpu_i_ASL, addrMode=cpu_a_ACC,  cycles=2]]; // 0x0A
    [[CpuInstruction name="ANC?", impl=@@cpu_i_ANC, addrMode=cpu_a_IMM,  cycles=2]]; // 0x0B
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ABS,  cycles=4]]; // 0x0C
    [[CpuInstruction name="ORA",  impl=@@cpu_i_ORA, addrMode=cpu_a_ABS,  cycles=4]]; // 0x0D
    [[CpuInstruction name="ASL",  impl=@@cpu_i_ASL, addrMode=cpu_a_ABS,  cycles=6]]; // 0x0E
    [[CpuInstruction name="SLO?", impl=@@cpu_i_SLO, addrMode=cpu_a_ABS,  cycles=6]]; // 0x0F

    [[CpuInstruction name="BPL",  impl=@@cpu_i_BPL, addrMode=cpu_a_REL,  cycles=2]]; // 0x10
    [[CpuInstruction name="ORA",  impl=@@cpu_i_ORA, addrMode=cpu_a_INDY, cycles=5]]; // 0x11
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x12
    [[CpuInstruction name="SLO?", impl=@@cpu_i_SLO, addrMode=cpu_a_INDY, cycles=8]]; // 0x13
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x14
    [[CpuInstruction name="ORA",  impl=@@cpu_i_ORA, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x15
    [[CpuInstruction name="ASL",  impl=@@cpu_i_ASL, addrMode=cpu_a_ZPX,  cycles=6]]; // 0x16
    [[CpuInstruction name="SLO?", impl=@@cpu_i_SLO, addrMode=cpu_a_ZPX,  cycles=6]]; // 0x17
    [[CpuInstruction name="CLC",  impl=@@cpu_i_CLC, addrMode=cpu_a_IMP,  cycles=2]]; // 0x18
    [[CpuInstruction name="ORA",  impl=@@cpu_i_ORA, addrMode=cpu_a_ABSY, cycles=4]]; // 0x19
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMP,  cycles=2]]; // 0x1A
    [[CpuInstruction name="SLO?", impl=@@cpu_i_SLO, addrMode=cpu_a_ABSY, cycles=7]]; // 0x1B
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_ABSX, cycles=4]]; // 0x1C
    [[CpuInstruction name="ORA",  impl=@@cpu_i_ORA, addrMode=cpu_a_ABSX, cycles=4]]; // 0x1D
    [[CpuInstruction name="ASL",  impl=@@cpu_i_ASL, addrMode=cpu_a_ABSX, cycles=7]]; // 0x1E
    [[CpuInstruction name="SLO?", impl=@@cpu_i_SLO, addrMode=cpu_a_ABSX, cycles=7]]; // 0x1F

    [[CpuInstruction name="JSR",  impl=@@cpu_i_JSR, addrMode=cpu_a_ABS,  cycles=6]]; // 0x20
    [[CpuInstruction name="AND",  impl=@@cpu_i_AND, addrMode=cpu_a_INDX, cycles=6]]; // 0x21
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x22
    [[CpuInstruction name="RLA?", impl=@@cpu_i_RLA, addrMode=cpu_a_INDX, cycles=8]]; // 0x23
    [[CpuInstruction name="BIT",  impl=@@cpu_i_BIT, addrMode=cpu_a_ZP,   cycles=3]]; // 0x24
    [[CpuInstruction name="AND",  impl=@@cpu_i_AND, addrMode=cpu_a_ZP,   cycles=3]]; // 0x25
    [[CpuInstruction name="ROL",  impl=@@cpu_i_ROL, addrMode=cpu_a_ZP,   cycles=5]]; // 0x26
    [[CpuInstruction name="RLA?", impl=@@cpu_i_RLA, addrMode=cpu_a_ZP,   cycles=5]]; // 0x27
    [[CpuInstruction name="PLP",  impl=@@cpu_i_PLP, addrMode=cpu_a_IMP,  cycles=4]]; // 0x28
    [[CpuInstruction name="AND",  impl=@@cpu_i_AND, addrMode=cpu_a_IMM,  cycles=2]]; // 0x29
    [[CpuInstruction name="ROL",  impl=@@cpu_i_ROL, addrMode=cpu_a_ACC,  cycles=2]]; // 0x2A
    [[CpuInstruction name="ANC?", impl=@@cpu_i_ANC, addrMode=cpu_a_IMM,  cycles=2]]; // 0x2B
    [[CpuInstruction name="BIT",  impl=@@cpu_i_BIT, addrMode=cpu_a_ABS,  cycles=4]]; // 0x2C
    [[CpuInstruction name="AND",  impl=@@cpu_i_AND, addrMode=cpu_a_ABS,  cycles=4]]; // 0x2D
    [[CpuInstruction name="ROL",  impl=@@cpu_i_ROL, addrMode=cpu_a_ABS,  cycles=6]]; // 0x2E
    [[CpuInstruction name="RLA?", impl=@@cpu_i_RLA, addrMode=cpu_a_ABS,  cycles=6]]; // 0x2F

    [[CpuInstruction name="BMI",  impl=@@cpu_i_BMI, addrMode=cpu_a_REL,  cycles=2]]; // 0x30
    [[CpuInstruction name="AND",  impl=@@cpu_i_AND, addrMode=cpu_a_INDY, cycles=5]]; // 0x31
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x32
    [[CpuInstruction name="RLA?", impl=@@cpu_i_RLA, addrMode=cpu_a_INDY, cycles=8]]; // 0x33
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x34
    [[CpuInstruction name="AND",  impl=@@cpu_i_AND, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x35
    [[CpuInstruction name="ROL",  impl=@@cpu_i_ROL, addrMode=cpu_a_ZPX,  cycles=6]]; // 0x36
    [[CpuInstruction name="RLA?", impl=@@cpu_i_RLA, addrMode=cpu_a_ZPX,  cycles=6]]; // 0x37
    [[CpuInstruction name="SEC",  impl=@@cpu_i_SEC, addrMode=cpu_a_IMP,  cycles=2]]; // 0x38
    [[CpuInstruction name="AND",  impl=@@cpu_i_AND, addrMode=cpu_a_ABSY, cycles=4]]; // 0x39
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMP,  cycles=2]]; // 0x3A
    [[CpuInstruction name="RLA?", impl=@@cpu_i_RLA, addrMode=cpu_a_ABSY, cycles=7]]; // 0x3B
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ABSX, cycles=4]]; // 0x3C
    [[CpuInstruction name="AND",  impl=@@cpu_i_AND, addrMode=cpu_a_ABSX, cycles=4]]; // 0x3D
    [[CpuInstruction name="ROL",  impl=@@cpu_i_ROL, addrMode=cpu_a_ABSX, cycles=7]]; // 0x3E
    [[CpuInstruction name="RLA?", impl=@@cpu_i_RLA, addrMode=cpu_a_ABSX, cycles=7]]; // 0x3F

    [[CpuInstruction name="RTI",  impl=@@cpu_i_RTI, addrMode=cpu_a_IMP,  cycles=6]]; // 0x40
    [[CpuInstruction name="EOR",  impl=@@cpu_i_EOR, addrMode=cpu_a_INDX, cycles=6]]; // 0x41
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x42
    [[CpuInstruction name="SRE?", impl=@@cpu_i_SRE, addrMode=cpu_a_INDX, cycles=8]]; // 0x43
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ZP,   cycles=3]]; // 0x44
    [[CpuInstruction name="EOR",  impl=@@cpu_i_EOR, addrMode=cpu_a_ZP,   cycles=3]]; // 0x45
    [[CpuInstruction name="LSR",  impl=@@cpu_i_LSR, addrMode=cpu_a_ZP,   cycles=5]]; // 0x46
    [[CpuInstruction name="SRE?", impl=@@cpu_i_SRE, addrMode=cpu_a_ZP,   cycles=5]]; // 0x47
    [[CpuInstruction name="PHA",  impl=@@cpu_i_PHA, addrMode=cpu_a_IMP,  cycles=3]]; // 0x48
    [[CpuInstruction name="EOR",  impl=@@cpu_i_EOR, addrMode=cpu_a_IMM,  cycles=2]]; // 0x49
    [[CpuInstruction name="LSR",  impl=@@cpu_i_LSR, addrMode=cpu_a_ACC,  cycles=2]]; // 0x4A
    [[CpuInstruction name="ALR?", impl=@@cpu_i_ALR, addrMode=cpu_a_IMM,  cycles=2]]; // 0x4B
    [[CpuInstruction name="JMP",  impl=@@cpu_i_JMP, addrMode=cpu_a_ABS,  cycles=3]]; // 0x4C
    [[CpuInstruction name="EOR",  impl=@@cpu_i_EOR, addrMode=cpu_a_ABS,  cycles=4]]; // 0x4D
    [[CpuInstruction name="LSR",  impl=@@cpu_i_LSR, addrMode=cpu_a_ABS,  cycles=6]]; // 0x4E
    [[CpuInstruction name="SRE?", impl=@@cpu_i_SRE, addrMode=cpu_a_ABS,  cycles=6]]; // 0x4F

    [[CpuInstruction name="BVC",  impl=@@cpu_i_BVC, addrMode=cpu_a_REL,  cycles=2]]; // 0x50
    [[CpuInstruction name="EOR",  impl=@@cpu_i_EOR, addrMode=cpu_a_INDY, cycles=5]]; // 0x51
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x52
    [[CpuInstruction name="SRE?", impl=@@cpu_i_SRE, addrMode=cpu_a_INDY, cycles=8]]; // 0x53
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x54
    [[CpuInstruction name="EOR",  impl=@@cpu_i_EOR, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x55
    [[CpuInstruction name="LSR",  impl=@@cpu_i_LSR, addrMode=cpu_a_ZPX,  cycles=6]]; // 0x56
    [[CpuInstruction name="SRE?", impl=@@cpu_i_SRE, addrMode=cpu_a_ZPX,  cycles=6]]; // 0x57
    [[CpuInstruction name="CLI",  impl=@@cpu_i_CLI, addrMode=cpu_a_IMP,  cycles=2]]; // 0x58
    [[CpuInstruction name="EOR",  impl=@@cpu_i_EOR, addrMode=cpu_a_ABSY, cycles=4]]; // 0x59
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMP,  cycles=2]]; // 0x5A
    [[CpuInstruction name="SRE?", impl=@@cpu_i_SRE, addrMode=cpu_a_ABSY, cycles=7]]; // 0x5B
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ABSX, cycles=4]]; // 0x5C
    [[CpuInstruction name="EOR",  impl=@@cpu_i_EOR, addrMode=cpu_a_ABSX, cycles=4]]; // 0x5D
    [[CpuInstruction name="LSR",  impl=@@cpu_i_LSR, addrMode=cpu_a_ABSX, cycles=7]]; // 0x5E
    [[CpuInstruction name="SRE?", impl=@@cpu_i_SRE, addrMode=cpu_a_ABSX, cycles=7]]; // 0x5F

    [[CpuInstruction name="RTS",  impl=@@cpu_i_RTS, addrMode=cpu_a_IMP,  cycles=6]]; // 0x60
    [[CpuInstruction name="ADC",  impl=@@cpu_i_ADC, addrMode=cpu_a_INDX, cycles=6]]; // 0x61
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x62
    [[CpuInstruction name="RRA?", impl=@@cpu_i_RRA, addrMode=cpu_a_INDX, cycles=8]]; // 0x63
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ZP,   cycles=3]]; // 0x64
    [[CpuInstruction name="ADC",  impl=@@cpu_i_ADC, addrMode=cpu_a_ZP,   cycles=3]]; // 0x65
    [[CpuInstruction name="ROR",  impl=@@cpu_i_ROR, addrMode=cpu_a_ZP,   cycles=5]]; // 0x66
    [[CpuInstruction name="RRA?", impl=@@cpu_i_RRA, addrMode=cpu_a_ZP,   cycles=5]]; // 0x67
    [[CpuInstruction name="PLA",  impl=@@cpu_i_PLA, addrMode=cpu_a_IMP,  cycles=4]]; // 0x68
    [[CpuInstruction name="ADC",  impl=@@cpu_i_ADC, addrMode=cpu_a_IMM,  cycles=2]]; // 0x69
    [[CpuInstruction name="ROR",  impl=@@cpu_i_ROR, addrMode=cpu_a_ACC,  cycles=2]]; // 0x6A
    [[CpuInstruction name="ARR?", impl=@@cpu_i_ARR, addrMode=cpu_a_IMM,  cycles=2]]; // 0x6B
    [[CpuInstruction name="JMP",  impl=@@cpu_i_JMP, addrMode=cpu_a_IND,  cycles=5]]; // 0x6C
    [[CpuInstruction name="ADC",  impl=@@cpu_i_ADC, addrMode=cpu_a_ABS,  cycles=4]]; // 0x6D
    [[CpuInstruction name="ROR",  impl=@@cpu_i_ROR, addrMode=cpu_a_ABS,  cycles=6]]; // 0x6E
    [[CpuInstruction name="RRA?", impl=@@cpu_i_RRA, addrMode=cpu_a_ABS,  cycles=6]]; // 0x6F

    [[CpuInstruction name="BVS",  impl=@@cpu_i_BVS, addrMode=cpu_a_REL,  cycles=2]]; // 0x70
    [[CpuInstruction name="ADC",  impl=@@cpu_i_ADC, addrMode=cpu_a_INDY, cycles=5]]; // 0x71
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x72
    [[CpuInstruction name="RRA?", impl=@@cpu_i_RRA, addrMode=cpu_a_INDY, cycles=8]]; // 0x73
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x74
    [[CpuInstruction name="ADC",  impl=@@cpu_i_ADC, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x75
    [[CpuInstruction name="ROR",  impl=@@cpu_i_ROR, addrMode=cpu_a_ZPX,  cycles=6]]; // 0x76
    [[CpuInstruction name="RRA?", impl=@@cpu_i_RRA, addrMode=cpu_a_ZPX,  cycles=6]]; // 0x77
    [[CpuInstruction name="SEI",  impl=@@cpu_i_SEI, addrMode=cpu_a_IMP,  cycles=2]]; // 0x78
    [[CpuInstruction name="ADC",  impl=@@cpu_i_ADC, addrMode=cpu_a_ABSY, cycles=4]]; // 0x79
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMP,  cycles=2]]; // 0x7A
    [[CpuInstruction name="RRA?", impl=@@cpu_i_RRA, addrMode=cpu_a_ABSY, cycles=7]]; // 0x7B
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ABSX, cycles=4]]; // 0x7C
    [[CpuInstruction name="ADC",  impl=@@cpu_i_ADC, addrMode=cpu_a_ABSX, cycles=4]]; // 0x7D
    [[CpuInstruction name="ROR",  impl=@@cpu_i_ROR, addrMode=cpu_a_ABSX, cycles=7]]; // 0x7E
    [[CpuInstruction name="RRA?", impl=@@cpu_i_RRA, addrMode=cpu_a_ABSX, cycles=7]]; // 0x7F

    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMM,  cycles=2]]; // 0x80
    [[CpuInstruction name="STA",  impl=@@cpu_i_STA, addrMode=cpu_a_INDX, cycles=6]]; // 0x81
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMM,  cycles=2]]; // 0x82
    [[CpuInstruction name="SAX?", impl=@@cpu_i_SAX, addrMode=cpu_a_INDX, cycles=6]]; // 0x83
    [[CpuInstruction name="STY",  impl=@@cpu_i_STY, addrMode=cpu_a_ZP,   cycles=3]]; // 0x84
    [[CpuInstruction name="STA",  impl=@@cpu_i_STA, addrMode=cpu_a_ZP,   cycles=3]]; // 0x85
    [[CpuInstruction name="STX",  impl=@@cpu_i_STX, addrMode=cpu_a_ZP,   cycles=3]]; // 0x86
    [[CpuInstruction name="SAX?", impl=@@cpu_i_SAX, addrMode=cpu_a_ZP,   cycles=3]]; // 0x87
    [[CpuInstruction name="DEY",  impl=@@cpu_i_DEY, addrMode=cpu_a_IMP,  cycles=2]]; // 0x88
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMM,  cycles=2]]; // 0x89
    [[CpuInstruction name="TXA",  impl=@@cpu_i_TXA, addrMode=cpu_a_IMP,  cycles=2]]; // 0x8A
    [[CpuInstruction name="XAA?", impl=@@cpu_i_XAA, addrMode=cpu_a_IMM,  cycles=2]]; // 0x8B
    [[CpuInstruction name="STY",  impl=@@cpu_i_STY, addrMode=cpu_a_ABS,  cycles=4]]; // 0x8C
    [[CpuInstruction name="STA",  impl=@@cpu_i_STA, addrMode=cpu_a_ABS,  cycles=4]]; // 0x8D
    [[CpuInstruction name="STX",  impl=@@cpu_i_STX, addrMode=cpu_a_ABS,  cycles=4]]; // 0x8E
    [[CpuInstruction name="SAX?", impl=@@cpu_i_SAX, addrMode=cpu_a_ABS,  cycles=4]]; // 0x8F

    [[CpuInstruction name="BCC",  impl=@@cpu_i_BCC, addrMode=cpu_a_REL,  cycles=2]]; // 0x90
    [[CpuInstruction name="STA",  impl=@@cpu_i_STA, addrMode=cpu_a_INDY, cycles=6]]; // 0x91
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x92
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x93
    [[CpuInstruction name="STY",  impl=@@cpu_i_STY, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x94
    [[CpuInstruction name="STA",  impl=@@cpu_i_STA, addrMode=cpu_a_ZPX,  cycles=4]]; // 0x95
    [[CpuInstruction name="STX",  impl=@@cpu_i_STX, addrMode=cpu_a_ZPY,  cycles=4]]; // 0x96
    [[CpuInstruction name="SAX?", impl=@@cpu_i_SAX, addrMode=cpu_a_ZPY,  cycles=4]]; // 0x97
    [[CpuInstruction name="TYA",  impl=@@cpu_i_TYA, addrMode=cpu_a_IMP,  cycles=2]]; // 0x98
    [[CpuInstruction name="STA",  impl=@@cpu_i_STA, addrMode=cpu_a_ABSY, cycles=5]]; // 0x99
    [[CpuInstruction name="TXS",  impl=@@cpu_i_TXS, addrMode=cpu_a_IMP,  cycles=2]]; // 0x9A
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x9B
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x9C
    [[CpuInstruction name="STA",  impl=@@cpu_i_STA, addrMode=cpu_a_ABSX, cycles=5]]; // 0x9D
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x9E
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0x9F

    [[CpuInstruction name="LDY",  impl=@@cpu_i_LDY, addrMode=cpu_a_IMM,  cycles=2]]; // 0xA0
    [[CpuInstruction name="LDA",  impl=@@cpu_i_LDA, addrMode=cpu_a_INDX, cycles=6]]; // 0xA1
    [[CpuInstruction name="LDX",  impl=@@cpu_i_LDX, addrMode=cpu_a_IMM,  cycles=2]]; // 0xA2
    [[CpuInstruction name="LAX?", impl=@@cpu_i_LAX, addrMode=cpu_a_INDX, cycles=6]]; // 0xA3
    [[CpuInstruction name="LDY",  impl=@@cpu_i_LDY, addrMode=cpu_a_ZP,   cycles=3]]; // 0xA4
    [[CpuInstruction name="LDA",  impl=@@cpu_i_LDA, addrMode=cpu_a_ZP,   cycles=3]]; // 0xA5
    [[CpuInstruction name="LDX",  impl=@@cpu_i_LDX, addrMode=cpu_a_ZP,   cycles=3]]; // 0xA6
    [[CpuInstruction name="LAX?", impl=@@cpu_i_LAX, addrMode=cpu_a_ZP,   cycles=3]]; // 0xA7
    [[CpuInstruction name="TAY",  impl=@@cpu_i_TAY, addrMode=cpu_a_IMP,  cycles=2]]; // 0xA8
    [[CpuInstruction name="LDA",  impl=@@cpu_i_LDA, addrMode=cpu_a_IMM,  cycles=2]]; // 0xA9
    [[CpuInstruction name="TAX",  impl=@@cpu_i_TAX, addrMode=cpu_a_IMP,  cycles=2]]; // 0xAA
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0xAB
    [[CpuInstruction name="LDY",  impl=@@cpu_i_LDY, addrMode=cpu_a_ABS,  cycles=4]]; // 0xAC
    [[CpuInstruction name="LDA",  impl=@@cpu_i_LDA, addrMode=cpu_a_ABS,  cycles=4]]; // 0xAD
    [[CpuInstruction name="LDX",  impl=@@cpu_i_LDX, addrMode=cpu_a_ABS,  cycles=4]]; // 0xAE
    [[CpuInstruction name="LAX?", impl=@@cpu_i_LAX, addrMode=cpu_a_ABS,  cycles=4]]; // 0xAF

    [[CpuInstruction name="BCS",  impl=@@cpu_i_BCS, addrMode=cpu_a_REL,  cycles=2]]; // 0xB0
    [[CpuInstruction name="LDA",  impl=@@cpu_i_LDA, addrMode=cpu_a_INDY, cycles=5]]; // 0xB1
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0xB2
    [[CpuInstruction name="LAX?", impl=@@cpu_i_LAX, addrMode=cpu_a_INDY, cycles=5]]; // 0xB3
    [[CpuInstruction name="LDY",  impl=@@cpu_i_LDY, addrMode=cpu_a_ZPX,  cycles=4]]; // 0xB4
    [[CpuInstruction name="LDA",  impl=@@cpu_i_LDA, addrMode=cpu_a_ZPX,  cycles=4]]; // 0xB5
    [[CpuInstruction name="LDX",  impl=@@cpu_i_LDX, addrMode=cpu_a_ZPY,  cycles=4]]; // 0xB6
    [[CpuInstruction name="LAX?", impl=@@cpu_i_LAX, addrMode=cpu_a_ZPY,  cycles=4]]; // 0xB7
    [[CpuInstruction name="CLV",  impl=@@cpu_i_CLV, addrMode=cpu_a_IMP,  cycles=2]]; // 0xB8
    [[CpuInstruction name="LDA",  impl=@@cpu_i_LDA, addrMode=cpu_a_ABSY, cycles=4]]; // 0xB9
    [[CpuInstruction name="TSX",  impl=@@cpu_i_TSX, addrMode=cpu_a_IMP,  cycles=2]]; // 0xBA
    [[CpuInstruction name="LAS?", impl=@@cpu_i_LAS, addrMode=cpu_a_ABSY, cycles=1]]; // 0xBB
    [[CpuInstruction name="LDY",  impl=@@cpu_i_LDY, addrMode=cpu_a_ABSX, cycles=4]]; // 0xBC
    [[CpuInstruction name="LDA",  impl=@@cpu_i_LDA, addrMode=cpu_a_ABSX, cycles=4]]; // 0xBD
    [[CpuInstruction name="LDX",  impl=@@cpu_i_LDX, addrMode=cpu_a_ABSY, cycles=4]]; // 0xBE
    [[CpuInstruction name="LAX?", impl=@@cpu_i_LAX, addrMode=cpu_a_ABSY, cycles=4]]; // 0xBF

    [[CpuInstruction name="CPY",  impl=@@cpu_i_CPY, addrMode=cpu_a_IMM,  cycles=2]]; // 0xC0
    [[CpuInstruction name="CMP",  impl=@@cpu_i_CMP, addrMode=cpu_a_INDX, cycles=6]]; // 0xC1
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMM,  cycles=2]]; // 0xC2
    [[CpuInstruction name="DCP?", impl=@@cpu_i_DCP, addrMode=cpu_a_INDX, cycles=8]]; // 0xC3
    [[CpuInstruction name="CPY",  impl=@@cpu_i_CPY, addrMode=cpu_a_ZP,   cycles=3]]; // 0xC4
    [[CpuInstruction name="CMP",  impl=@@cpu_i_CMP, addrMode=cpu_a_ZP,   cycles=3]]; // 0xC5
    [[CpuInstruction name="DEC",  impl=@@cpu_i_DEC, addrMode=cpu_a_ZP,   cycles=5]]; // 0xC6
    [[CpuInstruction name="DCP?", impl=@@cpu_i_DCP, addrMode=cpu_a_ZP,   cycles=5]]; // 0xC7
    [[CpuInstruction name="INY",  impl=@@cpu_i_INY, addrMode=cpu_a_IMP,  cycles=2]]; // 0xC8
    [[CpuInstruction name="CMP",  impl=@@cpu_i_CMP, addrMode=cpu_a_IMM,  cycles=2]]; // 0xC9
    [[CpuInstruction name="DEX",  impl=@@cpu_i_DEX, addrMode=cpu_a_IMP,  cycles=2]]; // 0xCA
    [[CpuInstruction name="SBX?", impl=@@cpu_i_SBX, addrMode=cpu_a_IMM,  cycles=2]]; // 0xCB
    [[CpuInstruction name="CPY",  impl=@@cpu_i_CPY, addrMode=cpu_a_ABS,  cycles=4]]; // 0xCC
    [[CpuInstruction name="CMP",  impl=@@cpu_i_CMP, addrMode=cpu_a_ABS,  cycles=4]]; // 0xCD
    [[CpuInstruction name="DEC",  impl=@@cpu_i_DEC, addrMode=cpu_a_ABS,  cycles=6]]; // 0xCE
    [[CpuInstruction name="DCP?", impl=@@cpu_i_DCP, addrMode=cpu_a_ABS,  cycles=6]]; // 0xCF

    [[CpuInstruction name="BNE",  impl=@@cpu_i_BNE, addrMode=cpu_a_REL,  cycles=2]]; // 0xD0
    [[CpuInstruction name="CMP",  impl=@@cpu_i_CMP, addrMode=cpu_a_INDY, cycles=5]]; // 0xD1
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0xD2
    [[CpuInstruction name="DCP?", impl=@@cpu_i_DCP, addrMode=cpu_a_INDY, cycles=8]]; // 0xD3
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ZPX,  cycles=4]]; // 0xD4
    [[CpuInstruction name="CMP",  impl=@@cpu_i_CMP, addrMode=cpu_a_ZPX,  cycles=4]]; // 0xD5
    [[CpuInstruction name="DEC",  impl=@@cpu_i_DEC, addrMode=cpu_a_ZPX,  cycles=6]]; // 0xD6
    [[CpuInstruction name="DCP?", impl=@@cpu_i_DCP, addrMode=cpu_a_ZPX,  cycles=6]]; // 0xD7
    [[CpuInstruction name="CLD",  impl=@@cpu_i_CLD, addrMode=cpu_a_IMP,  cycles=2]]; // 0xD8
    [[CpuInstruction name="CMP",  impl=@@cpu_i_CMP, addrMode=cpu_a_ABSY, cycles=4]]; // 0xD9
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMP,  cycles=2]]; // 0xDA
    [[CpuInstruction name="DCP?", impl=@@cpu_i_DCP, addrMode=cpu_a_ABSY, cycles=7]]; // 0xDB
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ABSX, cycles=4]]; // 0xDC
    [[CpuInstruction name="CMP",  impl=@@cpu_i_CMP, addrMode=cpu_a_ABSX, cycles=4]]; // 0xDD
    [[CpuInstruction name="DEC",  impl=@@cpu_i_DEC, addrMode=cpu_a_ABSX, cycles=7]]; // 0xDE
    [[CpuInstruction name="DCP?", impl=@@cpu_i_DCP, addrMode=cpu_a_ABSX, cycles=7]]; // 0xDF

    [[CpuInstruction name="CPX",  impl=@@cpu_i_CPX, addrMode=cpu_a_IMM,  cycles=2]]; // 0xE0
    [[CpuInstruction name="SBC",  impl=@@cpu_i_SBC, addrMode=cpu_a_INDX, cycles=6]]; // 0xE1
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMM,  cycles=2]]; // 0xE2
    [[CpuInstruction name="ISB?", impl=@@cpu_i_ISB, addrMode=cpu_a_INDX, cycles=8]]; // 0xE3
    [[CpuInstruction name="CPX",  impl=@@cpu_i_CPX, addrMode=cpu_a_ZP,   cycles=3]]; // 0xE4
    [[CpuInstruction name="SBC",  impl=@@cpu_i_SBC, addrMode=cpu_a_ZP,   cycles=3]]; // 0xE5
    [[CpuInstruction name="INC",  impl=@@cpu_i_INC, addrMode=cpu_a_ZP,   cycles=5]]; // 0xE6
    [[CpuInstruction name="ISB?", impl=@@cpu_i_ISB, addrMode=cpu_a_ZP,   cycles=5]]; // 0xE7
    [[CpuInstruction name="INX",  impl=@@cpu_i_INX, addrMode=cpu_a_IMP,  cycles=2]]; // 0xE8
    [[CpuInstruction name="SBC",  impl=@@cpu_i_SBC, addrMode=cpu_a_IMM,  cycles=2]]; // 0xE9
    [[CpuInstruction name="NOP",  impl=@@cpu_i_NOP, addrMode=cpu_a_IMP,  cycles=2]]; // 0xEA
    [[CpuInstruction name="SBC?", impl=@@cpu_i_SBC, addrMode=cpu_a_IMM,  cycles=2]]; // 0xEB
    [[CpuInstruction name="CPX",  impl=@@cpu_i_CPX, addrMode=cpu_a_ABS,  cycles=4]]; // 0xEC
    [[CpuInstruction name="SBC",  impl=@@cpu_i_SBC, addrMode=cpu_a_ABS,  cycles=4]]; // 0xED
    [[CpuInstruction name="INC",  impl=@@cpu_i_INC, addrMode=cpu_a_ABS,  cycles=6]]; // 0xEE
    [[CpuInstruction name="ISB?", impl=@@cpu_i_ISB, addrMode=cpu_a_ABS,  cycles=6]]; // 0xEF

    [[CpuInstruction name="BEQ",  impl=@@cpu_i_BEQ, addrMode=cpu_a_REL,  cycles=2]]; // 0xF0
    [[CpuInstruction name="SBC",  impl=@@cpu_i_SBC, addrMode=cpu_a_INDY, cycles=5]]; // 0xF1
    [[CpuInstruction name="STP?", impl=@@cpu_i_STP, addrMode=cpu_a_IMP,  cycles=1]]; // 0xF2
    [[CpuInstruction name="ISB?", impl=@@cpu_i_ISB, addrMode=cpu_a_INDY, cycles=8]]; // 0xF3
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ZPX,  cycles=4]]; // 0xF4
    [[CpuInstruction name="SBC",  impl=@@cpu_i_SBC, addrMode=cpu_a_ZPX,  cycles=4]]; // 0xF5
    [[CpuInstruction name="INC",  impl=@@cpu_i_INC, addrMode=cpu_a_ZPX,  cycles=6]]; // 0xF6
    [[CpuInstruction name="ISB?", impl=@@cpu_i_ISB, addrMode=cpu_a_ZPX,  cycles=6]]; // 0xF7
    [[CpuInstruction name="SED",  impl=@@cpu_i_SED, addrMode=cpu_a_IMP,  cycles=2]]; // 0xF8
    [[CpuInstruction name="SBC",  impl=@@cpu_i_SBC, addrMode=cpu_a_ABSY, cycles=4]]; // 0xF9
    [[CpuInstruction name="NOP?", impl=@@cpu_i_NOP, addrMode=cpu_a_IMP,  cycles=2]]; // 0xFA
    [[CpuInstruction name="ISB?", impl=@@cpu_i_ISB, addrMode=cpu_a_ABSY, cycles=7]]; // 0xFB
    [[CpuInstruction name="NOP?", impl=@@cpu_i_IGN, addrMode=cpu_a_ABSX, cycles=4]]; // 0xFC
    [[CpuInstruction name="SBC",  impl=@@cpu_i_SBC, addrMode=cpu_a_ABSX, cycles=4]]; // 0xFD
    [[CpuInstruction name="INC",  impl=@@cpu_i_INC, addrMode=cpu_a_ABSX, cycles=7]]; // 0xFE
    [[CpuInstruction name="ISB?", impl=@@cpu_i_ISB, addrMode=cpu_a_ABSX, cycles=7]]  // 0xFF
]]


def cpu_get_flag(var cpu: Cpu6502; flag: CpuFlags): int
    return (cpu.status & (1 << int(flag))) >> int(flag)

def cpu_get_flag_bool(var cpu: Cpu6502; flag: CpuFlags): bool
    return (cpu.status & (1 << int(flag))) != 0

def cpu_set_flag(var cpu: Cpu6502; flag: CpuFlags; value: int)
    let fmsk = ~(1 << int(flag))
    let f = value << int(flag)
    cpu.status &= fmsk
    cpu.status |= f

def cpu_set_flag(var cpu: Cpu6502; flag: CpuFlags; value: bool)
    let v = value ? 1 : 0
    let fmsk = ~(1 << int(flag))
    let f = v << int(flag)
    cpu.status &= fmsk
    cpu.status |= f

def cpu_st_push(var cpu: Cpu6502; val: int)
    cpu_write(cpu, int(0x0100) + cpu.sp, val)
    cpu.sp = (cpu.sp - 1) & int(0xFF)

def cpu_st_pop(var cpu: Cpu6502): int
    cpu.sp = (cpu.sp + 1) & int(0xFF)
    return cpu_read(cpu, int(0x0100) + cpu.sp)

def cpu_step(var cpu: Cpu6502)
    if cpu.dbgMode
        cpu_step_dbg(cpu)
        return
    if cpu.halt
        return
    let storedPc = cpu.pc
    let opcode = cpu_read(cpu, cpu.pc)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    let instruction = cpu_instruction_table[opcode]
    cpu.cycles = instruction.cycles
    let additionalClockCycle1 = invoke(instruction.addrMode.setup, cpu)
    let additionalClockCycle2 = invoke(instruction.impl, cpu, instruction.addrMode)
    cpu.cycles += additionalClockCycle1 & additionalClockCycle2
    cpu.totalCycles += cpu.cycles
    cpu.prevOpcode = opcode
    cpu.prevPc = storedPc
    print("{cpu.prevPc} {instruction.name}\n")

def cpu_step_dbg(var cpu: Cpu6502)
    if cpu.halt
        return
    let storedPc = cpu.pc
    let storedA = cpu.a
    let storedX = cpu.x
    let storedY = cpu.y
    let storedSP = cpu.sp
    let storedP = cpu.status
    let storedCycles = cpu.totalCycles
    let opcode = cpu_read(cpu, cpu.pc)
    cpu.pc = (cpu.pc + 1) & int(0xFFFF)
    let instruction = cpu_instruction_table[opcode]
    cpu.cycles = instruction.cycles
    let additionalClockCycle1 = invoke(instruction.addrMode.setup, cpu)
    let additionalClockCycle2 = invoke(instruction.impl, cpu, instruction.addrMode)
    cpu.cycles += additionalClockCycle1 & additionalClockCycle2
    cpu.totalCycles += cpu.cycles
    cpu.prevOpcode = opcode
    cpu.prevPc = storedPc

    let instructionLen = instruction.addrMode.bytes + 1
    let f = fopen("6502.log", "at")
    let pcStr = format("%04X", storedPc)
    var instrDump = ""
    for i in range(0, 3)
        if i < instructionLen
            instrDump += format("%02X ", cpu.bus->peek(storedPc + i))
        else
            instrDump += "   "
    var instrName = instruction.name
    if length(instrName) == 3
        instrName += " "
    var instrArgs = invoke(instruction.addrMode.fmt, cpu, (storedPc + 1) & int(0xFFFF))
    if length(instrArgs) < 15
        let missingSpaces = 15 - length(instrArgs)
        for i in range(0, missingSpaces)
            instrArgs += " "
    var instrDisasm = instrName + " " + instrArgs
    let aStr = format("%02X", storedA)
    let xStr = format("%02X", storedX)
    let yStr = format("%02X", storedY)
    let pStr = format("%02X", storedP)
    let spStr = format("%02X", storedSP)
    fwrite(f, "{pcStr}  {instrDump} {instrDisasm} A:{aStr} X:{xStr} Y:{yStr} P:{pStr} SP:{spStr} CYC:{storedCycles}\n")
    fclose(f)

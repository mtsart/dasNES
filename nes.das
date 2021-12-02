require bus
require ram
require rom
require cpu_6502
require cartridge

let MASTER_CLOCK_SPEED = 21477272 // 21.477272 MHz for NTSC version
let PPU_CLOCK_SPEED = MASTER_CLOCK_SPEED / 4

class Nes
    cpuBus: Bus?
    ppuBus: Bus?
    ram: Ram?
    cpu: Cpu6502?
    globalClock: uint64
    cpuIdleClocks: int
    mapperCpuBusId: int
    mapperPpuBusId: int
    cartridge: Cartridge?

    def init()
        cpuBus = new Bus()
        ppuBus = new Bus()
        ram = new Ram()
        cpuBus->attach(ram)
        cpu = new Cpu6502()
        cpu->attachBus(cpuBus)
        mapperCpuBusId = -1
        mapperPpuBusId = -1

    def reset()
        cpu->reset()
        globalClock = 0ul
        cpuIdleClocks = 0

    def clock(clocks: int)
        var clockLeft = clocks
        while globalClock % 3ul != 0ul && clockLeft > 0
            // TODO: clock the PPU once
            globalClock++
            clockLeft--
        while clockLeft > 0
            if cpuIdleClocks > 0
                if cpuIdleClocks <= clockLeft
                    // TODO: clock the PPU cpuIdleClocks times
                    globalClock += uint64(cpuIdleClocks)
                    clockLeft -= cpuIdleClocks
                    cpuIdleClocks = 0
                else
                    // TODO: clock the PPU clockLeft times
                    globalClock += uint64(cpuIdleClocks)
                    cpuIdleClocks -= clockLeft
                    clockLeft = 0
            else
                cpu_step(*cpu)
                cpuIdleClocks = cpu.cycles * 3
                

    def insertCartridge(rom: NesRom?)
        if mapperCpuBusId >= 0
            cpuBus->detach(mapperCpuBusId)
        if mapperPpuBusId >= 0
            ppuBus->detach(mapperPpuBusId)
        cartridge = new Cartridge()
        cartridge->init(rom)
        cpuBus->setMapper(cartridge.cpuMapper)
        ppuBus->setMapper(cartridge.ppuMapper)
        mapperCpuBusId = cpuBus->attach(cartridge.cpuMapper->getBusDevice())
        mapperPpuBusId = ppuBus->attach(cartridge.ppuMapper->getBusDevice())

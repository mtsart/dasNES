require bus
require ram
require rom
require cpu_6502
require dma
require ppu
require cartridge
require controllers

//let MASTER_CLOCK_SPEED = 3477272 // 21.477272 MHz for NTSC version
let MASTER_CLOCK_SPEED = 21477272 // 21.477272 MHz for NTSC version
let PPU_CLOCK_SPEED = MASTER_CLOCK_SPEED / 4
let MIN_UPDATES_PER_SECOND = 30
let MAX_CLOCK_PER_UPDATE = int64(PPU_CLOCK_SPEED / MIN_UPDATES_PER_SECOND)

class Nes
    cpuBus: Bus?
    ppuBus: Bus?
    ram: Ram?
    cpu: Cpu6502?
    ppu: Ppu2C02?
    dma: DmaEngine?
    controllers: Controllers?
    globalClock: uint64
    cpuIdleClocks: int
    mapperCpuBusId: int
    mapperPpuBusId: int
    cartridge: Cartridge?
    timeLeft: double
    timePassed: double

    def init()
        cpuBus = new Bus()
        ppuBus = new Bus()
        ram = new Ram()
        cpuBus->attach(ram)
        cpu = new Cpu6502()
        cpu->attachBus(cpuBus)
        ppu = new Ppu2C02()
        ppu->init()
        ppu->attachBus(ppuBus)
        cpuBus->attach(ppu)
        ppu->attachCpu(cpu)
        ppuBus->attach(ppu->getPpuBusDevice())
        controllers = new Controllers()
        cpuBus->attach(controllers)
        dma = new DmaEngine()
        dma->attachCpuBus(cpuBus)
        dma->attachPpu(ppu)
        cpuBus->attach(dma)

        mapperCpuBusId = -1
        mapperPpuBusId = -1

    def reset()
        cpu->reset()
        ppu->reset()
        dma->reset()
        globalClock = 0ul
        cpuIdleClocks = 0
        timeLeft = 0lf
        timePassed = 0lf

    def update(dt: float)
        timeLeft += double(dt)
        var nesClocks = int64(timeLeft * double(PPU_CLOCK_SPEED))
        if nesClocks > MAX_CLOCK_PER_UPDATE
            nesClocks = MAX_CLOCK_PER_UPDATE
        if cpu.halt
            nesClocks = 0l
        if nesClocks > 1000l
            nesClocks = 1000l
        let updateTime = double(nesClocks) / double(PPU_CLOCK_SPEED)
        timeLeft -= updateTime
        timePassed += updateTime
        controllers->update()
        clock(int(nesClocks))

    def clock(clocks: int)
        var clockLeft = clocks
        while globalClock % 3ul != 0ul && clockLeft > 0
            ppu->clock(1)
            globalClock++
            clockLeft--
        while clockLeft > 0
            if cpuIdleClocks > 0
                if cpuIdleClocks <= clockLeft
                    ppu->clock(cpuIdleClocks)
                    globalClock += uint64(cpuIdleClocks)
                    clockLeft -= cpuIdleClocks
                    cpuIdleClocks = 0
                else
                    ppu->clock(clockLeft)
                    globalClock += uint64(cpuIdleClocks)
                    cpuIdleClocks -= clockLeft
                    clockLeft = 0
            else
                if dma.active
                    if dma.sync
                        if (globalClock & 1ul) == 1ul
                            dma.sync = false
                        cpuIdleClocks = 1
                    else
                        dma->step()
                        cpuIdleClocks = 2
                else
                    cpu_step(*cpu)
                    cpuIdleClocks = cpu.cycles * 3


    def drawScreen(x: int; y: int; scale: float)
        ppu->drawScreen(x, y, scale)


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

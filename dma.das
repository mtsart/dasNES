require device
require ppu
require bus

class DmaEngine: Device
    ppu: Ppu2C02?
    cpuBus: Bus?
    active: bool
    sync: bool
    dmaPage: int
    dmaAddr: int

    def attachCpuBus(b: Bus?)
        cpuBus = b

    def attachPpu(p: Ppu2C02?)
        ppu = p

    def reset()
        active = false
        sync = false

    def step()
        let data = cpuBus->read(dmaPage << 8 | dmaAddr)
        ppu.oam[dmaAddr] = data
        dmaAddr++
        if dmaAddr >= int(0x100)
            active = false

    def override checkAddress(address: int): bool
        return address == int(0x4014)
    
    def override read(address: int): int
        return 0
    
    def override write(address: int; data: int): void
        dmaPage = data
        dmaAddr = 0
        active = true
        sync = true

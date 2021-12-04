require mapper
require rom
require device

class Mapper_002_CpuBusDevice: Device
    rom: NesRom?
    prgRam: int[8192]
    selectedBank: int
    lastBank: int

    def init(r: NesRom?)
        rom = r
        selectedBank = 0
        lastBank = length(rom.prgRom) - 1

    def override checkAddress(address: int): bool
        return (address >= int(0x6000)) && (address <= int(0xFFFF))

    def override read(address: int): int
        if address >= int(0x6000)
            if address < int(0x8000)
                if rom.havePrgRam
                    return prgRam[address - int(0x6000)]
                return 0
            if address < int(0xC000)
                return int(rom.prgRom[selectedBank].v[address - int(0x8000)])
            return int(rom.prgRom[lastBank].v[address - int(0xC000)])
        return 0

    def override write(address: int; data: int): void
        if address >= int(0x6000) && address < int(0x8000)
            if rom.havePrgRam
                prgRam[address - int(0x6000)] = data
        else
            selectedBank = data & int(0x0F)


class Mapper_002_PpuBusDevice: Device
    rom: NesRom?
    chrRam: int[8192]

    def init(r: NesRom?)
        rom = r

    def override checkAddress(address: int): bool
        return address >= 0 && address <= int(0x1FFF)

    def override read(address: int): int
        if length(rom.chrRom) > 0
            return int(rom.chrRom[0].v[address])
        return chrRam[address]

    def override write(address: int; data: int): void
        if length(rom.chrRom) == 0
            chrRam[address] = data
        return


class Mapper_002_CpuBus: CpuMapper
    cpuBusDevice: Mapper_002_CpuBusDevice?

    def override init(r: NesRom?)
        Mapper`init(self, r)
        cpuBusDevice = new Mapper_002_CpuBusDevice()
        cpuBusDevice->init(r)

    def override getBusDevice(): Device?
        return cpuBusDevice


class Mapper_002_PpuBus: PpuMapper
    ppuBusDevice: Mapper_002_PpuBusDevice?

    def override init(r: NesRom?)
        Mapper`init(self, r)
        ppuBusDevice = new Mapper_002_PpuBusDevice()
        ppuBusDevice->init(r)

    def override getBusDevice(): Device?
        return ppuBusDevice

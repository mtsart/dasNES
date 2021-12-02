require mapper
require rom
require device

class Mapper_000_CpuBusDevice: Device
    rom: NesRom?
    prgRam: int[8192]

    def init(r: NesRom?)
        rom = r

    def override checkAddress(address: int): bool
        return (address >= int(0x6000)) && (address <= int(0xFFFF))

    def override read(address: int): int
        if address >= int(0x6000)
            if address < int(0x8000)
                if rom.havePrgRam
                    return prgRam[address - int(0x6000)]
                return 0
            if length(rom.prgRom) > 0
                if address < int(0xC000)
                    return int(rom.prgRom[0].v[address - int(0x8000)])
                let chunkIdx = length(rom.prgRom) > 1 ? 1 : 0
                let offset = address - int(0xC000)
                return int(rom.prgRom[chunkIdx].v[address - int(0xC000)])
        return 0

    def override write(address: int; data: int): void
        if rom.havePrgRam
            if address >= int(0x6000) && address < int(0x8000)
                prgRam[address - int(0x6000)] = data


class Mapper_000_PpuBusDevice: Device
    rom: NesRom?

    def init(r: NesRom?)
        rom = r

    def override checkAddress(address: int): bool
        return address >= 0 && address <= int(0x1FFF)

    def override read(address: int): int
        if length(rom.chrRom) > 0
            return int(rom.chrRom[0].v[address])
        return 0

    def override write(address: int; data: int): void
        return


class Mapper_000_CpuBus: CpuMapper
    cpuBusDevice: Mapper_000_CpuBusDevice?

    def override init(r: NesRom?)
        Mapper`init(self, r)
        cpuBusDevice = new Mapper_000_CpuBusDevice()
        cpuBusDevice->init(r)

    def override getBusDevice(): Device?
        return cpuBusDevice


class Mapper_000_PpuBus: PpuMapper
    ppuBusDevice: Mapper_000_PpuBusDevice?

    def override init(r: NesRom?)
        Mapper`init(self, r)
        ppuBusDevice = new Mapper_000_PpuBusDevice()
        ppuBusDevice->init(r)

    def override getBusDevice(): Device?
        return ppuBusDevice

require rom
require mapper

require mapper_000

class Cartridge
    cpuMapper: Mapper?
    ppuMapper: Mapper?

    def init(rom: NesRom?)
        if rom.mapper == 0
            cpuMapper = cast<Mapper?>(new Mapper_000_CpuBus())
            cpuMapper->init(rom)
            ppuMapper = cast<Mapper?>(new Mapper_000_PpuBus())
            ppuMapper->init(rom)
        else // use mapper 0 by default
            cpuMapper = cast<Mapper?>(new Mapper_000_CpuBus())
            cpuMapper->init(rom)
            ppuMapper = cast<Mapper?>(new Mapper_000_PpuBus())
            ppuMapper->init(rom)

require rom
require device

class Mapper
    rom: NesRom?

    def init(r: NesRom?)
        rom = r
    
    def abstract mapAddress(address: int): int

    def abstract getBusDevice(): Device?


class CpuMapper: Mapper
    def override mapAddress(address: int): int
        return address


class PpuMapper: Mapper
    def transformCIRAMAddr(address: int): int
        if rom.useMirroring
            if rom.verticalMirroring
                return address & ~int(0x800)
            else
                var mirroredAddr = address & ~int(0x400)
                if mirroredAddr >= int(0x2800)
                    mirroredAddr -= int(0x400)
                return mirroredAddr
        return address

    def transformPaletteAddr(address: int): int
        var res = address
        if res >= int(0x3F20)
            res &= int(0xFF1F)
        if (res & int(0x13)) == int(0x10)
            res ^= int(0x10)
        return res

    def doStandardPpuTransform(address: int): int
        if (address >= int(0x2000)) && (address <= int(0x2FFF))
            return transformCIRAMAddr(address)
        if (address >= int(0x3000)) && (address <= int(0x3EFF))
            return transformCIRAMAddr(address - int(0x1000))
        if (address >= int(0x3F00)) && (address <= int(0x3FFF))
            return transformPaletteAddr(address)
        return -1

    def override mapAddress(address: int): int
        let transformedAddr = doStandardPpuTransform(address)
        if transformedAddr >= 0
            return transformedAddr
        return address

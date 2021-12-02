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
    def override mapAddress(address: int): int
        return address

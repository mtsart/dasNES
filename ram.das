require device

let TOTAL_RAM = 2048

class Ram: Device
    ram: int[TOTAL_RAM]

    def override checkAddress(address: int): bool
        return address >= 0 && address < TOTAL_RAM
    
    def override read(address: int): int
        return ram[address]
    
    def override write(address: int; data: int): void
        ram[address] = data

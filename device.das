class Device
    def abstract checkAddress(address: int): bool
    def abstract read(address: int): int
    def abstract write(address: int; data: int): void

    def peek(address: int): int
        return read(address)

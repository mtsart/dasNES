require device
require daslib/media

class Controllers: Device
    state: uint[2]
    saved_state: uint[2]

    def update()
        state[0] = 0x00
        state[0] |= get_key(VK_D) ? 0x01 : 0x00 // right
        state[0] |= get_key(VK_A) ? 0x02 : 0x00 // left
        state[0] |= get_key(VK_S) ? 0x04 : 0x00 // down
        state[0] |= get_key(VK_W) ? 0x08 : 0x00 // up
        state[0] |= get_key(VK_T) ? 0x10 : 0x00 // start
        state[0] |= get_key(VK_R) ? 0x20 : 0x00 // select
        state[0] |= get_key(VK_G) ? 0x40 : 0x00 // B
        state[0] |= get_key(VK_F) ? 0x80 : 0x00 // A
        state[1] = 0x00
        return

    def override checkAddress(address: int): bool
        return address >= int(0x4016) && address <= int(0x4017)
    
    def override read(address: int): int
        let data = int((saved_state[address & 1] & 0x80) >> 0x07)
        saved_state[address & 1] <<= 0x01
        return data
    
    def override write(address: int; data: int): void
        saved_state[address & 1] = state[address & 1]

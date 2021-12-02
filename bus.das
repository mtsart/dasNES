require mapper
require device


class Bus
    mapper: Mapper?
    devices: array<Device?>

    def setMapper(m: Mapper?)
        mapper = m

    def attach(device: Device?): int
        for i in range(0, length(devices))
            if devices[i] == null
                devices[i] = device
                return i
        push(devices, device)
        return length(devices) - 1

    def detach(id: int)
        devices[id] = null

    def write(address: int; data: int)
        let sanitizedAddr = address & int(0xFFFF)
        let sanitizedData = data & int(0xFF)
        let effectiveAddr = mapper->mapAddress(sanitizedAddr)
        for device in devices
            if device != null && device->checkAddress(effectiveAddr)
                device->write(effectiveAddr, sanitizedData)
                return

    def read(address: int)
        let sanitizedAddr = address & int(0xFFFF)
        let effectiveAddr = mapper->mapAddress(sanitizedAddr)
        for device in devices
            if device != null && device->checkAddress(effectiveAddr)
                return device->read(effectiveAddr) & int(0xFF)
        return 0

    def peek(address: int)
        let sanitizedAddr = address & int(0xFFFF)
        let effectiveAddr = mapper->mapAddress(sanitizedAddr)
        for device in devices
            if device != null && device->checkAddress(effectiveAddr)
                return device->peek(effectiveAddr) & int(0xFF)
        return 0

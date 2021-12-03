require device
require bus
require cpu
require daslib/media


let PIXELS_PER_SCANLINE = 341
let VISIBLE_PIXELS = 256
let TOTAL_SCANLINES = 262
let VISIBLE_SCANLINES = 240


struct PpuRegs
    control: int
    mask: int
    status: int
    oamAddr: int
    oamData: int
    scroll: int
    ppuData: int
    vAddr: int
    tAddr: int
    fineX: int
    w: bool

struct BgState
    tileId: int
    tileAttr: int
    tileLsb: int
    tileMsb: int
    shiftLsb: int
    shiftMsb: int
    shiftLAttr: int
    shiftHAttr: int

enum PpuControl
    EnableNMI = int(0x80)
    DblSprite = int(0x20)
    BgTbl     = int(0x10)
    FgTbl     = int(0x08)
    BigStep   = int(0x04)
    NameTbl   = int(0x03)

enum PpuMask
    EmphBlue  = int(0x80)
    EmphGreen = int(0x40)
    EmphRed   = int(0x20)
    ShowFg    = int(0x10)
    ShowBg    = int(0x08)
    FgLeft    = int(0x04)
    BgLeft    = int(0x02)
    Grayscale = int(0x01)

enum PpuStatus
    VBlank    = int(0x80)
    S0Hit     = int(0x40)
    SOverflow = int(0x20)


class Ppu2C02PpuBusDevice: Device
    vram: int[2048]
    palette: int[32]

    def override checkAddress(address: int): bool
        if (address >= int(0x2000)) && (address <= int(0x27FF))
            return true
        return (address >= int(0x3F00)) && (address <= int(0x3F1F))

    def override read(address: int): int
        if (address >= int(0x2000)) && (address <= int(0x27FF))
            return vram[address - int(0x2000)]
        return palette[address - int(0x3F00)]

    def override write(address: int; data: int): void
        if (address >= int(0x2000)) && (address <= int(0x27FF))
            vram[address - int(0x2000)] = data
        else
            palette[address - int(0x3F00)] = data


class Ppu2C02: Device
    ppuBus: Bus?
    ppuBusDevice: Ppu2C02PpuBusDevice?
    cpu: Cpu?
    cycle: int
    scanline: int
    frameComplete: bool
    reg: PpuRegs
    screen: Image
    backbuffer: Image
    bg: BgState
    rgbPalette: uint[64]
    ppuWrites: int

    def init()
        backbuffer <- create_image(256, 240)
        backbuffer |> set_image_smooth(true)
        screen := backbuffer
        initRgbPalette()

    def initRgbPalette()
        rgbPalette[0x00] = make_color32(84,  84,  84)
        rgbPalette[0x01] = make_color32(0,   30,  116)
        rgbPalette[0x02] = make_color32(8,   16,  144)
        rgbPalette[0x03] = make_color32(48,  0,   136)
        rgbPalette[0x04] = make_color32(68,  0,   100)
        rgbPalette[0x05] = make_color32(92,  0,   48)
        rgbPalette[0x06] = make_color32(84,  4,   0)
        rgbPalette[0x07] = make_color32(60,  24,  0)
        rgbPalette[0x08] = make_color32(32,  42,  0)
        rgbPalette[0x09] = make_color32(8,   58,  0)
        rgbPalette[0x0A] = make_color32(0,   64,  0)
        rgbPalette[0x0B] = make_color32(0,   60,  0)
        rgbPalette[0x0C] = make_color32(0,   50,  60)
        rgbPalette[0x0D] = make_color32(0,   0,   0)
        rgbPalette[0x0E] = make_color32(0,   0,   0)
        rgbPalette[0x0F] = make_color32(0,   0,   0)

        rgbPalette[0x10] = make_color32(152, 150, 152)
        rgbPalette[0x11] = make_color32(8,   76,  196)
        rgbPalette[0x12] = make_color32(48,  50,  236)
        rgbPalette[0x13] = make_color32(92,  30,  228)
        rgbPalette[0x14] = make_color32(136, 20,  176)
        rgbPalette[0x15] = make_color32(160, 20,  100)
        rgbPalette[0x16] = make_color32(152, 34,  32)
        rgbPalette[0x17] = make_color32(120, 60,  0)
        rgbPalette[0x18] = make_color32(84,  90,  0)
        rgbPalette[0x19] = make_color32(40,  114, 0)
        rgbPalette[0x1A] = make_color32(8,   124, 0)
        rgbPalette[0x1B] = make_color32(0,   118, 40)
        rgbPalette[0x1C] = make_color32(0,   102, 120)
        rgbPalette[0x1D] = make_color32(0,   0,   0)
        rgbPalette[0x1E] = make_color32(0,   0,   0)
        rgbPalette[0x1F] = make_color32(0,   0,   0)

        rgbPalette[0x20] = make_color32(236, 238, 236)
        rgbPalette[0x21] = make_color32(76,  154, 236)
        rgbPalette[0x22] = make_color32(120, 124, 236)
        rgbPalette[0x23] = make_color32(176, 98,  236)
        rgbPalette[0x24] = make_color32(228, 84,  236)
        rgbPalette[0x25] = make_color32(236, 88,  180)
        rgbPalette[0x26] = make_color32(236, 106, 100)
        rgbPalette[0x27] = make_color32(212, 136, 32)
        rgbPalette[0x28] = make_color32(160, 170, 0)
        rgbPalette[0x29] = make_color32(116, 196, 0)
        rgbPalette[0x2A] = make_color32(76,  208, 32)
        rgbPalette[0x2B] = make_color32(56,  204, 108)
        rgbPalette[0x2C] = make_color32(56,  180, 204)
        rgbPalette[0x2D] = make_color32(60,  60,  60)
        rgbPalette[0x2E] = make_color32(0,   0,   0)
        rgbPalette[0x2F] = make_color32(0,   0,   0)

        rgbPalette[0x30] = make_color32(236, 238, 236)
        rgbPalette[0x31] = make_color32(168, 204, 236)
        rgbPalette[0x32] = make_color32(188, 188, 236)
        rgbPalette[0x33] = make_color32(212, 178, 236)
        rgbPalette[0x34] = make_color32(236, 174, 236)
        rgbPalette[0x35] = make_color32(236, 174, 212)
        rgbPalette[0x36] = make_color32(236, 180, 176)
        rgbPalette[0x37] = make_color32(228, 196, 144)
        rgbPalette[0x38] = make_color32(204, 210, 120)
        rgbPalette[0x39] = make_color32(180, 222, 120)
        rgbPalette[0x3A] = make_color32(168, 226, 144)
        rgbPalette[0x3B] = make_color32(152, 226, 180)
        rgbPalette[0x3C] = make_color32(160, 214, 228)
        rgbPalette[0x3D] = make_color32(160, 162, 160)
        rgbPalette[0x3E] = make_color32(0,   0,   0)
        rgbPalette[0x3F] = make_color32(0,   0,   0)

    def drawScreen(x: int; y: int; scale: float)
        var size: int2
        size.x = int(float(VISIBLE_PIXELS) * scale)
        size.y = int(float(VISIBLE_SCANLINES) * scale)
        //screen |> draw_image(x, y, make_color(1.0), size)
        backbuffer |> draw_image(x, y, make_color(1.0), size)

    def attachBus(b: Bus?)
        ppuBus = b
    
    def getPpuBusDevice(): Device?
        if ppuBusDevice == null
            ppuBusDevice = new Ppu2C02PpuBusDevice()
        return ppuBusDevice

    def attachCpu(c: Cpu?)
        cpu = c

    def reset()
        print("PPU reset\n")
        reg.status = 0
        reg.w = false

    def clock(clocksPassed: int)
        for i in range(0, clocksPassed)
            cycle++
            if cycle >= PIXELS_PER_SCANLINE
                cycle = 0
                scanline++
                if scanline >= TOTAL_SCANLINES
                    scanline = -1
                    frameComplete = true
            if cycle == 1 && scanline == VISIBLE_SCANLINES + 1
                reg.status |= int(PpuStatus VBlank)
                if (reg.control & int(PpuControl EnableNMI)) != 0
                    cpu->nmi()
                screen := backbuffer
            if cycle == 1 && scanline == -1
                reg.status &= ~int(PpuStatus VBlank)
            if scanline < VISIBLE_SCANLINES
                let renderEnabled = isRenderEnabled()
                if (cycle >= 2 && cycle < 258) || (cycle >= 321 && cycle < 338)
                    if renderEnabled
                        bg.shiftLsb <<= 1
                        bg.shiftMsb <<= 1
                        bg.shiftLAttr <<= 1
                        bg.shiftHAttr <<= 1
                    let step = (cycle - 1) & 7
                    if step == 0
                        bg.shiftLsb = (bg.shiftLsb & int(0xFF00)) | bg.tileLsb
                        bg.shiftMsb = (bg.shiftMsb & int(0xFF00)) | bg.tileMsb
                        bg.shiftLAttr = (bg.shiftLAttr & int(0xFF00)) | (((bg.tileAttr & 1) == 0) ? 0 : int(0xFF))
                        bg.shiftHAttr = (bg.shiftHAttr & int(0xFF00)) | (((bg.tileAttr & 2) == 0) ? 0 : int(0xFF))
                        bg.tileId = ppuBus->read(int(0x2000) | (reg.vAddr & int(0x0FFF)))
                    elif step == 2
                        // see https://wiki.nesdev.org/w/index.php?title=PPU_scrolling for details
                        var attrAddress = int(0x23C0) // 960 bytes into vram
                        attrAddress |= reg.vAddr & int(0x0C00) // nametable select
                        attrAddress |= (reg.vAddr >> 4) & int(0x38) // high 3 bits of coarseY
                        attrAddress |= (reg.vAddr >> 2) & int(0x07) // high 3 bits of coarseX
                        bg.tileAttr = ppuBus->read(attrAddress)
                        if (reg.vAddr & int(0x40)) != 0 // coarseY & 0x02
                            bg.tileAttr >>= 4
                        if (reg.vAddr & int(0x02)) != 0 // coarseX & 0x02
                            bg.tileAttr >>= 2
                        bg.tileAttr &= 3
                    elif step == 4
                        let controlBgTbl = (reg.control & int(PpuControl BgTbl)) << 8 // either 0x0000 or 0x1000
                        let lsbOffset = (bg.tileId << 4) + ((reg.vAddr >> 12) & 7)
                        bg.tileLsb = ppuBus->read(controlBgTbl + lsbOffset)
                    elif step == 6
                        let controlBgTbl = (reg.control & int(PpuControl BgTbl)) << 8 // either 0x0000 or 0x1000
                        let msbOffset = (bg.tileId << 4) + ((reg.vAddr >> 12) & 7) + 8
                        bg.tileMsb = ppuBus->read(controlBgTbl + msbOffset)
                    elif step == 7
                        if renderEnabled
                            coarseXInc()
                if cycle == 256
                    if renderEnabled
                        YInc()
                if cycle == 257
                    bg.shiftLsb = (bg.shiftLsb & int(0xFF00)) | bg.tileLsb
                    bg.shiftMsb = (bg.shiftMsb & int(0xFF00)) | bg.tileMsb
                    bg.shiftLAttr = (bg.shiftLAttr & int(0xFF00)) | (((bg.tileAttr & 1) == 0) ? 0 : int(0xFF))
                    bg.shiftHAttr = (bg.shiftHAttr & int(0xFF00)) | (((bg.tileAttr & 2) == 0) ? 0 : int(0xFF))
                    if renderEnabled
                        // move X component from tAddr to vAddr
                        reg.vAddr &= ~int(0x041F)
                        reg.vAddr |= reg.tAddr & int(0x041F)
                if scanline == -1 && cycle >= 280 && cycle <= 304
                    // move Y component from tAddr to vAddr
                    reg.vAddr &= int(0x041F)
                    reg.vAddr |= reg.tAddr & ~int(0x041F)
                if scanline >= 0 && cycle >= 0 && cycle < VISIBLE_PIXELS
                    renderPixel()

    def isRenderEnabled()
        return (reg.mask & (int(PpuMask ShowBg) | int(PpuMask ShowFg))) != 0

    def coarseXInc()
        // see https://wiki.nesdev.org/w/index.php?title=PPU_scrolling for details
        if (reg.vAddr & int(0x001F)) == 31
            reg.vAddr &= ~int(0x001F)
            reg.vAddr ^= int(0x0400)
        else
            reg.vAddr++

    def YInc()
        if (reg.vAddr & int(0x7000)) != int(0x7000)
            reg.vAddr += int(0x1000)
        else
            reg.vAddr &= ~int(0x7000)
            var coarseY = (reg.vAddr & int(0x03E0)) >> 5
            if coarseY == 29
                coarseY = 0
                reg.vAddr ^= int(0x0800)
            elif coarseY == 31
                coarseY = 0
            else
                coarseY++
            reg.vAddr &= ~int(0x03E0)
            reg.vAddr |= coarseY << 5

    def renderPixel()
        let currentBit = int(0x8000) >> reg.fineX
        let shiftL = 15 - reg.fineX
        let shiftH = 14 - reg.fineX
        let bgPixel = ((bg.shiftLsb & currentBit) >> shiftL) | ((bg.shiftMsb & currentBit) >> shiftH)
        let bgPalette = ((bg.shiftLAttr & currentBit) >> shiftL) | ((bg.shiftHAttr & currentBit) >> shiftH)
        let colorIdx = ppuBusDevice.palette[(bgPalette << 2) + bgPixel] & int(0x3F)
        let color = rgbPalette[colorIdx]
        backbuffer |> set_pixel(cycle, scanline, color)
        return

    def override checkAddress(address: int): bool
        return (address >= int(0x2000)) && (address <= int(0x3FFF))

    def override read(address: int): int
        let regId = address & 7
        var result: int = 0
        if regId == 2
            // content of lower 5 bits is undefined, some junk from ppuData will do
            let data = (reg.status & int(0xE0)) | (reg.ppuData & int(0x1F))
            // reading status clears VBlank and resets address latch
            reg.status &= ~int(PpuStatus VBlank)
            reg.w = false
            result = data
        elif regId == 7
            var data = reg.ppuData
            reg.ppuData = ppuBus->read(reg.vAddr)
            // reading palette, unlike the rest of ppu bus, makes data available on the same cpu cycle
            if (reg.vAddr >= int(0x3F00)) && (reg.vAddr <= int(0x3FFF))
                if (reg.mask & int(PpuMask Grayscale)) != 0
                    reg.ppuData &= int(0x30)
                data = reg.ppuData
            reg.vAddr += (reg.control & int(PpuControl BigStep)) == 0 ? 1 : 32
            result = data
        return result

    def override write(address: int; data: int)
        let regId = address & 7
        if regId == 0
            reg.control = data
            if (reg.control & int(PpuControl EnableNMI)) != 0
                if (reg.status & int(PpuStatus VBlank)) != 0
                    cpu->nmi()
            let nameTable = data & int(PpuControl NameTbl)
            reg.tAddr &= ~(int(0x03) << 10)
            reg.tAddr |= nameTable << 10
        elif regId == 1
            reg.mask = data
        elif regId == 5
            if reg.w
                let fineY = data & 7
                let coarseY = data >> 3
                reg.tAddr &= int(0x0C1F) // -000 1100 0001 1111 (3 bit fineY, 2 bit nametable, 5 bit coarseY, 5 bit coarseX)
                reg.tAddr |= fineY << 12
                reg.tAddr |= coarseY << 5
                reg.w = false
            else
                reg.fineX = data & 7
                let coarseX = data >> 3
                reg.tAddr &= int(0xFFE0)
                reg.tAddr |= coarseX
                reg.w = true
        elif regId == 6
            if reg.w
                reg.tAddr &= int(0xFF00)
                reg.tAddr |= data
                reg.vAddr = reg.tAddr
                print("Write 6 (second) data {uint(data)} tAddr {uint(reg.tAddr)}\n")
                reg.w = false
            else
                reg.tAddr &= int(0x00FF)
                reg.tAddr |= (data << 8) & int(0x3F00)  // highest bits are cleared
                print("Write 6 (first) data {uint(data)} tAddr {uint(reg.tAddr)}\n")
                reg.w = true
        elif regId == 7
            ppuWrites++
            ppuBus->write(reg.vAddr, data)
            reg.vAddr += (reg.control & int(PpuControl BigStep)) == 0 ? 1 : 32

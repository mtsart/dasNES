require daslib/media
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code
require nes
require rom
require cpu_6502


var
    nes: Nes?
    rom: NesRom?
    prevTime: float

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("dasNES")
    nes = new Nes()
    nes->init()
    rom = load_rom("rom/nestest.nes")
    nes->insertCartridge(rom)
    nes->reset()
    prevTime = get_time_after_start()
    return

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    // dt seems to be incorrect under heavy load
    let curTime = get_time_after_start()
    let dt2 = curTime - prevTime
    prevTime = curTime
    nes->update(dt2)
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    var memDump: string
    for i in range(0, 16)
        let byte = format(" %02X", nes.ram.ram[i])
        memDump += byte
    if get_key(VK_B)
        set_font_size(12)
        for y in range(0, 30)
            for x in range(0, 32)
                let id = nes.ppuBus->read(int(0x2000) + y * 32 + x)
                text_out(x * 16, y * 16, "{format("%02X", id)}", make_color(1.0))
    else
        nes->drawScreen(0, 0, 2.0)
    text_out(0, 560, "RAM at 0x0000:{memDump}", make_color(1.0))
    text_out(0, 575, "Total clocks: {nes.cpu.totalCycles} {nes.timePassed} {nes.timeLeft}", make_color(1.0))
    text_out(0, 590, "CPU: {uint(nes.cpu.prevPc)} {uint(nes.cpu.prevOpcode)} {cpu_instruction_table[nes.cpu.prevOpcode].name} {uint(nes.cpu.absAddr)}", make_color(1.0))
    let idFmt = format("%02X", nes.ppu.bg.tileId)
    let lsbFmt = format("%02X", nes.ppu.bg.tileLsb)
    let msbFmt = format("%02X", nes.ppu.bg.tileMsb)
    let vFmt = format("%04X", nes.ppu.reg.vAddr)
    let fxFmt = format("%d", nes.ppu.reg.fineX)
    let fyFmt = format("%d", (nes.ppu.reg.vAddr >> 12) & 7)
    let cxFmt = format("%02d", nes.ppu.reg.vAddr & 31)
    let cyFmt = format("%02d", (nes.ppu.reg.vAddr >> 5) & 31)
    text_out(0, 605, "PPU: {idFmt} {lsbFmt} {msbFmt} {vFmt} {fxFmt} {fyFmt} {cxFmt} {cyFmt} {nes.ppu.ppuWrites} {nes.ppu.cycle} {nes.ppu.scanline} {uint(nes.ppu.reg.control)} {uint(nes.ppu.reg.tAddr)}", make_color(1.0))

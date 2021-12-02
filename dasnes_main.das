require daslib/media
options debugger            // uncomment for debug in VS Code
require daslib/debug        // uncomment for debug in VS Code
require nes
require rom


var
    nes: Nes?
    rom: NesRom?

// 'initialize' runs once when game starts and every hot-reload
[export]
def initialize
    set_window_title("dasNES")
    nes = new Nes()
    nes->init()
    rom = load_rom("rom/nestest.nes")
    nes->insertCartridge(rom)
    nes->reset()
    return

// this function is called to update game data,
// dt - time elapsed since the previous update (in seconds)
[export]
def act(dt: float)
    if get_key(VK_ESCAPE)
        schedule_quit_game()
    nes->clock(2000000)
    return

// this function will be called every frame after 'act',
// you can draw anything in this function
[export]
def draw
    var memDump: string
    for i in range(0, 16)
        let byte = format(" %02X", nes.ram.ram[i])
        memDump += byte
    text_out(0, 60, "RAM at 0x0000:{memDump}", make_color(1.0))
    text_out(0, 75, "Total clocks: {nes.cpu.totalCycles}", make_color(1.0))

require fio

let
    PRG_ROM_CHUNK = 16384
    CHR_ROM_CHUNK = 8192
    TRAINER_SIZE = 512

struct NESFileHdr
    magic: uint8[4]
    prgRomChunks: uint8
    chrRomChunks: uint8
    flags6: uint8
    flags7: uint8
    unused: uint8[8]

struct PrgRomChunk
    v: uint8[PRG_ROM_CHUNK]

struct ChrRomChunk
    v: uint8[CHR_ROM_CHUNK]

struct NesRom
    isValid: bool
    error: string
    useMirroring: bool
    verticalMirroring: bool
    havePrgRam: bool
    haveTrainer: bool
    mapper: int
    trainer: uint8[TRAINER_SIZE]
    prgRom: array<PrgRomChunk>
    chrRom: array<ChrRomChunk>

def load_rom(fn: string): NesRom?
    var res: NesRom? = new NesRom
    res.isValid = false
    res.error = "Unknown error"
    let f = fopen(fn, "rb")
    if f == null
        res.error = "Cannot open {fn}"
        return res
    
    fmap(f) <| $(var data: array<uint8>#)
        let l = length(data)
        var fileHdr: NESFileHdr
        let hdrSize = typeinfo(sizeof fileHdr)
        if l < hdrSize
            res.error = "File is too short"
            return

        for i in range(0, 4)
            fileHdr.magic[i] = data[i]
        fileHdr.prgRomChunks = data[4]
        fileHdr.chrRomChunks = data[5]
        fileHdr.flags6 = data[6]
        fileHdr.flags7 = data[7]
        for i in range(0, 8)
            fileHdr.unused[i] = data[i + 8]

        if (fileHdr.magic[0] != uint8(0x4E) ||
            fileHdr.magic[1] != uint8(0x45) ||
            fileHdr.magic[2] != uint8(0x53) ||
            fileHdr.magic[3] != uint8(0x1A))
            res.error = "Wrong magic signature"
            return
        
        if (uint(fileHdr.flags7) & 0x0C) != 0x00
            if (uint(fileHdr.flags7) & 0x0C) == 0x08
                res.error = "Probably NES 2.0 format, not currently supported"
            else
                res.error = "Archaic iNES format is not supported"
            return

        for i in range(4, 8)
            if fileHdr.unused[i] != uint8(0)
                res.error = "Archaic iNES format is not supported"
                return

        res.verticalMirroring = (uint(fileHdr.flags6) & 0x01) != 0x00
        res.havePrgRam = (uint(fileHdr.flags6) & 0x02) != 0x00
        res.haveTrainer = (uint(fileHdr.flags6) & 0x04) != 0x00
        res.useMirroring = (uint(fileHdr.flags6) & 0x08) != 0x00
        res.mapper = int((uint(fileHdr.flags6) >> 0x04) | (uint(fileHdr.flags7) & 0xF0))

        if res.mapper != 0
            res.error = "Unsupported mapper {res.mapper}"
            return

        var filePos = hdrSize

        if res.haveTrainer
            if l - filePos < TRAINER_SIZE
                res.error = "Cannot read trainer data, file is truncated, expected at least {filePos + TRAINER_SIZE} bytes, got {l}"
                return
            for i in range(0, TRAINER_SIZE)
                res.trainer[i] = data[i + filePos]
            filePos += TRAINER_SIZE

        let totalPrgRomLen = int(uint(fileHdr.prgRomChunks)) * PRG_ROM_CHUNK
        if l - filePos < totalPrgRomLen
            res.error = "Cannot read PRG_ROM data, file is truncated, expected at least {filePos + totalPrgRomLen} bytes, got {l}"
            return
        resize(res.prgRom, int(uint(fileHdr.prgRomChunks)))
        for i in range(0x00, uint(fileHdr.prgRomChunks))
            for j in range(0, PRG_ROM_CHUNK)
                res.prgRom[i].v[j] = data[filePos]
                filePos++

        let totalChrRomLen = int(uint(fileHdr.chrRomChunks)) * CHR_ROM_CHUNK
        if l - filePos < totalChrRomLen
            res.error = "Cannot read CHR_ROM data, file is truncated, expected at least {filePos + totalChrRomLen} bytes, got {l}"
            return
        resize(res.chrRom, int(uint(fileHdr.chrRomChunks)))
        for i in range(0x00, uint(fileHdr.chrRomChunks))
            for j in range(0, CHR_ROM_CHUNK)
                res.chrRom[i].v[j] = data[filePos]
                filePos++

        res.error = ""
        res.isValid = true
    
    fclose(f)
    return res

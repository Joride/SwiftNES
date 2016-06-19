//
//  Memory.swift
//  SwiftNES
//
//  Created by Adam Gastineau on 3/23/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class Memory {
	/* Main Memory
	-- $10000 --
	 PRG-ROM Upper Bank
	-- $C000 --
	 PRG-ROM Lower Bank
	-- $8000 --
	 SRAM
	-- $6000 --
	 Expansion ROM
	-- $4020 --
	 I/O Registers
	-- $4000 --
	 Mirrors $2000 - $2007
	-- $2008 --
	 I/O Registers
	-- $2000 --
	 Mirrors $0000 - $07FF
	-- $0800 --
	 RAM
	-- $0200 --
	 Stack
	-- $0100 --
	 Zero Page
	-- $0000 --
	*/
	
	enum NametableMirroringType {
		case vertical
		
		case horizontal
		
		case oneScreen
		
		case fourScreen
	}
	
	var mapper: Mapper?;
	
	var banks: [UInt8];
	
	var mirrorPRGROM = false;
	
	/**
	 Initializes memory with the given type

	 - Parameter memoryType: The type of memory to create, represented as a Bool.
		True represents PPU memory (VRAM) and false CPU memory
	*/
	init() {
		// Dummy initialization
		self.banks = [UInt8](repeating: 0, count: 1);
		self.mapper = nil;
	}
	
	func readMemory(_ address: Int) -> UInt8 {
		return 0;
	}
	
	final func readTwoBytesMemory(_ address: Int) -> UInt16 {
		return UInt16(self.readMemory(address + 1)) << 8 | UInt16(self.readMemory(address));
	}
	
	func writeMemory(_ address: Int, data: UInt8) {
		
	}
	
    final func writeTwoBytesMemory(_ address: Int, data: UInt16) {
        writeMemory(address, data: UInt8(data & 0xFF));
        writeMemory(address + 1, data: UInt8((data & 0xFF00) >> 8));
    }
	
	func setMapper(_ mapper: Mapper) {
		
	}
}

final class PPUMemory: Memory {
	
	/* -- $4000
	Empty
	-- $3F20 --
	Sprite Palette
	-- $3F10 --
	Image Palette
	-- $3F00 --
	Empty
	-- $3000 --
	Attribute Table 3
	-- $2FC0 --
	Name Table 3 (32x30 tiles)
	-- $2C00 --
	Attribute Table 2
	-- $2BC0 --
	Name Table 2 (32x30 tiles)
	-- $2800 --
	Attribute Table 1
	-- $27C0 --
	Name Table 1 (32x30 tiles)
	-- $2400 --
	Attribute Table 0
	-- $23C0 --
	Name Table 0 (32x30 tiles)
	-- $2000 --
	Pattern Table 1 (256x2x8, may be VROM)
	-- $1000 --
	Pattern Table 0 (256x2x8, may be VROM)
	-- $0000 --
	*/
	
	var nametable: [UInt8];
	
	var nametableMirroring: NametableMirroringType = .oneScreen;
	var oneScreenUpper: Bool;
	
	private var previousAddress: Int;
	var a12Timer: Int;
	
	init(mapper: Mapper) {
		self.nametable = [UInt8](repeating: 0, count: 0x2000);
		self.oneScreenUpper = false;
		
		self.previousAddress = 0;
		self.a12Timer = 0;
		super.init();
		setMapper(mapper);
	}
	
	final override func setMapper(_ mapper: Mapper) {
		mapper.ppuMemory = self;
		self.mapper = mapper;
	}
	
	final override func readMemory(_ address: Int) -> UInt8 {
		var address = address % 0x4000;
		
		if(address & 0x1000 == 0x1000 && self.previousAddress & 0x1000 == 0) {
			if(self.a12Timer == 0) {
				self.mapper!.step();
			}
			self.a12Timer = 16;
		}
		
		self.previousAddress = address;
		
		if(address < 0x2000) {
			return self.mapper!.read(address);
		} else if((address >= 0x2000) && (address < 0x3000)) {
			if(self.nametableMirroring == .oneScreen) {
				address = 0x2000 | (address % 0x400);
				if(self.oneScreenUpper) {
					address += 0x400;
				}
			} else if(self.nametableMirroring == .horizontal) {
				if(address >= 0x2C00) {
					address -= 0x800;
				} else if(address >= 0x2400) {
					address -= 0x400;
				}
			} else if(self.nametableMirroring == .vertical) {
				if(address >= 0x2800) {
					address -= 0x800;
				}
			} else {
				print("ERROR: Nametable mirroring type not implemented");
			}
		} else if((address > 0x2FFF) && (address < 0x3F00)) {
			address -= 0x1000;
		}
		
		return self.nametable[address - 0x2000];
	}
	
	final override func writeMemory(_ address: Int, data: UInt8) {
		var address = address % 0x4000;
		
		if(address & 0x1000 == 0x1000 && self.previousAddress & 0x1000 == 0) {
			if(self.a12Timer == 0) {
				self.mapper!.step();
			}
			self.a12Timer = 16;
		}
		
		self.previousAddress = address;
		
		if(address < 0x2000) {
			self.mapper!.write(address, data: data);
			return;
		} else if((address >= 0x2000) && (address < 0x3000)) {
			if(self.nametableMirroring == .oneScreen) {
				address = 0x2000 | (address % 0x400);
				if(self.oneScreenUpper) {
					address += 0x400;
				}
			} else if(self.nametableMirroring == .horizontal) {
				if(address >= 0x2C00) {
					address -= 0x800;
				} else if(address >= 0x2400) {
					address -= 0x400;
				}
			} else if(self.nametableMirroring == .vertical) {
				if(address >= 0x2800) {
					address -= 0x800;
				}
			} else {
				print("ERROR: Nametable mirroring type not implemented");
			}
		} else if((address > 0x2FFF) && (address < 0x3F00)) {
			address -= 0x1000;
		} else if(address >= 0x3F10) {
			address = 0x3F00 + address % 0x20;
			
			if((address >= 0x3F10) && (address < 0x3F20) && (address & 0x3 == 0)) {
				address -= 0x10;
			}
		}
		
		self.nametable[address - 0x2000] = data;
	}
	
	func readPaletteMemory(_ address: Int) -> UInt8 {
		var address = address % 0x20;
		
		if(address >= 0x10 && address < 0x20 && address & 0x3 == 0) {
			address -= 0x10;
		}
		
		return self.nametable[0x1F00 + address];
	}
	
	
	func dumpMemory() {
		let logger = Logger(path: "/Users/adam/memory.dump");
		logger.dumpMemory(self.banks);
		logger.endLogging();
	}
}

final class CPUMemory: Memory {
	/* Main Memory
	-- $10000 --
	PRG-ROM Upper Bank
	-- $C000 --
	PRG-ROM Lower Bank
	-- $8000 --
	SRAM
	-- $6000 --
	Expansion ROM
	-- $4020 --
	I/O Registers
	-- $4000 --
	Mirrors $2000 - $2007
	-- $2008 --
	I/O Registers
	-- $2000 --
	Mirrors $0000 - $07FF
	-- $0800 --
	RAM
	-- $0200 --
	Stack
	-- $0100 --
	Zero Page
	-- $0000 --
	*/
	
	var ram: [UInt8];
	
	var sram: [UInt8];
	
	var ppu: PPU?;
	var apu: APU?;
	var controllerIO: ControllerIO?;
	
	init(mapper: Mapper) {
		self.ram = [UInt8](repeating: 0, count: 0x800);
		
		self.sram = [UInt8](repeating: 0, count: 0x2000);
		
		super.init();
		setMapper(mapper);
	}
	
	final override func setMapper(_ mapper: Mapper) {
		mapper.cpuMemory = self;
		self.mapper = mapper;
	}
	
	final override func readMemory(_ address: Int) -> UInt8 {
		if(address < 0x2000) {
			return self.ram[address % 0x800];
		} else if(address < 0x4000) {
			switch (address % 8) {
			case 0:
				return (self.ppu?.readWriteOnlyRegister())!;
			case 1:
				return (self.ppu?.readWriteOnlyRegister())!;
			case 2:
				return (self.ppu?.readPPUSTATUS())!;
			case 3:
				return (self.ppu?.readWriteOnlyRegister())!;
			case 4:
				return (self.ppu?.readOAMDATA())!;
			case 5:
				return (self.ppu?.readWriteOnlyRegister())!;
			case 6:
				return (self.ppu?.readWriteOnlyRegister())!;
			case 7:
				return (self.ppu?.readPPUDATA())!;
			default: break
			}
		} else if(address == 0x4016) {
			return self.controllerIO!.readState();
		} else if(address == 0x4017) {
			// TODO: Add second controller support
			return 0x40;
		} else if(address > 0x3FFF && address < 0x4018) {
			return (self.apu?.cpuRead(address))!;
		} else if(self.mirrorPRGROM && address >= 0xC000) {
			return self.mapper!.read(address - 0x4000);
		}
		
		return self.mapper!.read(address);
	}
	
	final override func writeMemory(_ address: Int, data: UInt8) {
		var address = address;
		
		if(address < 0x2000) {
			self.ram[address % 0x800] = data;
			return;
		} else if(address < 0x4000) {
			self.ppu?.cpuWrite(address % 8, data: data);
			return;
		} else if(address == 0x4014) {
			self.ppu?.OAMDMA = data;
			return;
		} else if(address == 0x4016) {
			if(data & 0x1 == 1) {
				self.controllerIO?.strobeHigh = true;
			} else {
				self.controllerIO?.strobeHigh = false;
			}
			
			return;
		} else if(address > 0x3FFF && address < 0x4018) {
			self.apu?.cpuWrite(address, data: data);
			return;
		} else if(self.mirrorPRGROM && address >= 0xC000) {
			address = address - 0x4000;
		}
		
		self.mapper!.write(address, data: data);
	}
}

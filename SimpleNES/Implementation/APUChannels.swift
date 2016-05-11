//
//  APUChannels.swift
//  SimpleNES
//
//  Created by Adam Gastineau on 5/9/16.
//  Copyright © 2016 Adam Gastineau. All rights reserved.
//

import Foundation

class APURegister {
	
	let lengthTable: [UInt8] = [0x0A, 0xFE, 0x14, 0x02, 0x28, 0x04, 0x50, 0x06, 0xA0, 0x08, 0x3C,
	                            0x0A, 0x0E, 0x0C, 0x1A, 0x0E, 0x0C, 0x10, 0x18, 0x12, 0x30, 0x14,
	                            0x60, 0x16, 0xC0, 0x18, 0x48, 0x1A, 0x10, 0x1C, 0x20, 0x1E];
	
	let dutyTable: [[UInt8]] = [[0, 1, 0, 0, 0, 0, 0, 0], [0, 1, 1, 0, 0, 0, 0, 0], [0, 1, 1, 1, 1, 0, 0, 0], [1, 0, 0, 1, 1, 1, 1, 1]];
	
	// Register 4
	var lengthCounter: UInt8 {
		didSet {
			self.wavelength = (self.wavelength & 0xFF) | (UInt16(lengthCounter & 0x7) << 8);
			self.lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)];
		}
	}
	// 3 bits
	var wavelength: UInt16;
	// 5 bits
	var lengthCounterLoad: UInt8;
	
	var lengthCounterDisable: Bool;
	
	var timer: UInt16;
	
	init() {
		self.lengthCounter = 0;
		self.wavelength = 0;
		self.lengthCounterLoad = 0;
		
		self.timer = 0;
		
		self.lengthCounterDisable = true;
	}
	
	func stepLength() {
		if(!self.lengthCounterDisable && self.lengthCounterLoad > 0) {
			self.lengthCounterLoad -= 1;
		}
	}
}

final class Square: APURegister {
	
	// Register 1
	var control: UInt8 {
		didSet {
			self.envelopeDisable = control & 0x10 == 0x10;
			self.lengthCounterDisable = control & 0x20 == 0x20;
			self.dutyCycleType = (control >> 6) & 0x3;
			
			self.envelopePeriod = control & 0xF;
			self.constantVolume = self.envelopePeriod;
			
			self.envelopeShouldUpdate = true;
		}
	}
	// 4 bits
	var volume: UInt8;
	var envelopeDisable: Bool;
	// 2 bits
	var dutyCycleType: UInt8;
	
	// Register 2
	var sweep: UInt8 {
		didSet {
			self.sweepShift = sweep & 0x7;
			self.decreaseWavelength = sweep & 0x8 == 0x8;
			self.sweepUpdateRate = (sweep >> 4) & 0x7;
			self.sweepEnable = sweep & 0x80 == 0x80;
			
			self.sweepShouldUpdate = true;
		}
	}
	// 3 bits
	var sweepShift: UInt8;
	var decreaseWavelength: Bool;
	// 3 bits
	var sweepUpdateRate: UInt8;
	var sweepEnable: Bool;
	
	// Register 3
	var wavelengthLow: UInt8 {
		didSet {
			self.wavelength = (self.wavelength & 0xFF00) | UInt16(wavelengthLow);
		}
	}
	
	// Register 4
	override var lengthCounter: UInt8 {
		didSet {
			self.wavelength = (self.wavelength & 0xFF) | (UInt16(lengthCounter & 0x7) << 8);
			self.lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)];
			self.dutyIndex = 0;
			self.envelopeShouldUpdate = true;
		}
	}
	
	private var channel2: Bool;
	
	var sweepShouldUpdate: Bool;
	var sweepValue: UInt8;
	var targetWavelength: UInt16;
	
	var dutyIndex: Int;
	
	var envelopeShouldUpdate: Bool;
	var envelopePeriod: UInt8;
	var envelopeVolume: UInt8;
	var constantVolume: UInt8;
	var envelopeValue: UInt8;
	
	override convenience init() {
		self.init(isChannel2: false);
	}
	
	init(isChannel2: Bool) {
		self.control = 0;
		self.volume = 0;
		self.envelopeDisable = false;
		self.dutyCycleType = 0;
		
		self.sweep = 0;
		self.sweepShift = 0;
		self.decreaseWavelength = false;
		self.sweepUpdateRate = 0;
		self.sweepEnable = false;
		
		self.wavelengthLow = 0;
		
		self.channel2 = isChannel2;
		
		self.sweepShouldUpdate = false;
		self.sweepValue = 0;
		self.targetWavelength = 0;
		
		self.dutyIndex = 0;
		
		self.envelopeShouldUpdate = false;
		self.envelopePeriod = 0;
		self.envelopeVolume = 0;
		self.constantVolume = 0;
		self.envelopeValue = 0;
		
		super.init();
	}
	
	func stepSweep() {
		if(self.sweepShouldUpdate) {
			if(self.sweepEnable && self.sweepValue == 0) {
				sweepUpdate();
			}
			
			self.sweepValue = self.sweepUpdateRate;
			self.sweepShouldUpdate = false;
		} else if(self.sweepValue > 0) {
			self.sweepValue -= 1;
		} else {
			if(self.sweepEnable) {
				sweepUpdate();
			}
			
			self.sweepValue = self.sweepUpdateRate;
		}
	}
	
	private func sweepUpdate() {
		let delta = self.wavelength >> UInt16(self.sweepShift);
		
		if(self.decreaseWavelength) {
			self.targetWavelength = self.wavelength - delta;
			
			if(!self.channel2) {
				self.targetWavelength += 1;
			}
		} else {
			self.targetWavelength = self.wavelength + delta;
		}
		
		if(self.sweepEnable && self.sweepShift != 0 && self.wavelength > 7 && self.targetWavelength < 0x800) {
			self.wavelength = self.targetWavelength;
		}
	}
	
	func stepTimer() {
		if(self.timer == 0) {
			self.timer = self.wavelength;
			self.dutyIndex = (self.dutyIndex + 1) % 8;
		} else {
			self.timer -= 1;
		}
	}
	
	func stepEnvelope() {
		if(self.envelopeShouldUpdate) {
			self.envelopeVolume = 0xF;
			self.envelopeValue = self.envelopePeriod;
			self.envelopeShouldUpdate = false;
		} else if(self.envelopeValue > 0) {
			self.envelopeValue -= 1;
		} else {
			if(self.envelopeVolume > 0) {
				self.envelopeVolume -= 1;
			} else if(self.lengthCounterDisable) {
				self.envelopeVolume = 0xF;
			}
			
			self.envelopeValue = self.envelopePeriod;
		}
	}
	
	func output() -> UInt8 {
		if(self.lengthCounterLoad == 0 || dutyTable[Int(self.dutyCycleType)][self.dutyIndex] == 0 || self.wavelength < 8 || self.targetWavelength > 0x7FF) {
			return 0;
		}
		
		if(!self.envelopeDisable) {
			return self.envelopeVolume;
		}
		
		return self.constantVolume;
	}
}

final class Triangle: APURegister {
	
	// Register 1
	var control: UInt8 {
		didSet {
			self.linearCounterLoad = control & 0x7F;
			self.linearCounter = self.linearCounterLoad;
			self.lengthCounterDisable = control & 0x80 == 0x80;
		}
	}
	// 7 bits
	var linearCounterLoad: UInt8;
	
	// Register 2 not used
	
	// Register 3
	var wavelengthLow: UInt8 {
		didSet {
			self.wavelength = (self.wavelength & 0xFF00) | UInt16(wavelengthLow);
		}
	}
	
	override var lengthCounter: UInt8 {
		didSet {
			self.wavelength = (self.wavelength & 0xFF) | (UInt16(lengthCounter & 0x7) << 8);
			self.lengthCounterLoad = lengthTable[Int((lengthCounter >> 3) & 0x1F)];
			self.timer = self.wavelength;
			self.linearHalt = true;
		}
	}
	
	var linearCounter: UInt8;
	var linearHalt: Bool;
	
	var triangleGenerator: UInt8;
	var triangleIncreasing: Bool;
	
	override init() {
		self.control = 0;
		self.linearCounterLoad = 0;
		
		self.wavelengthLow = 0;
		
		self.linearCounter = 0;
		self.linearHalt = false;
		
		self.triangleGenerator = 0;
		self.triangleIncreasing = true;
	}
	
	func stepLinear() {
		if(self.linearHalt) {
			self.linearCounter = self.linearCounterLoad;
		} else if(self.linearCounter > 0) {
			self.linearCounter -= 1;
		}
		
		if(!self.lengthCounterDisable) {
			self.linearHalt = false;
		}
	}
	
	func stepTriangleGenerator() {
		if(self.triangleGenerator == 0) {
			self.triangleIncreasing = true;
		} else if(self.triangleGenerator == 0xF) {
			self.triangleIncreasing = false;
		}
		
		if(self.triangleIncreasing) {
			self.triangleGenerator += 1;
		} else {
			self.triangleGenerator -= 1;
		}
	}
	
	func stepTimer() {
		if(self.timer == 0) {
			self.timer = self.wavelength;
			if(self.lengthCounterLoad > 0 && self.linearCounter > 0) {
				stepTriangleGenerator();
			}
		} else {
			self.timer -= 1;
		}
	}
	
	func output() -> Double {
		if(self.lengthCounterLoad == 0 || self.linearCounter == 0) {
			return 0;
		}
		
		if(self.wavelength == 0 || self.wavelength == 1) {
			return 7.5;
		}
		
		return Double(self.triangleGenerator);
	}
}

final class Noise: APURegister {
	
	var control: UInt8 {
		didSet {
			self.volume = control & 0xF;
			self.envelopeDisable = control & 0x10 == 0x10;
			self.lengthCounterDisable = control & 0x20 == 0x20;
			self.dutyCycleType = (control >> 6) & 0x3;
		}
	}
	// 4 bits
	var volume: UInt8;
	var envelopeDisable: Bool;
	var dutyCycleType: UInt8;
	
	// Register 2 unused
	
	// Register 3
	var period: UInt8 {
		didSet {
			self.sampleRate = period & 0xF;
			self.randomNumberGeneration = period & 0x80 == 0x80;
		}
	}
	// 4 bits
	var sampleRate: UInt8;
	// 3 unused bits
	var randomNumberGeneration: Bool;
	
	// 3 unused bits in register 4 (msbWavelength)
	
	override init() {
		self.control = 0;
		self.volume = 0;
		self.envelopeDisable = false;
		self.dutyCycleType = 0;
		
		self.period = 0;
		self.sampleRate = 0;
		self.randomNumberGeneration = false;
	}
	
	func stepEnvelope() {
		
	}
}
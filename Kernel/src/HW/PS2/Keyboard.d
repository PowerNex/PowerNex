module HW.PS2.Keyboard;

import CPU.IDT;
import Data.Register;
import Data.BitField;
import IO.Log;
import IO.Port;
import IO.Keyboard;
import HW.PS2.KBSet;

/// This is a class for controlling the 8042 PS/2 controller
struct PS2Keyboard {
public:
	static void Init() {
		ubyte result;

		IDT.Register(IRQ(1), &onIRQ);

		sendCtlCmd(0xAD /* Disable port 1 */ );
		sendCtlCmd(0xA7 /* Disable port 2 */ );

		while (getStatus.OutputFull)
			get(false);

		sendCtlCmd(0x20 /* Read configuration */ );
		result = get();
		result &= ~0b1000010; // Clear Translation bit and IRQ flags
		sendCtlCmd(0x60 /* Write configuration */ );
		sendCmd(result);

		sendCtlCmd(0xAE /* Enable port 1 */ );

		sendCmd(0xFF /* Reset */ );
		while (result != 0xAA)
			result = get(false);

		initialized = true;
	}

private:
	struct keyboardStatus {
		ubyte value;

		//dfmt off
		mixin(Bitfield!(value,
			"OutputFull", 1,
			"InputFull", 1,
			"SelfTestSucceeded", 1,
			"LastWriteWasCommand", 1,
			"KeyboardLocked", 1,
			"Timeout", 1,
			"ParityError", 1
		));
		//dfmt on
	}

	struct keyState {
		ulong[4] bitmaps;
		private enum countPerInt = ulong.sizeof * 8;
		private enum length = bitmaps.length * countPerInt;

		void Set(ushort bit) {
			if (bit >= length)
				return;

			bitmaps[bit / countPerInt] |= 1 << (bit % countPerInt);
		}

		bool IsSet(ushort bit) {
			if (bit >= length)
				return false;

			return !!(bitmaps[bit / countPerInt] & 1 << (bit % countPerInt));
		}

		void Clear(ushort bit) {
			if (bit >= length)
				return;

			bitmaps[bit / countPerInt] &= ~(1 << (bit % countPerInt));
		}
	}

	enum ushort DataPort = 0x60;
	enum ushort ControllerPort = 0x64; // Read -> Status Register / Write -> Command Register

	__gshared bool initialized;
	__gshared keyState state;

	static KeyCode combineKeyData(ubyte ch) {
		__gshared bool nextUnpress = false;
		__gshared bool nextExtended = false;
		__gshared int nextSpecial = 0;

		KeyCode key = KeyCode.None;

		if (ch == 0xF0) {
			nextUnpress = true;
			return KeyCode.None;
		} else if (nextSpecial == 2) {
			nextSpecial--; // Should maybe save ch?
			return KeyCode.None;
		} else if (ch == 0xE0) {
			nextExtended = true;
			return KeyCode.None;
		} else if (ch == 0xE1) {
			nextSpecial = 2;
			return KeyCode.None;
		}

		if (nextExtended)
			key = FindKeycode(E0Bit | (ch & 0x7F));
		else if (nextSpecial == 1)
			key = FindKeycode(E1Bit | (ch & 0x7F));
		else
			key = FindKeycode(ch);

		if (nextUnpress) {
			state.Clear(key);

			nextUnpress = false;
			nextExtended = false;
			nextSpecial = 0;
			return KeyCode.None;
		}

		state.Set(key);

		if (key == KeyCode.CapsLock || key == KeyCode.NumLock || key == KeyCode.ScrollLock)
			setLED();

		return key;
	}

	static void waitGet() {
		while (!getStatus.OutputFull) {
		}
	}

	static void waitSend() {
		while (getStatus.InputFull) {
		}
	}

	static ubyte get(bool wait = true) {
		if (wait)
			waitGet();
		return In!ubyte(DataPort);
	}

	static keyboardStatus getStatus() {
		return keyboardStatus(In!ubyte(ControllerPort));
	}

	static void sendCmd(ubyte cmd) {
		waitSend();
		Out!ubyte(DataPort, cmd);
	}

	static void sendCtlCmd(ubyte cmd) {
		waitSend();
		Out!ubyte(ControllerPort, cmd);
	}

	static void setLED() {
		waitSend();
		sendCmd(0xED);
		get(false);
		sendCmd(state.IsSet(KeyCode.CapsLock) << 2 | state.IsSet(KeyCode.NumLock) << 1 | state.IsSet(KeyCode.ScrollLock));
		get(false);
	}

	static void onIRQ(Registers* regs) {
		ubyte data = get();
		if (!initialized)
			return;

		KeyCode key = combineKeyData(data);
		if (key != KeyCode.None) {
			import IO.TextMode;

			GetScreen.Write(key, " ");

			// TODO: Translate the KeyCode to a (d)char
			//Keyboard.Push(translatedKey);
		}

	}
}

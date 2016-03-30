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

		setLED();

		initialized = true;
	}

private:
	struct keyboardStatus {
		private ubyte value;

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

		void Set(KeyCode key) {
			ubyte bit = cast(ubyte)key;

			bitmaps[bit / countPerInt] |= 1 << (bit % countPerInt);
		}

		bool IsSet(KeyCode key) {
			ubyte bit = cast(ubyte)key;

			return !!(bitmaps[bit / countPerInt] & 1 << (bit % countPerInt));
		}

		void Clear(KeyCode key) {
			ubyte bit = cast(ubyte)key;

			bitmaps[bit / countPerInt] &= ~(1 << (bit % countPerInt));
		}

		void Toggle(KeyCode key) {
			if (IsSet(key))
				Clear(key);
			else
				Set(key);
		}
	}

	struct modifierState {
		private ubyte data;

		mixin(Bitfield!(data, "NumLock", 1, "CapsLock", 1, "ScrollLock", 1));
	}

	enum ushort DataPort = 0x60;
	enum ushort ControllerPort = 0x64; // Read -> Status Register / Write -> Command Register

	__gshared bool initialized;
	__gshared keyState state;
	__gshared modifierState modifiers;

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

		if (key == KeyCode.CapsLock) {
			modifiers.CapsLock = !modifiers.CapsLock;
			setLED();
		} else if (key == KeyCode.NumLock) {
			modifiers.NumLock = !modifiers.NumLock;
			setLED();
		} else if (key == KeyCode.ScrollLock) {
			modifiers.ScrollLock = !modifiers.ScrollLock;
			setLED();
		}

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
		sendCmd(modifiers.CapsLock << 2 | modifiers.NumLock << 1 | modifiers.ScrollLock);
		get(false);
	}

	static void onIRQ(Registers* regs) {
		ubyte data = get();
		if (!initialized)
			return;

		KeyCode key = combineKeyData(data);
		if (key != KeyCode.None) {
			dchar ch;

			bool shift = state.IsSet(KeyCode.LeftShift) || state.IsSet(KeyCode.RightShift);
			bool caps = modifiers.CapsLock;
			bool num = modifiers.NumLock;

			if (ch == dchar.init && caps != shift)
				ch = FindShiftedCharTranslate(key);

			if (ch == dchar.init && shift)
				ch = FindShiftedEtcTranslate(key);

			if (ch == dchar.init && num)
				ch = FindKeypadTranslate(key);

			if (ch == dchar.init)
				ch = FindNormalTranslate(key);

			if (ch != dchar.init)
				Keyboard.Push(ch);
		}
	}
}

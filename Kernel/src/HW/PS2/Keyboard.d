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
		IDT.Register(IRQ(2), &ignore);

		sendCtlCmd(0xAD /* Disable port 1 */ );
		sendCtlCmd(0xA7 /* Disable port 2 */ );

		while (getStatus.OutputFull)
			get(false);
		sendCtlCmd(0x20 /* Read configuration */ );
		result = get();
		result &= ~0b100_0010; // Clear Translation bit (aka enable scancode set 2) and IRQ flags
		sendCtlCmd(0x60 /* Write configuration */ );
		sendCmd(result);
		sendCtlCmd(0xAE /* Enable port 1 */ );
		sendCmd(0xFF /* Reset */ );
		while (result != 0xAA)
			result = get();
		setLED();
		enabled = true;
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

	__gshared bool enabled;
	__gshared keyState state;
	__gshared modifierState modifiers;

	static KeyCode combineKeyData(ubyte ch) {
		enum VBoxHack { // XXX: Fixed VBox scancode set 2 problems
			None,
			NumLock,
			CapsLock,
		}

		__gshared VBoxHack vboxHackState = VBoxHack.None;
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

			vboxHackState = VBoxHack.None;
			nextUnpress = false;
			nextExtended = false;
			nextSpecial = 0;
			return KeyCode.None;
		}

		state.Set(key);

		if (key == KeyCode.CapsLock && vboxHackState != VBoxHack.CapsLock) {
			modifiers.CapsLock = !modifiers.CapsLock;
			setLED();
			vboxHackState = VBoxHack.CapsLock;
		} else if (vboxHackState != VBoxHack.NumLock && key == KeyCode.NumLock) {
			modifiers.NumLock = !modifiers.NumLock;
			setLED();
			vboxHackState = VBoxHack.NumLock;
		} else if (key == KeyCode.ScrollLock) {
			modifiers.ScrollLock = !modifiers.ScrollLock;
			setLED();
		} else
			vboxHackState = VBoxHack.None;
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
		enabled = false;
		sendCmd(0xED);
		while (get() != 0xFA) {
		}
		sendCmd(modifiers.CapsLock << 2 | modifiers.NumLock << 1 | modifiers.ScrollLock);
		while (get() != 0xFA) {
		}
		enabled = true;
	}

	static void onIRQ(Registers* regs) {
		ubyte data = get(false);
		if (!enabled)
			return;
		//if (data == 0x00 || data == 0xAA || data == 0xEE || data == 0xFA || data == 0xFC || data == 0xFD || data == 0xFE || data == 0xFF)
		//acontinue;

		KeyCode key = combineKeyData(data);
		if (key != KeyCode.None) {
			wchar ch;

			bool shift = state.IsSet(KeyCode.LeftShift) || state.IsSet(KeyCode.RightShift);
			bool caps = modifiers.CapsLock;
			bool num = modifiers.NumLock;

			if (ch == wchar.init && caps != shift)
				ch = FindShiftedCharTranslate(key);

			if (ch == wchar.init && shift)
				ch = FindShiftedEtcTranslate(key);

			if (ch == wchar.init && num)
				ch = FindKeypadTranslate(key);

			if (ch == wchar.init)
				ch = FindNormalTranslate(key);

			if (ch != wchar.init)
				Keyboard.Push(ch);
		}
	}

	static void ignore(Registers*) {
	}
}

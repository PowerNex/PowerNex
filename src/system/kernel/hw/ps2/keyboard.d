module hw.ps2.keyboard;

import stl.arch.amd64.idt;
import stl.register;
import stl.bitfield;
import stl.io.log;
import stl.arch.amd64.ioport;
import hw.ps2.kbset;

/// This is a class for controlling the 8042 PS/2 controller
struct PS2Keyboard {
public:
	static void init() {
		ubyte result;

		IDT.register(irq(1), cast(IDT.InterruptCallback)&_onIRQ);
		IDT.register(irq(2), cast(IDT.InterruptCallback)&_ignore);

		_sendCtlCmd(0xAD /* Disable port 1 */ );
		_sendCtlCmd(0xA7 /* Disable port 2 */ );

		while (_getStatus.OutputFull)
			_get(false);
		_sendCtlCmd(0x20 /* Read configuration */ );
		result = _get();
		result &= ~0b100_0010; // Clear Translation bit (aka enable scancode set 2) and IRQ flags
		_sendCtlCmd(0x60 /* Write configuration */ );
		_sendCmd(result);
		_sendCtlCmd(0xAE /* Enable port 1 */ );
		_sendCmd(0xFF /* Reset */ );
		while (result != 0xAA)
			result = _get();
		_setLED();
		_enabled = true;
	}

private:
	struct KeyboardStatus {
		private ubyte _value;

		//dfmt off
		mixin(bitfield!(_value,
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

	struct KeyState {
		ulong[4] bitmaps;
		private enum _countPerInt = ulong.sizeof * 8;
		private enum _length = bitmaps.length * _countPerInt;

		void set(KeyCode key) {
			ubyte bit = cast(ubyte)key;

			bitmaps[bit / _countPerInt] |= 1 << (bit % _countPerInt);
		}

		bool isSet(KeyCode key) {
			ubyte bit = cast(ubyte)key;

			return !!(bitmaps[bit / _countPerInt] & 1 << (bit % _countPerInt));
		}

		void clear(KeyCode key) {
			ubyte bit = cast(ubyte)key;

			bitmaps[bit / _countPerInt] &= ~(1 << (bit % _countPerInt));
		}

		void toggle(KeyCode key) {
			if (isSet(key))
				clear(key);
			else
				set(key);
		}
	}

	struct ModifierState {
		private ubyte _data;

		mixin(bitfield!(_data, "numLock", 1, "capsLock", 1, "scrollLock", 1));
	}

	enum ushort _dataPort = 0x60;
	enum ushort _controllerPort = 0x64; // Read -> Status Register / Write -> Command Register

	__gshared bool _enabled;
	__gshared KeyState _state;
	__gshared ModifierState _modifiers;

	static KeyCode _combineKeyData(ubyte ch) {
		enum VBoxHack { // XXX: Fixed VBox scancode set 2 problems
			none,
			numLock,
			capsLock,
		}

		__gshared VBoxHack vboxHackState = VBoxHack.none;
		__gshared bool nextUnpress = false;
		__gshared bool nextExtended = false;
		__gshared int nextSpecial = 0;

		KeyCode key = KeyCode.none;

		if (ch == 0xF0) {
			nextUnpress = true;
			return KeyCode.none;
		} else if (nextSpecial == 2) {
			nextSpecial--; // Should maybe save ch?
			return KeyCode.none;
		} else if (ch == 0xE0) {
			nextExtended = true;
			return KeyCode.none;
		} else if (ch == 0xE1) {
			nextSpecial = 2;
			return KeyCode.none;
		}

		if (nextExtended)
			key = findKeycode(e0Bit | (ch & 0x7F));
		else if (nextSpecial == 1)
			key = findKeycode(e1Bit | (ch & 0x7F));
		else
			key = findKeycode(ch);

		if (nextUnpress) {
			_state.clear(key);

			vboxHackState = VBoxHack.none;
			nextUnpress = false;
			nextExtended = false;
			nextSpecial = 0;
			return KeyCode.none;
		}

		_state.set(key);

		if (key == KeyCode.capsLock && vboxHackState != VBoxHack.capsLock) {
			_modifiers.capsLock = !_modifiers.capsLock;
			_setLED();
			vboxHackState = VBoxHack.capsLock;
		} else if (vboxHackState != VBoxHack.numLock && key == KeyCode.numLock) {
			_modifiers.numLock = !_modifiers.numLock;
			_setLED();
			vboxHackState = VBoxHack.numLock;
		} else if (key == KeyCode.scrollLock) {
			_modifiers.scrollLock = !_modifiers.scrollLock;
			_setLED();
		} else
			vboxHackState = VBoxHack.none;
		return key;
	}

	static void _waitGet() {
		while (!_getStatus.OutputFull) {
		}
	}

	static void _waitSend() {
		while (_getStatus.InputFull) {
		}
	}

	static ubyte _get(bool wait = true) {
		if (wait)
			_waitGet();
		return inp!ubyte(_dataPort);
	}

	static KeyboardStatus _getStatus() {
		return KeyboardStatus(inp!ubyte(_controllerPort));
	}

	static void _sendCmd(ubyte cmd) {
		_waitSend();
		outp!ubyte(_dataPort, cmd);
	}

	static void _sendCtlCmd(ubyte cmd) {
		_waitSend();
		outp!ubyte(_controllerPort, cmd);
	}

	static void _setLED() {
		_enabled = false;
		_sendCmd(0xED);
		while (_get() != 0xFA) {
		}
		_sendCmd(_modifiers.capsLock << 2 | _modifiers.numLock << 1 | _modifiers.scrollLock);
		while (_get() != 0xFA) {
		}
		_enabled = true;
	}

	static void _onIRQ(Registers* regs) {
		ubyte data = _get(false);
		if (!_enabled)
			return;
		//if (data == 0x00 || data == 0xAA || data == 0xEE || data == 0xFA || data == 0xFC || data == 0xFD || data == 0xFE || data == 0xFF)
		//acontinue;

		KeyCode key = _combineKeyData(data);
		if (key != KeyCode.none) {
			dchar ch;

			const bool shift = _state.isSet(KeyCode.leftShift) || _state.isSet(KeyCode.rightShift);
			const bool caps = _modifiers.capsLock;
			const bool num = _modifiers.numLock;

			if (ch == dchar.init && caps != shift)
				ch = findShiftedCharTranslate(key);

			if (ch == dchar.init && shift)
				ch = findShiftedEtcTranslate(key);

			if (ch == dchar.init && num)
				ch = findKeypadTranslate(key);

			if (ch == dchar.init)
				ch = findNormalTranslate(key);

			if (ch != dchar.init) {
				const bool ctrl = _state.isSet(KeyCode.leftCtrl) || _state.isSet(KeyCode.rightCtrl);
				const bool alt = _state.isSet(KeyCode.leftAlt) || _state.isSet(KeyCode.rightAlt);
				//ConsoleManager.addKeyboardInput(ch, ctrl, alt, shift);
				//Keyboard.Push(ch);
			}
		}
	}

	static void _ignore(Registers*) {
	}
}

/**********************************************************************************
 * Electric Imp I2C LCD Library                                                   *
 * Copyright (C) 2013  Omri Bahumi                                                *
 *                                                                                *
 * This library is free software; you can redistribute it and/or                  *
 * modify it under the terms of the GNU Lesser General Public                     *
 * License as published by the Free Software Foundation; either                   *
 * version 2.1 of the License, or (at your option) any later version.             *
 *                                                                                *
 * This library is distributed in the hope that it will be useful,                *
 * but WITHOUT ANY WARRANTY; without even the implied warranty of                 *
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU              *
 * Lesser General Public License for more details.                                *
 *                                                                                *
 * You should have received a copy of the GNU Lesser General Public               *
 * License along with this library; if not, write to the Free Software            *
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA *
 **********************************************************************************/

/*
 * Deeply inspired by Arduino LiquidCrystal_I2C library: https://github.com/kiyoshigawa/LiquidCrystal_I2C
 */

class LowLevelLcd {
    i2cPort = null;
    lcdAddress = null;

    // commands
    static LCD_CLEARDISPLAY = 0x01;
    static LCD_RETURNHOME = 0x02;
    static LCD_ENTRYMODESET = 0x04;
    static LCD_DISPLAYCONTROL = 0x08;
    static LCD_CURSORSHIFT = 0x10;
    static LCD_FUNCTIONSET = 0x20;
    static LCD_SETCGRAMADDR = 0x40;
    static LCD_SETDDRAMADDR = 0x80;

    // flags for display entry mode
    static LCD_ENTRYRIGHT = 0x00;
    static LCD_ENTRYLEFT = 0x02;
    static LCD_ENTRYSHIFTINCREMENT = 0x01;
    static LCD_ENTRYSHIFTDECREMENT = 0x00;

    // flags for display on/off control
    static LCD_DISPLAYON = 0x04;
    static LCD_DISPLAYOFF = 0x00;
    static LCD_CURSORON = 0x02;
    static LCD_CURSOROFF = 0x00;
    static LCD_BLINKON = 0x01;
    static LCD_BLINKOFF = 0x00;

    // flags for display/cursor shift
    static LCD_DISPLAYMOVE = 0x08;
    static LCD_CURSORMOVE = 0x00;
    static LCD_MOVERIGHT = 0x04;
    static LCD_MOVELEFT = 0x00;

    // flags for function set
    static LCD_8BITMODE = 0x10;
    static LCD_4BITMODE = 0x00;
    static LCD_2LINE = 0x08;
    static LCD_1LINE = 0x00;
    static LCD_5x10DOTS = 0x04;
    static LCD_5x8DOTS = 0x00;

    static PIN_RS = 0x1; // off=command, on=data
    static PIN_RW = 0x2; // off=write, on=read
    static PIN_EN = 0x4; // clock
    static PIN_LED = 0x8;

    /*
     * Construct a new ImpLcd instance to talk with a generic I2C controlled LCD
     *
     * @port - I2C object. One of the hardware.i2c* objects
     * @address - integer, base address of the I2C LCD
     */
    constructor(port, address)
    {
        this.i2cPort = port;
        this.lcdAddress = address;

        this.i2cPort.configure(CLOCK_SPEED_100_KHZ);

        // set LCD to 8 bits mode 3 times
        for (local i=0; i<3; i++)
        {
            this.sendPulse(0x03 << 4, 0);
        }

        // set LCD to 4 bits mode
        this.sendPulse(0x02 << 4, 0);
    }

    /*
     * Read `length` bytes from the I2C read address
     *
     * @length - integer, number of bytes to read
     */
    function rawRead(length)
    {
        return this.i2cPort.read((this.lcdAddress << 1) | 0x1, length);
    }

    /*
     * I2C write wrapper. Write `data` to the I2C write address
     *
     * @data - string, data to send
     */
    function rawWrite(data)
    {
        return this.i2cPort.write((this.lcdAddress << 1) | 0x0, data);
    }

    /*
     * Wrapper around rawWrite() that accepts a byte instead of a string. It also keeps the LED on all time
     *
     * @byte - byte, byte to send
     */
    function rawWriteByte(byte)
    {
        return this.rawWrite(format("%c", byte | PIN_LED));
    }

    /*
     * Write a string to the display on the current position
     *
     * @s - string, string to print
     */
    function writeString(s)
    {
        for (local i=0; i<s.len(); i++)
        {
            this.send(s[i], PIN_RS);
        }
    }

    /*
     * Send a command to the LCD
     *
     * @value - byte, command to send
     */
    function sendCommand(value)
    {
        this.send(value, 0);
    }

    /*
     * Pulse a value to the LCD
     */
    function sendPulse(value, mode)
    {
        mode = mode | PIN_LED;

        this.rawWriteByte(value | mode);
        this.rawWriteByte(value | mode | PIN_EN);
        imp.sleep(0.0006);
        this.rawWriteByte(value | mode);
    }

    /*
     * Push an 8bit value to the LCD with two 4bit pulses
     */
    function send(value, mode)
    {
        local highNib = value & 0xf0;
        local lowNib = (value << 4) & 0xf0;

        this.sendPulse(highNib, mode);
        this.sendPulse(lowNib, mode);
    }
}

class ImpLcd
{
    _lcd = null;
    _functionSet = LowLevelLcd.LCD_4BITMODE | LowLevelLcd.LCD_1LINE | LowLevelLcd.LCD_5x8DOTS;
    _displayControl = LowLevelLcd.LCD_DISPLAYON | LowLevelLcd.LCD_CURSOROFF | LowLevelLcd.LCD_BLINKOFF;

    /*
     * Construct a new ImpLcd instance to talk with a generic I2C controlled LCD
     *
     * @port - I2C object. One of the hardware.i2c* objects
     * @address - integer, base address of the I2C LCD
     * @rows - integer, number of rows on the LCD
     * @dotSize - integer, when this value is greater than zero, the LCD is configured to display 5x10 dots characters. Otherwise, 5x8 dots characters.
     */
    constructor(port, address, rows, dotSize)
    {
        this._lcd = LowLevelLcd(port, address);

        if (rows > 1)
        {
            this._functionSet = this._functionSet | LowLevelLcd.LCD_2LINE;
        }

        if (dotSize > 0)
        {
            this._functionSet = this._functionSet | LowLevelLcd.LCD_5x10DOTS;
        }

        this.functionSet();
        this.displayControl();
        this.clear();
    }

    /*
     * Send the current value of _functionSet to the LCD
     */
    function functionSet()
    {
        return this._lcd.sendCommand(LowLevelLcd.LCD_FUNCTIONSET | this._functionSet);
    }

    /*
     * Send the current value of _displayControl to the LCD
     */
    function displayControl()
    {
        return this._lcd.sendCommand(LowLevelLcd.LCD_DISPLAYCONTROL | this._displayControl);
    }

    /*
     * Write a string to the display on the current position
     *
     * @s - string, string to print
     */
    function writeString(s)
    {
        return this._lcd.writeString(s);
    }

    /*
     * Set the LCD cursor to given position
     *
     * @col - integer, column number, zero based
     * @row - integer, row number, zero based
     */
    function setCursor(col, row)
    {
        local rowOffsets = [ 0x00, 0x40, 0x14, 0x54 ];
        return this._lcd.sendCommand(LowLevelLcd.LCD_SETDDRAMADDR | (col + rowOffsets[row]));
    }

    /*
     * Clear the LCD
     */
    function clear()
    {
        return this._lcd.sendCommand(LowLevelLcd.LCD_CLEARDISPLAY);
    }

    /*
     * Turn display off (doesn't turn off the LED)
     */
    function noDisplay()
    {
        this._displayControl = this.displayControl & ~LowLevelLcd.LCD_DISPLAYON;
        return this.displayControl();
    }

    /*
     * Turn display on
     */
    function display()
    {
        this._displayControl = this.displayControl | LowLevelLcd.LCD_DISPLAYON;
        return this.displayControl();
    }

    /*
     * Turn cursor blinking off
     */
    function noBlink()
    {
        this._displayControl = this.displayControl & ~LowLevelLcd.LCD_BLINKON;
        return this.displayControl();
    }

    /*
     * Turn cursor blinking on
     */
    function blink()
    {
        this._displayControl = this.displayControl | LowLevelLcd.LCD_BLINKON;
        return this.displayControl();
    }

    /*
     * Turn off the cursor
     */
    function noCursor()
    {
        this._displayControl = this.displayControl & ~LowLevelLcd.LCD_CURSORON;
        return this.displayControl();
    }

    /*
     * Turn the cursor on
     */
    function cursor()
    {
        this._displayControl = this.displayControl | LowLevelLcd.LCD_CURSORON;
        return this.displayControl();
    }
}

// create an ImpLcd instance. Our LCD is connected to I2C on ports 8,9 with a base address of 0x27
lcd <- ImpLcd(hardware.i2c89, 0x27, 2, 0);

function updateClock()
{
    local t = date();

    // move to the first row, first column
    lcd.setCursor(0, 0);
    lcd.writeString(format("%02d:%02d:%02d", t.hour, t.min, t.sec));

    // move to the second row, first column
    lcd.setCursor(0, 1);
    lcd.writeString(format("%02d-%02d-%04d", t.day, t.month, t.year));

    // update the clock again in 1 second
    imp.wakeup(1, updateClock);
}

// fire updateClock() for the first time
updateClock();

// Register with the server
imp.configure("ImpLcd", [], []);


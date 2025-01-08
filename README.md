# ft_otp

## Description
This is a program that allows you to store an initial password in an encrypted file and that is capable of generating a new TOTP one time password every time it is requested.<br />
It has a CLI (Command Line Interface), and a GUI (Graphical User Interface) version.

### Secret key
* The `keys` folder contains a set of valid and invalid keys (for testing purpose). The valid keys are: `key.hex`, `key.base32`.
* The file containing the secret key shouldn't end with a newline character.
do:<br />
`echo -n <key_string> > <key_file>`<br />
to put into a file a string that doesn't end with a newline. 
* The key should be either in Hex or Base32 formats.
* The key should have at least 64 characters.


## Requirement
* Crypto++ Library<br />
Used for performing HMAC-SHA1.
```
sudo apt install libcrypto++X libcrypto++-dev libcrypto++-utils libcrypto++-doc
// Or, on Termux
pkg install cryptopp
```

* Qrencode<br />
Used for producing QRcodes.
```
sudo apt install libqrencode-dev
// Or, on Termux
pkg install libqrencode
```

* PNG Library
Used for producing QRcodes.
```
sudo apt install libpng-dev
// Or, on Termux
pkg install libpng
```

## Commands

### CLI
```
// Install
cd cli
make

// Usage: ./ft_otp [OPTIONS] <key file>
// Options:
  -g, --generate     Generate and save the encrypted key
  -k, --key          Generate password using the provided key
  -q, --qrcode       Generate a QR code containing the key (requires -g)
  -v, --verbose      Enable verbose output
  -h, --help         Show this help message and exit

// Generate the encrypted key file with its corresponding QR code
./ft_otp -gk <key_file>

The program receives as argument a hexadecimal key of at least 64 characters.
The program stores this key safely in a file called ft_otp.key,
which is encrypted with AES encryption using Crypto++.

// Generate the TOTP temporary password
./ft_otp -k ft_otp.key

The program generates a new temporary password based on the encrypted key
given as argument and prints it on the standard output.

// Check what TOTP code you should get with a hex key
oathtool --totp $(cat keys/key.hex) -v
// Check with a Base32 key
oathtool --totp -b $(cat keys/key.base32) -v


// Examples of usage

# With a Hex key #

// 1. Generate and save the encrypted key to the external file `ft_otp.key`.
make && ./ft_otp -g keys/key.hex

// 2. Decode the encrypted key and generate a TOTP code from it.
// Compare our TOTP code to the one delivered by `oathtool`.
./ft_otp ft_otp.key -k && echo "" && oathtool --totp $(cat keys/key.hex) -v

or: make hex

# With a Base32 key #

make && ./ft_otp -g keys/key.base32 && ./ft_otp ft_otp.key -k && echo "" && oathtool --totp -b $(cat keys/key.base32) -v

or: make b32

# With a Bad key #

make && ./ft_otp -g keys/key.base32hex
./ft_otp ft_otp.key -k
oathtool --totp $(cat keys/key.base32hex) -v

or: make bad

// Tests
make hex	  // Run with a Hex secret key
make b32	  // Run with a Base32 secret key
make bad	  // Run with a bad secret key
make tests	// Run all tests
```
<img src="screenshots/cli.png" />


### GUI
```
// Run the GUI
cd gui
./run.sh

// Or
cd gui
./build/Desktop_Qt_6_8_1-Debug/ft_otp_gui
```
<img src="screenshots/gui.png" />


## QR Code Generation for TOTP Secrets
* QR codes can be generated and read from command line for testing:
```
// Generate QR code image
sudo apt install qrencode
qrencode -o qrcode.png $(cat keys/key.hex)

// Read QR code image
sudo apt install zbar-tools
zbarimg qrcode.png
```
* This program generates a QR code for a TOTP (Time-based One-Time Password) secret, saving it as a PNG image file. The process involves creating a QR code based on the **Key URI Format**, which can be scanned by standard QR code readers for seamless OTP setup.

### How It Works

1. **QR Code Dimensions and Scaling**:
    - The QR code is generated at a scaled-up resolution for better readability.
    - **Dimensions**: The total image size is `(QR_width × scale + 2 × margin) × (QR_width × scale + 2 × margin)`, ensuring sufficient size and compatibility with QR scanners.
    - Defaults:
        - **Scale**: 10 (each module is scaled by 10 pixels).
        - **Margin**: 4 modules.

2. **PNG File Creation**:
    - The program uses the **libpng** library to create a grayscale PNG file where:
        - Black pixels represent QR code modules (`0x00`).
        - White pixels fill the rest (`0xFF`).

3. **Key URI Format**:
    - The QR code encodes a **TOTP URI** in the following format:
      ```
      otpauth://totp/<PROJECT_NAME>:<USER_EMAIL>?secret=<SECRET>&issuer=<PROJECT_NAME>
      ```
      - **Example**:
        ```
        otpauth://totp/MyService:myuser@example.com?secret=BASE32SECRET&issuer=MyService
        ```

4. **Steps to Generate the QR Code**:
    - A TOTP URI is created dynamically using the provided secret and project name.
    - The URI is encoded into a QR code using the `qrencode` library.
    - The generated QR code is saved as a PNG file in the current directory.

<img src="screenshots/qr.png" />


## Endianness
Endianness determines the byte order of data in memory. 

* In TOTP, the timestamp must be in big-endian format (most significant byte first) when passed to the HMAC function. Incorrect endianness leads to invalid TOTP codes, as the hash depends on the precise byte order. So we had to ensure the timestamp matched the expected endianness for consistent results.
* To check the endianness of your system:<br />
`lscpu | grep Order		# Output: Byte Order:     Little Endian`


## The algorithm for TOTP
* The TOTP one-time password is randomly generated by the HOTP algorithm (RFC 4226), and always contains the same format, i.e. 6 digits.
* The main difference between HOTP (HMAC-Based One-Time Password) and TOTP (Time-Based One-Time Password) lies in how they generate and validate one-time passwords (OTPs). While both are based on a shared secret and hashing algorithms, they differ in their reliance on counters versus time:
```
HOTP:

    Uses a counter that is incremented on each OTP request.
    Formula: HOTP = Truncate(HMAC(secret, counter)).

TOTP:

    Uses the current time divided by a fixed time step (e.g., 30 seconds).
    Formula: TOTP = Truncate(HMAC(secret, time_step)).
```

## Decoding Base32 to raw bytes
At first, we were trying to decode Base32 keys with `Base32Decoder`:

```cpp
	Base32Decoder decoder;
	decoder.Put((byte*)key.data(), key.size());
	decoder.MessageEnd();
	size_t size = decoder.MaxRetrievable();
	decodedKey.resize(size);
	decoder.Get(decodedKey, size);
```
However, the decoded string it returned didn't match the one returned by `oathtool --totp -b $(cat key.base32) -v`.
<br /><br />
We thought that the padding character `=` was handled differently, so we tried our code and oathtool both with and without the padding character at the end of the key string.<br />
However it did not change anything either with our code or with oathtool.<br />
<br /><br />
So, we concluded that the key difference between our implementation (`decodeBase32RFC4648()`) and the behavior of oathtool was likely rooted in how the Base32 decoding process was handled, particularly with respect to strict adherence to <a href="https://datatracker.ietf.org/doc/html/rfc4648#section-6">RFC 4648</a>.<br />
<br /><br />
In fact, we found that the default `Base32Decoder` code was based on <a href="http://www.ietf.org/proceedings/51/I-D/draft-ietf-idn-dude-02.txt">Differential Unicode Domain Encoding (DUDE)</a>, which doesn't even use the same character set:

```
// DUDE Decoder's set of characters

static const char base32[] = {
  97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107,     /* a-k */
  109, 110,                                               /* m-n */
  112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122,  /* p-z */
  50, 51, 52, 53, 54, 55, 56, 57                          /* 2-9 */
};
```


## Graphic User Interface

### Install Qt Creator
* We used Qt Creator (Qt6) in order to create the GUI.
* Install the latest open source free version of Qt from the <a href="https://www.qt.io/download-qt-installer-oss">official website</a>.


## Trouble shooting

### Known compilation errors
#### Missing Standard C++ Library development files
* The error
```
In file included from srcs/FileHandler.cpp:1:
incs/FileHandler.hpp:4:10: fatal error: 'iostream' file not found
#include <iostream>
         ^~~~~~~~~~
1 error generated.
```

* The solution<br />
Install the necessary development packages to provide standard headers and libraries:
```
sudo apt install build-essential clang libc++-14-dev libc++-dev libc++1-14 libc++abi-14-dev libc++abi-dev libc++abi1-14 libstdc++-12-dev libunwind-14 libunwind-14-dev
```


## Documentation
* https://www.cryptopp.com/wiki/Advanced_Encryption_Standard (AES)
* https://www.ietf.org/rfc/rfc4226.txt (HOTP)
* https://datatracker.ietf.org/doc/html/rfc6238#section-4 (TOTP)
* https://datatracker.ietf.org/doc/html/rfc4648#section-6 (Base32 encoding)
* https://datatracker.ietf.org/doc/html/rfc3986 (URI)
* https://github.com/google/google-authenticator/wiki/Key-Uri-Format (Key URI Format)

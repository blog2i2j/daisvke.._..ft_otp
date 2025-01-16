# ft_otp

## Description
This program allows you to securely store an initial password in an encrypted file and generate a new TOTP (Time-based One-Time Password) every time it is requested. It provides both a CLI (Command Line Interface) and a GUI (Graphical User Interface) version.

---

### Secret Key
- The `keys` folder contains a set of valid and invalid keys (for testing purposes). 
  - Valid keys: `key.hex`, `key.base32`.
- The secret key file **must not end with a newline character**. To ensure this:
  ```bash
  echo -n <key_string> > <key_file>
  ```
- Keys must:
  - Be in **Hex** or **Base32** format.
  - Contain at least **64 characters**.

---

## Requirements
### 1. **Crypto++ Library**
Used for performing HMAC-SHA1 operations.
```bash
# Install on Ubuntu
sudo apt install libcrypto++X libcrypto++-dev libcrypto++-utils libcrypto++-doc
# Install on Termux
pkg install cryptopp
```

### 2. **Qrencode**
Used for producing QR codes.
```bash
# Install on Ubuntu
sudo apt install libqrencode-dev
# Install on Termux
pkg install libqrencode
```

### 3. **PNG Library**
Used for QR code generation.
```bash
# Install on Ubuntu
sudo apt install libpng-dev
# Install on Termux
pkg install libpng
```

---

## Commands

### CLI
#### Installation:
```bash
cd cli
make
```

#### Usage:
```bash
./ft_otp [OPTIONS] <key_file>

Options:
  -g, --generate     Generate and save the encrypted key
  -k, --key          Generate a password using the provided key
  -q, --qrcode       Generate a QR code containing the key (requires -g)
  -v, --verbose      Enable verbose output
  -h, --help         Show this help message and exit
```

#### Examples:
1. **Generate and save an encrypted key with a QR code:**
   ```bash
   ./ft_otp -gk <key_file>
   ```
   - The key is stored in an encrypted file named `ft_otp.key` using AES encryption.

2. **Generate a TOTP password:**
   ```bash
   ./ft_otp -k ft_otp.key
   ```
   - The program generates a temporary password based on the provided encrypted key.

3. **Verify the TOTP code using `oathtool`:**
   ```bash
   oathtool --totp $(cat keys/key.hex) -v    # Hex key
   oathtool --totp -b $(cat keys/key.base32) -v   # Base32 key
   ```

#### Predefined Usage:
```bash
# With a Hex key
make && ./ft_otp -g keys/key.hex && ./ft_otp ft_otp.key -k

# With a Base32 key
make && ./ft_otp -g keys/key.base32 && ./ft_otp ft_otp.key -k

# With a Bad key
make && ./ft_otp -g keys/key.base32hex && ./ft_otp ft_otp.key -k
```

#### Testing:
```bash
make hex    # Run with a Hex key
make b32    # Run with a Base32 key
make bad    # Run with an invalid key
make tests  # Run all tests
```

<img src="screenshots/cli.png" alt="CLI Screenshot" />

---

### GUI
#### Running the GUI:
```bash
cd gui
./run.sh
# Or
cd gui
./build/Desktop_Qt_6_8_1-Debug/ft_otp_gui
```

<img src="screenshots/gui.png" alt="GUI Screenshot" />

---

## QR Code Generation for TOTP Secrets
QR codes simplify sharing TOTP secrets by encoding them in a scannable format.

#### Steps:
1. **Generate a QR Code:**
   ```bash
   qrencode -o qrcode.png $(cat keys/key.hex)
   ```
2. **Read the QR Code:**
   ```bash
   zbarimg qrcode.png
   ```

#### QR Code Key URI Format:
The QR code encodes the secret as a URI:
```
otpauth://totp/<PROJECT_NAME>:<USER_EMAIL>?secret=<SECRET>&issuer=<PROJECT_NAME>
```
- Example:
  ```
  otpauth://totp/MyService:myuser@example.com?secret=BASE32SECRET&issuer=MyService
  ```

---

## Technical Notes

### How It Works

#### 1. QR Code Dimensions and Scaling:
- The QR code is generated with scaled-up resolution for better readability.
- **Image Dimensions**:
  ```
  (QR_width × scale + 2 × margin) × (QR_width × scale + 2 × margin)
  ```

#### 2. PNG File Creation:
- **libpng** is used to create a grayscale PNG file.
  - **Black pixels** represent QR code modules (`0x00`).
  - **White pixels** fill the rest (`0xFF`).

#### 3. Key URI Format:
- Encodes a TOTP URI in the following format:
  ```
  otpauth://totp/<PROJECT_NAME>:<USER_EMAIL>?secret=<SECRET>&issuer=<PROJECT_NAME>
  ```
  - Example:
    ```
    otpauth://totp/MyService:myuser@example.com?secret=BASE32SECRET&issuer=MyService
    ```

#### 4. Steps for QR Code Generation:
- A TOTP URI is dynamically created using the provided secret and project name.
- The URI is encoded into a QR code using the **qrencode** library.
- The resulting QR code is saved as a PNG file in the current directory.

---

### Decoding Base32 to Raw Bytes

Initially, Base32 decoding was attempted with `Base32Decoder`:

```cpp
Base32Decoder decoder;
decoder.Put((byte*)key.data(), key.size());
decoder.MessageEnd();
size_t size = decoder.MaxRetrievable();
decodedKey.resize(size);
decoder.Get(decodedKey, size);
```

However, the decoded output did not match the output of `oathtool --totp -b $(cat key.base32) -v`.  
This led to the hypothesis that differences in padding (`=`) might cause discrepancies, but adding or removing padding didn’t affect either implementation.

#### Findings:
The key difference between our implementation (`decodeBase32RFC4648()`) and `oathtool` likely stems from strict adherence to [RFC 4648](https://datatracker.ietf.org/doc/html/rfc4648#section-6). Specifically:
- The `Base32Decoder` used by our code followed the **Differential Unicode Domain Encoding (DUDE)** standard, which employs a different character set.

#### DUDE Decoder's Character Set:
The character set used by DUDE differs from the Base32 standard:
```
// DUDE Decoder's set of characters
static const char base32[] = {
  97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107,     // a-k
  109, 110,                                               // m-n
  112, 113, 114, 115, 116, 117, 118, 119, 120, 121, 122,  // p-z
  50, 51, 52, 53, 54, 55, 56, 57                          // 2-9
};
```

The mismatch between the DUDE and RFC 4648 Base32 decoding caused inconsistencies in the generated TOTP.

#### Conclusion:
We developed our own `decodeBase32RFC4648()` function to ensure strict adherence to RFC 4648, which resolved the discrepancies.


### Endianness
TOTP requires the timestamp in **big-endian format** (most significant byte first). Incorrect endianness will produce invalid codes.  
To verify system endianness:
```bash
lscpu | grep Order    # Output: Byte Order: Little Endian
```

---

### Algorithm for TOTP
#### Differences Between HOTP and TOTP:
- **HOTP**: Based on a counter.
  ```
  HOTP = Truncate(HMAC(secret, counter))
  ```
- **TOTP**: Based on time.
  ```
  TOTP = Truncate(HMAC(secret, time_step))
  ```

#### Key Format:
- Always 6 digits.

---

### Decoding Base32
Initial decoding attempts with `Base32Decoder` didn’t match `oathtool` results. The issue stemmed from:
- Padding differences.
- Base32Decoder’s use of a different character set (e.g., DUDE encoding).

---

### GUI Development
The GUI was developed using **Qt Creator (Qt6)**.  
Install the latest version of Qt from the [official website](https://www.qt.io/download-qt-installer-oss).

---

## Troubleshooting

### Missing Standard C++ Library Development Files
Error:
```
fatal error: 'iostream' file not found
```
Solution:
```bash
sudo apt install build-essential clang libc++-14-dev libstdc++-12-dev
```

---

## References
- [Crypto++ Advanced Encryption Standard (AES)](https://www.cryptopp.com/wiki/Advanced_Encryption_Standard)
- [HOTP RFC 4226](https://www.ietf.org/rfc/rfc4226.txt)
- [TOTP RFC 6238](https://datatracker.ietf.org/doc/html/rfc6238#section-4)
- [Base32 RFC 4648](https://datatracker.ietf.org/doc/html/rfc4648#section-6)
- [Key URI Format (Google Authenticator)](https://github.com/google/google-authenticator/wiki/Key-Uri-Format)

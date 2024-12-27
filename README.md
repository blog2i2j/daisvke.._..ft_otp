# ft_otp

## Description
This is a program that allows you to store
an initial password in file, and that is capable of generating a new one time password
every time it is requested.<br />

### Secret key
* The `keys` folder contains a set of valid and invalid keys (for testing purpose). The valid keys are: `key.hex`, `key.base32`.
* The file containing the secret key shouldn't end with a newline character.
do `echo -n <key_string> > <key_file>` to put into a file a string that doesn't end with a newline. 
* The key has to be either in Hex or Base32 formats.
* The key has to have at least 64 characters.

## Commands
```
// Install
make

// Generate the key
./ft_otp -g <key_file>

The program receives as argument a hexadecimal key of at least 64 characters.
The program stores this key safely in a file called ft_otp.key,
which is encrypted with AES encryption using Crypto++.

// Generate the temporary password
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

or: make err

// Tests
make hex	// Run with a Hex secret key
make b32	// Run with a Base32 secret key
make err	// Run with a bad secret key
make tests	// Run all tests
```


## Notes

### Compatibility
* We added `cpu-features.h` for some systems as Termux on Android.

### Library
* As we sort of struggled trying to install and use the Crypto++ binary on some of our systems, we decided to install it from the source and include it on this repository as we found it to be much simpler to use.
* We've cloned the repo from Github and compiled it and tried to only keep the files that we were using by running:<br />
`find cryptopp -type f ! -name "*.h" ! -name "*topp.a" -exec rm -rf {} \;`<br />
which results in a 117MB folder. Some headers are unused but they don't take much space.

### The algorithm  for TOTP
* The TOTP one-time password is randomly generated by the HOTP algorithm (RFC 4226), and always contains the same format, i.e. 6 digits.

### Decoding Base32 to raw bytes
At first, we were trying to decode Base32 keys with `Base32Decoder`:

```cpp
	Base32Decoder decoder;
	decoder.Put((byte*)key.data(), key.size());
	decoder.MessageEnd();
	size_t size = decoder.MaxRetrievable();
	decodedKey.resize(size);
	decoder.Get(decodedKey, size);
```
However, the decoded string that it returned didn't match the one returned by `oathtool --totp -b $(cat key.base32) -v`.<br />

We thought that the padding character `=` was handled differently, so we tried our code and oathtool both with and without the padding character at the end of the key string.<br />
However it did not change anything either with our code or with oathtool.<br />

So, the key difference between our implementation and the behavior of oathtool is likely rooted in how the Base32 decoding process is handled, particularly with respect to strict adherence to RFC 4648.m

## Documentation
* https://www.cryptopp.com/wiki/Advanced_Encryption_Standard (AES)
* https://www.ietf.org/rfc/rfc4226.txt (HOTP)
* https://datatracker.ietf.org/doc/html/rfc6238#section-4 (TOTP)
* https://datatracker.ietf.org/doc/html/rfc4648#section-6 (Base 32 encoding)